package handlers

import (
	"buzzcart/internal/models"
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
)

const fcmMessagingScope = "https://www.googleapis.com/auth/firebase.messaging"

var (
	pushTokensOnce sync.Once
	pushTokensErr  error
)

// EnsurePushTokensSchema creates the device push-token registry on first call.
func EnsurePushTokensSchema(db *sql.DB) error {
	pushTokensOnce.Do(func() {
		statements := []string{
			`CREATE TABLE IF NOT EXISTS device_push_tokens (
				token      TEXT PRIMARY KEY,
				user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
				platform   TEXT NOT NULL DEFAULT 'unknown',
				updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
			)`,
			`CREATE INDEX IF NOT EXISTS idx_device_push_tokens_user
				ON device_push_tokens(user_id)`,
		}
		for _, statement := range statements {
			if _, err := db.Exec(statement); err != nil {
				pushTokensErr = err
				return
			}
		}
	})
	return pushTokensErr
}

type pushTokenRequest struct {
	Token    string `json:"token" binding:"required"`
	Platform string `json:"platform"`
}

// RegisterPushToken stores/refreshes an FCM device token for the caller.
// Tokens are unique per device; re-registering reassigns to the new user
// (device changed accounts).
func RegisterPushToken(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		var req pushTokenRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "token is required"})
			return
		}

		platform := strings.TrimSpace(req.Platform)
		if platform == "" {
			platform = "unknown"
		}

		_, err := db.Exec(
			`INSERT INTO device_push_tokens (token, user_id, platform, updated_at)
			 VALUES ($1, $2, $3, NOW())
			 ON CONFLICT (token) DO UPDATE
				SET user_id = EXCLUDED.user_id,
					platform = EXCLUDED.platform,
					updated_at = NOW()`,
			strings.TrimSpace(req.Token),
			userID,
			platform,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to register push token"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"status": "registered"})
	}
}

// UnregisterPushToken removes a device token (logout / notifications off).
func UnregisterPushToken(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		var req pushTokenRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "token is required"})
			return
		}

		_, err := db.Exec(
			`DELETE FROM device_push_tokens WHERE token = $1 AND user_id = $2`,
			strings.TrimSpace(req.Token),
			userID,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to unregister push token"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"status": "unregistered"})
	}
}

// PushSender delivers OS-level notifications through FCM (HTTP v1). It is
// only invoked for recipients whose app is not foregrounded — in-app socket
// banners cover the foreground case.
type PushSender struct {
	db          *sql.DB
	projectID   string
	tokenSource oauth2.TokenSource
	httpClient  *http.Client
}

// NewPushSender builds an FCM sender from the same Google credentials the
// storage layer uses (credentials file, or ambient credentials on Cloud
// Run). Returns nil (push disabled, no error) when credentials or project ID
// are unavailable.
func NewPushSender(db *sql.DB, projectID, credentialsFile string) *PushSender {
	projectID = strings.TrimSpace(projectID)
	if projectID == "" {
		return nil
	}

	ctx := context.Background()
	var tokenSource oauth2.TokenSource
	if credentialsFile = strings.TrimSpace(credentialsFile); credentialsFile != "" {
		data, err := os.ReadFile(credentialsFile)
		if err != nil {
			return nil
		}
		credentials, err := google.CredentialsFromJSON(ctx, data, fcmMessagingScope)
		if err != nil {
			return nil
		}
		tokenSource = credentials.TokenSource
	} else {
		credentials, err := google.FindDefaultCredentials(ctx, fcmMessagingScope)
		if err != nil {
			return nil
		}
		tokenSource = credentials.TokenSource
	}

	return &PushSender{
		db:          db,
		projectID:   projectID,
		tokenSource: oauth2.ReuseTokenSource(nil, tokenSource),
		httpClient:  &http.Client{Timeout: 10 * time.Second},
	}
}

