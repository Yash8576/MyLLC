package storage

import (
	"buzzcart/internal/config"
	"fmt"
	"log"
)

var (
	// GlobalStorageClient is the global Firebase Storage client instance
	GlobalStorageClient *StorageClient
)

// InitializeStorage initializes the Firebase Storage client with the given configuration
func InitializeStorage(cfg *config.Config) error {
	storageConfig := StorageConfig{
		Bucket:          cfg.Storage.Bucket,
		ProjectID:       cfg.Storage.ProjectID,
		Location:        cfg.Storage.Location,
		CredentialsFile: cfg.Storage.CredentialsFile,
		PublicBaseURL:   cfg.Storage.PublicBaseURL,
	}

	client, err := NewStorageClient(storageConfig)
	if err != nil {
		return fmt.Errorf("failed to initialize storage client: %w", err)
	}

	GlobalStorageClient = client
	log.Printf("✓ Firebase Storage initialized successfully (Bucket: %s, Project: %s)", cfg.Storage.Bucket, cfg.Storage.ProjectID)

	return nil
}

// GetStorageClient returns the global storage client
// Panics if storage is not initialized - this should never happen in production
// as the server won't start without successful storage initialization
func GetStorageClient() *StorageClient {
	if GlobalStorageClient == nil {
		log.Fatal("FATAL: Storage client accessed before initialization. Server misconfigured.")
	}
	return GlobalStorageClient
}

// IsInitialized checks if storage client has been initialized
func IsInitialized() bool {
	return GlobalStorageClient != nil
}
