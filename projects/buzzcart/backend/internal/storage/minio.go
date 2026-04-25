package storage

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"time"

	storagepkg "cloud.google.com/go/storage"
	"github.com/google/uuid"
	"google.golang.org/api/iterator"
	"google.golang.org/api/option"
)

// StorageClient wraps the Firebase/GCS client with configuration.
type StorageClient struct {
	client              *storagepkg.Client
	bucket              string
	projectID           string
	location            string
	publicBaseURL       string
	serviceAccountEmail string
	privateKey          []byte
}

// StorageConfig holds the configuration for Firebase/GCS storage.
type StorageConfig struct {
	Bucket          string
	ProjectID       string
	Location        string
	CredentialsFile string
	PublicBaseURL   string
}

type serviceAccountCredentials struct {
	ClientEmail string `json:"client_email"`
	PrivateKey  string `json:"private_key"`
}

// NewStorageClient creates a new Firebase/GCS storage client.
func NewStorageClient(config StorageConfig) (*StorageClient, error) {
	bucketName := normalizeBucketName(config.Bucket)
	if bucketName == "" {
		return nil, fmt.Errorf("storage bucket is required")
	}

	ctx := context.Background()

	clientOptions := make([]option.ClientOption, 0, 1)
	if strings.TrimSpace(config.CredentialsFile) != "" {
		clientOptions = append(clientOptions, option.WithCredentialsFile(config.CredentialsFile))
	}

	gcsClient, err := storagepkg.NewClient(ctx, clientOptions...)
	if err != nil {
		return nil, fmt.Errorf("failed to create google storage client: %w", err)
	}

	client := &StorageClient{
		client:        gcsClient,
		bucket:        bucketName,
		projectID:     strings.TrimSpace(config.ProjectID),
		location:      strings.TrimSpace(config.Location),
		publicBaseURL: strings.TrimRight(strings.TrimSpace(config.PublicBaseURL), "/"),
	}

	if client.publicBaseURL == "" {
		client.publicBaseURL = "https://firebasestorage.googleapis.com/v0/b"
	}

	if strings.TrimSpace(config.CredentialsFile) != "" {
		credsRaw, readErr := os.ReadFile(config.CredentialsFile)
		if readErr != nil {
			return nil, fmt.Errorf("failed to read credentials file: %w", readErr)
		}

		var creds serviceAccountCredentials
		if unmarshalErr := json.Unmarshal(credsRaw, &creds); unmarshalErr != nil {
			return nil, fmt.Errorf("failed to parse credentials file: %w", unmarshalErr)
		}

		client.serviceAccountEmail = strings.TrimSpace(creds.ClientEmail)
		if creds.PrivateKey != "" {
			client.privateKey = []byte(creds.PrivateKey)
		}
	}

	// Ensure bucket exists
	if err := client.ensureBucket(); err != nil {
		_ = client.client.Close()
		return nil, err
	}

	return client, nil
}

// ensureBucket creates the bucket if it doesn't exist.
func (m *StorageClient) ensureBucket() error {
	if m.projectID == "" {
		// If no project is configured, skip creation and rely on an existing bucket.
		return nil
	}

	ctx := context.Background()
	bucketHandle := m.client.Bucket(m.bucket)

	_, err := bucketHandle.Attrs(ctx)
	if err == nil {
		return nil
	}
	if err != storagepkg.ErrBucketNotExist {
		return fmt.Errorf("failed to check bucket existence: %w", err)
	}

	attrs := &storagepkg.BucketAttrs{}
	if m.location != "" {
		attrs.Location = m.location
	}

	if createErr := bucketHandle.Create(ctx, m.projectID, attrs); createErr != nil {
		return fmt.Errorf("failed to create bucket %q: %w", m.bucket, createErr)
	}

	return nil
}

// UploadFile uploads a file to Firebase/GCS and returns the public URL.
func (m *StorageClient) UploadFile(file multipart.File, header *multipart.FileHeader, folder string) (string, error) {
	ctx := context.Background()

	// Generate unique filename
	ext := filepath.Ext(header.Filename)
	filename := fmt.Sprintf("%s%s", uuid.New().String(), ext)

	// Add folder prefix if provided
	objectName := buildObjectName(folder, filename)

	// Get content type
	contentType := header.Header.Get("Content-Type")
	if contentType == "" {
		contentType = "application/octet-stream"
	}

	writer := m.client.Bucket(m.bucket).Object(objectName).NewWriter(ctx)
	writer.ContentType = contentType
	downloadToken := uuid.New().String()
	writer.Metadata = map[string]string{
		"firebaseStorageDownloadTokens": downloadToken,
	}

	if _, err := io.Copy(writer, file); err != nil {
		_ = writer.Close()
		return "", fmt.Errorf("failed to write object: %w", err)
	}
	if err := writer.Close(); err != nil {
		return "", fmt.Errorf("failed to finalize upload: %w", err)
	}

	return m.GetPublicURLWithToken(objectName, downloadToken), nil
}