// SendMessagePush notifies every registered device of userID about a new
// chat message. Dead tokens reported by FCM are pruned. Safe on a nil
// receiver (push disabled).
func (p *PushSender) SendMessagePush(userID, title, body, conversationID string) {
	if p == nil {
		return
	}

	rows, err := p.db.Query(
		`SELECT token FROM device_push_tokens WHERE user_id = $1`,
		userID,
	)
	if err != nil {
		return
	}
	tokens := make([]string, 0, 4)
	for rows.Next() {
		var token string
		if err := rows.Scan(&token); err == nil && token != "" {
			tokens = append(tokens, token)
		}
	}
	rows.Close()

	for _, token := range tokens {
		if p.sendToToken(token, title, body, conversationID) == fcmTokenDead {
			_, _ = p.db.Exec(`DELETE FROM device_push_tokens WHERE token = $1`, token)
		}
	}
}

type fcmSendResult int

const (
	fcmSendOK fcmSendResult = iota
	fcmSendFailed
	fcmTokenDead
)

func (p *PushSender) sendToToken(token, title, body, conversationID string) fcmSendResult {
	payload := map[string]any{
		"message": map[string]any{
			"token": token,
			"notification": map[string]any{
				"title": title,
				"body":  body,
			},
			"data": map[string]string{
				"type":            "message",
				"conversation_id": conversationID,
			},
			"android": map[string]any{
				"priority": "HIGH",
				"notification": map[string]any{
					"channel_id": "messages",
				},
			},
			"apns": map[string]any{
				"payload": map[string]any{
					"aps": map[string]any{
						"sound":    "default",
						"badge":    1,
						"category": "MESSAGE",
					},
				},
			},
		},
	}

	encoded, err := json.Marshal(payload)
	if err != nil {
		return fcmSendFailed
	}

	accessToken, err := p.tokenSource.Token()
	if err != nil {
		return fcmSendFailed
	}

	endpoint := fmt.Sprintf(
		"https://fcm.googleapis.com/v1/projects/%s/messages:send",
		p.projectID,
	)
	request, err := http.NewRequest(http.MethodPost, endpoint, bytes.NewReader(encoded))
	if err != nil {
		return fcmSendFailed
	}
	request.Header.Set("Authorization", "Bearer "+accessToken.AccessToken)
	request.Header.Set("Content-Type", "application/json")

	response, err := p.httpClient.Do(request)
	if err != nil {
		return fcmSendFailed
	}
	defer response.Body.Close()
	responseBody, _ := io.ReadAll(io.LimitReader(response.Body, 4096))

	switch {
	case response.StatusCode >= 200 && response.StatusCode < 300:
		return fcmSendOK
	case response.StatusCode == http.StatusNotFound,
		response.StatusCode == http.StatusGone,
		strings.Contains(string(responseBody), "UNREGISTERED"),
		strings.Contains(string(responseBody), "InvalidRegistration"):
		return fcmTokenDead
	default:
		return fcmSendFailed
	}
}

// sendNewMessagePush builds the OS notification for a chat message: the
// sender's name as the title and a WhatsApp-style glimpse of the content as
// the body.
func sendNewMessagePush(db *sql.DB, pushSender *PushSender, message models.Message) {
	var senderName string
	err := db.QueryRow(
		`SELECT COALESCE(name, 'New message') FROM users WHERE id = $1`,
		message.SenderID,
	).Scan(&senderName)
	if err != nil || strings.TrimSpace(senderName) == "" {
		senderName = "New message"
	}

	body := strings.TrimSpace(message.Content)
	if message.MessageType == messageTypeProductLink {
		title := ""
		if message.Product != nil {
			title = strings.TrimSpace(message.Product.Title)
		}
		if title == "" {
			body = "Check this product"
		} else {
			body = "Check this " + title
		}
	} else if body == "" {
		body = "Sent an attachment"
	}
	if len(body) > 140 {
		body = body[:140] + "…"
	}

	pushSender.SendMessagePush(
		message.ReceiverID,
		senderName,
		body,
		message.ConversationID,
	)
}

// IsUserAppActive reports whether the user currently has the app foregrounded
// somewhere (per socket app_state presence) — if so, in-app banners handle
// notifications and no OS push should be sent.
func (h *MessageHub) IsUserAppActive(userID string) bool {
	if h == nil {
		return false
	}
	h.mu.RLock()
	defer h.mu.RUnlock()
	return h.activeUsers[userID] > 0
}