// UploadFileFromReader uploads a file from an io.Reader
func (m *StorageClient) UploadFileFromReader(reader io.Reader, filename string, size int64, contentType string, folder string) (string, error) {
	ctx := context.Background()

	// Generate unique filename
	ext := filepath.Ext(filename)
	uniqueFilename := fmt.Sprintf("%s%s", uuid.New().String(), ext)

	// Add folder prefix if provided
	objectName := buildObjectName(folder, uniqueFilename)

	if contentType == "" {
		contentType = "application/octet-stream"
	}
	_ = size

	writer := m.client.Bucket(m.bucket).Object(objectName).NewWriter(ctx)
	writer.ContentType = contentType
	downloadToken := uuid.New().String()
	writer.Metadata = map[string]string{
		"firebaseStorageDownloadTokens": downloadToken,
	}

	if _, err := io.Copy(writer, reader); err != nil {
		_ = writer.Close()
		return "", fmt.Errorf("failed to write object: %w", err)
	}
	if err := writer.Close(); err != nil {
		return "", fmt.Errorf("failed to finalize upload: %w", err)
	}

	return m.GetPublicURLWithToken(objectName, downloadToken), nil
}

// GetPublicURL returns the public URL for an object
func (m *StorageClient) GetPublicURL(objectName string) string {
	return m.GetPublicURLWithToken(objectName, "")
}

// GetPublicURLWithToken returns a Firebase/GCS URL for an object and includes
// a Firebase download token when one was attached to object metadata.
func (m *StorageClient) GetPublicURLWithToken(objectName string, downloadToken string) string {
	normalizedObjectName := strings.TrimPrefix(strings.TrimSpace(objectName), "/")
	if normalizedObjectName == "" {
		return ""
	}

	base := strings.TrimRight(strings.TrimSpace(m.publicBaseURL), "/")
	escapedObject := url.QueryEscape(normalizedObjectName)

	if strings.Contains(base, "/v0/b") {
		publicURL := fmt.Sprintf("%s/%s/o/%s?alt=media", base, m.bucket, escapedObject)
		if strings.TrimSpace(downloadToken) != "" {
			publicURL += "&token=" + url.QueryEscape(strings.TrimSpace(downloadToken))
		}
		return publicURL
	}
	if strings.Contains(base, "storage.googleapis.com") {
		return fmt.Sprintf("%s/%s/%s", base, m.bucket, normalizedObjectName)
	}

	return fmt.Sprintf("https://firebasestorage.googleapis.com/v0/b/%s/o/%s?alt=media", m.bucket, escapedObject)
}

// GetReadableURL returns a URL suitable for clients to render directly.
// Firebase Storage download URLs need a token unless the bucket/object is public,
// so tokenless Firebase URLs are repaired by adding metadata to the object.
func (m *StorageClient) GetReadableURL(raw string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return raw
	}
	if strings.Contains(raw, "token=") || strings.Contains(raw, "X-Goog-Signature=") {
		return raw
	}
	if !strings.Contains(raw, "firebasestorage.googleapis.com") && !strings.Contains(raw, "storage.googleapis.com") {
		return raw
	}

	objectName := m.normalizeObjectName(raw)
	if objectName == "" {
		return raw
	}

	if token, err := m.ensureDownloadToken(objectName); err == nil && token != "" {
		return m.GetPublicURLWithToken(objectName, token)
	}

	if signedURL, err := m.GetPresignedURL(objectName, 7*24*time.Hour); err == nil && signedURL != "" {
		return signedURL
	}

	return raw
}

func (m *StorageClient) ensureDownloadToken(objectName string) (string, error) {
	ctx := context.Background()
	objectHandle := m.client.Bucket(m.bucket).Object(objectName)

	attrs, err := objectHandle.Attrs(ctx)
	if err != nil {
		return "", fmt.Errorf("failed to read object metadata: %w", err)
	}

	const tokenKey = "firebaseStorageDownloadTokens"
	if attrs.Metadata != nil {
		if existing := strings.TrimSpace(attrs.Metadata[tokenKey]); existing != "" {
			return firstMetadataToken(existing), nil
		}
	}

	downloadToken := uuid.New().String()
	metadata := map[string]string{}
	for key, value := range attrs.Metadata {
		metadata[key] = value
	}
	metadata[tokenKey] = downloadToken

	if _, err := objectHandle.Update(ctx, storagepkg.ObjectAttrsToUpdate{Metadata: metadata}); err != nil {
		return "", fmt.Errorf("failed to update object metadata: %w", err)
	}

	return downloadToken, nil
}

func firstMetadataToken(tokens string) string {
	for _, token := range strings.Split(tokens, ",") {
		if trimmed := strings.TrimSpace(token); trimmed != "" {
			return trimmed
		}
	}
	return ""
}

// GetPresignedURL generates a presigned URL for temporary access (expires in 7 days by default).
func (m *StorageClient) GetPresignedURL(objectName string, expiry time.Duration) (string, error) {
	objectName = m.normalizeObjectName(objectName)
	if objectName == "" {
		return "", fmt.Errorf("object name is required")
	}

	if expiry == 0 {
		expiry = 7 * 24 * time.Hour // Default 7 days
	}

	if m.serviceAccountEmail == "" || len(m.privateKey) == 0 {
		return "", fmt.Errorf("service account credentials with private key are required to sign URLs")
	}

	signedURL, err := storagepkg.SignedURL(m.bucket, objectName, &storagepkg.SignedURLOptions{
		GoogleAccessID: m.serviceAccountEmail,
		PrivateKey:     m.privateKey,
		Method:         "GET",
		Expires:        time.Now().Add(expiry),
		Scheme:         storagepkg.SigningSchemeV4,
	})
	if err != nil {
		return "", fmt.Errorf("failed to generate signed URL: %w", err)
	}

	return signedURL, nil
}

// DeleteFile deletes a file from Firebase/GCS.
func (m *StorageClient) DeleteFile(objectName string) error {
	objectName = m.normalizeObjectName(objectName)
	if objectName == "" {
		return fmt.Errorf("object name is required")
	}

	ctx := context.Background()
	if err := m.client.Bucket(m.bucket).Object(objectName).Delete(ctx); err != nil && err != storagepkg.ErrObjectNotExist {
		return fmt.Errorf("failed to delete file: %w", err)
	}

	return nil
}

// ListFiles lists all files in a folder (prefix)
func (m *StorageClient) ListFiles(folder string) ([]string, error) {
	ctx := context.Background()

	var files []string
	prefix := strings.TrimSpace(folder)
	if prefix != "" && !strings.HasSuffix(prefix, "/") {
		prefix += "/"
	}
	iter := m.client.Bucket(m.bucket).Objects(ctx, &storagepkg.Query{Prefix: prefix})

	for {
		attrs, err := iter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			return nil, fmt.Errorf("error listing objects: %w", err)
		}
		files = append(files, attrs.Name)
	}

	return files, nil
}

// FileExists checks if a file exists in Firebase/GCS.
func (m *StorageClient) FileExists(objectName string) (bool, error) {
	objectName = m.normalizeObjectName(objectName)
	if objectName == "" {
		return false, nil
	}

	ctx := context.Background()

	_, err := m.client.Bucket(m.bucket).Object(objectName).Attrs(ctx)
	if err != nil {
		if err == storagepkg.ErrObjectNotExist {
			return false, nil
		}
		return false, fmt.Errorf("failed to check file existence: %w", err)
	}

	return true, nil
}

func (m *StorageClient) normalizeObjectName(raw string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return ""
	}

	if !strings.Contains(raw, "://") {
		return strings.TrimPrefix(raw, "/")
	}

	parsedURL, err := url.Parse(raw)
	if err != nil {
		return ""
	}

	trimmedPath := strings.TrimPrefix(parsedURL.Path, "/")
	if trimmedPath == "" {
		return ""
	}

	pathParts := strings.Split(trimmedPath, "/")

	// Firebase URL format: /v0/b/<bucket>/o/<url-encoded-object>
	if len(pathParts) >= 5 && pathParts[0] == "v0" && pathParts[1] == "b" && pathParts[3] == "o" {
		decoded, unescapeErr := url.QueryUnescape(strings.Join(pathParts[4:], "/"))
		if unescapeErr == nil {
			return decoded
		}
		return strings.Join(pathParts[4:], "/")
	}

	// Public GCS URL format: /<bucket>/<objectName>
	if len(pathParts) > 1 && pathParts[0] == m.bucket {
		return strings.Join(pathParts[1:], "/")
	}

	if strings.Contains(parsedURL.Host, "storage.googleapis.com") && len(pathParts) > 1 {
		return strings.Join(pathParts[1:], "/")
	}

	return strings.TrimPrefix(raw, "/")
}

func buildObjectName(folder string, filename string) string {
	cleanFolder := strings.Trim(strings.TrimSpace(folder), "/")
	if cleanFolder == "" {
		return filename
	}
	return cleanFolder + "/" + filename
}

func normalizeBucketName(raw string) string {
	bucket := strings.TrimSpace(raw)
	bucket = strings.TrimPrefix(bucket, "gs://")
	bucket = strings.TrimPrefix(bucket, "https://storage.googleapis.com/")
	bucket = strings.TrimPrefix(bucket, "http://storage.googleapis.com/")
	bucket = strings.TrimPrefix(bucket, "https://")
	bucket = strings.TrimPrefix(bucket, "http://")
	bucket = strings.Trim(bucket, "/")

	if idx := strings.Index(bucket, "/"); idx >= 0 {
		bucket = bucket[:idx]
	}

	return bucket
}
