package handlers

import (
	"database/sql"
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/net/websocket"
)

type MessageHub struct {
	mu                  sync.RWMutex
	clients             map[*messageSocketClient]struct{}
	userClients         map[string]map[*messageSocketClient]struct{}
	conversationViewers map[string]map[string]int
	presenceTTL         time.Duration
}

type messageSocketClient struct {
	conn               *websocket.Conn
	hub                *MessageHub
	userID             string
	send               chan []byte
	activeConversation string
	lastPresencePing   time.Time
	closeConnOnce      sync.Once
	closeSendOnce      sync.Once
}

type messageSocketInbound struct {
	Type           string `json:"type"`
	ConversationID string `json:"conversation_id,omitempty"`
	IsTyping       bool   `json:"is_typing,omitempty"`
}

func NewMessageHub() *MessageHub {
	hub := &MessageHub{
		clients:             make(map[*messageSocketClient]struct{}),
		userClients:         make(map[string]map[*messageSocketClient]struct{}),
		conversationViewers: make(map[string]map[string]int),
		presenceTTL:         12 * time.Second,
	}
	go hub.presenceCleanupLoop()
	return hub
}

func (h *MessageHub) Register(client *messageSocketClient) {
	h.mu.Lock()
	defer h.mu.Unlock()

	h.clients[client] = struct{}{}
	if h.userClients[client.userID] == nil {
		h.userClients[client.userID] = make(map[*messageSocketClient]struct{})
	}
	h.userClients[client.userID][client] = struct{}{}
}

func (h *MessageHub) Unregister(client *messageSocketClient) {
	h.mu.Lock()
	oldConversationID := client.activeConversation
	h.removeActiveConversationLocked(client)
	delete(h.clients, client)
	if userClients := h.userClients[client.userID]; userClients != nil {
		delete(userClients, client)
		if len(userClients) == 0 {
			delete(h.userClients, client.userID)
		}
	}
	h.mu.Unlock()

	if oldConversationID != "" {
		h.broadcastConversationPresence(oldConversationID)
	}
	client.closeSend()
}

func (h *MessageHub) PublishMessage(conversationID string, userIDs []string, message any) {
	h.broadcastToUsers(userIDs, map[string]any{
		"type":            "message_created",
		"conversation_id": conversationID,
		"message":         message,
	})
}

func (h *MessageHub) PublishTyping(conversationID, userID string, userIDs []string, isTyping bool) {
	h.broadcastToUsers(userIDs, map[string]any{
		"type":            "typing",
		"conversation_id": conversationID,
		"user_id":         userID,
		"is_typing":       isTyping,
	})
}

func (h *MessageHub) SetActiveConversation(client *messageSocketClient, conversationID string) {
	h.mu.Lock()
	oldConversationID := client.activeConversation
	now := time.Now()
	if oldConversationID == conversationID {
		client.lastPresencePing = now
		h.mu.Unlock()
		h.broadcastConversationPresence(conversationID)
		return
	}

	h.removeActiveConversationLocked(client)

	if conversationID != "" {
		if h.conversationViewers[conversationID] == nil {
			h.conversationViewers[conversationID] = make(map[string]int)
		}
		h.conversationViewers[conversationID][client.userID]++
		client.activeConversation = conversationID
		client.lastPresencePing = now
	} else {
		client.lastPresencePing = time.Time{}
	}
	h.mu.Unlock()

	if oldConversationID != "" {
		h.broadcastConversationPresence(oldConversationID)
	}
	if conversationID != "" {
		h.broadcastConversationPresence(conversationID)
	}
}

func (h *MessageHub) broadcastConversationPresence(conversationID string) {
	h.mu.RLock()
	viewerCounts := h.conversationViewers[conversationID]
	activeUserIDs := make([]string, 0, len(viewerCounts))
	for userID := range viewerCounts {
		activeUserIDs = append(activeUserIDs, userID)
	}
	h.mu.RUnlock()

	h.broadcastToUsers(activeUserIDs, map[string]any{
		"type":            "conversation_presence",
		"conversation_id": conversationID,
		"active_user_ids": activeUserIDs,
	})
}

func (h *MessageHub) broadcastToUsers(userIDs []string, payload any) {
	if len(userIDs) == 0 {
		return
	}

	encoded, err := json.Marshal(payload)
	if err != nil {
		return
	}

	uniqueUsers := make(map[string]struct{}, len(userIDs))
	for _, userID := range userIDs {
		if userID != "" {
			uniqueUsers[userID] = struct{}{}
		}
	}

	h.mu.RLock()
	defer h.mu.RUnlock()

	for userID := range uniqueUsers {
		for client := range h.userClients[userID] {
			select {
			case client.send <- encoded:
			default:
				go client.close()
			}
		}
	}
}

func (h *MessageHub) removeActiveConversationLocked(client *messageSocketClient) {
	if client.activeConversation == "" {
		client.lastPresencePing = time.Time{}
		return
	}

	viewers := h.conversationViewers[client.activeConversation]
	if viewers != nil {
		viewers[client.userID]--
		if viewers[client.userID] <= 0 {
			delete(viewers, client.userID)
		}
		if len(viewers) == 0 {
			delete(h.conversationViewers, client.activeConversation)
		}
	}
	client.activeConversation = ""
	client.lastPresencePing = time.Time{}
}

func (c *messageSocketClient) close() {
	c.closeConnOnce.Do(func() {
		_ = c.conn.Close()
	})
}

func (c *messageSocketClient) closeSend() {
	c.closeSendOnce.Do(func() {
		close(c.send)
	})
}

func (c *messageSocketClient) writeLoop() {
	for payload := range c.send {
		if err := websocket.Message.Send(c.conn, string(payload)); err != nil {
			return
		}
	}
}

func MessagesSocket(db *sql.DB, jwtSecret string, hub *MessageHub) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID, err := authenticateSocketUser(c, jwtSecret)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid websocket token"})
			return
		}

		server := websocket.Server{
			Handshake: func(config *websocket.Config, request *http.Request) error {
				return nil
			},
			Handler: websocket.Handler(func(ws *websocket.Conn) {
				client := &messageSocketClient{
					conn:   ws,
					hub:    hub,
					userID: userID,
					send:   make(chan []byte, 32),
				}
				hub.Register(client)
				defer hub.Unregister(client)
				defer client.close()

				go client.writeLoop()

				initialConversationID := strings.TrimSpace(c.Query("conversation_id"))
				if initialConversationID != "" && canAccessConversation(db, userID, initialConversationID) {
					hub.SetActiveConversation(client, initialConversationID)
				}

				for {
					var raw string
					if err := websocket.Message.Receive(ws, &raw); err != nil {
						return
					}

					var inbound messageSocketInbound
					if err := json.Unmarshal([]byte(raw), &inbound); err != nil {
						continue
					}

					handleSocketInbound(db, hub, client, inbound)
				}
			}),
		}

		server.ServeHTTP(c.Writer, c.Request)
	}
}

func handleSocketInbound(db *sql.DB, hub *MessageHub, client *messageSocketClient, inbound messageSocketInbound) {
	conversationID := strings.TrimSpace(inbound.ConversationID)

	switch strings.TrimSpace(inbound.Type) {
	case "open_conversation":
		if conversationID != "" && canAccessConversation(db, client.userID, conversationID) {
			hub.SetActiveConversation(client, conversationID)
		}
	case "close_conversation":
		if conversationID == "" || client.activeConversation == conversationID {
			hub.SetActiveConversation(client, "")
		}
	case "typing":
		if conversationID == "" || !canAccessConversation(db, client.userID, conversationID) {
			return
		}
		participants, err := getConversationParticipants(db, conversationID)
		if err != nil {
			return
		}
		hub.PublishTyping(conversationID, client.userID, participants, inbound.IsTyping)
	}
}

func (h *MessageHub) presenceCleanupLoop() {
	ticker := time.NewTicker(4 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		h.cleanupExpiredPresence()
	}
}

func (h *MessageHub) cleanupExpiredPresence() {
	now := time.Now()
	affectedConversations := make(map[string]struct{})

	h.mu.Lock()
	for client := range h.clients {
		if client.activeConversation == "" || client.lastPresencePing.IsZero() {
			continue
		}
		if now.Sub(client.lastPresencePing) <= h.presenceTTL {
			continue
		}
		affectedConversations[client.activeConversation] = struct{}{}
		h.removeActiveConversationLocked(client)
	}
	h.mu.Unlock()

	for conversationID := range affectedConversations {
		h.broadcastConversationPresence(conversationID)
	}
}

func canAccessConversation(db *sql.DB, userID, conversationID string) bool {
	var exists bool
	err := db.QueryRow(
		`SELECT EXISTS(
			SELECT 1
			FROM conversations
			WHERE id = $1
				AND (participant_1_id = $2 OR participant_2_id = $2)
		)`,
		conversationID,
		userID,
	).Scan(&exists)
	return err == nil && exists
}

func authenticateSocketUser(c *gin.Context, jwtSecret string) (string, error) {
	tokenString := strings.TrimSpace(c.Query("token"))
	if tokenString == "" {
		authHeader := c.GetHeader("Authorization")
		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) == 2 && parts[0] == "Bearer" {
			tokenString = parts[1]
		}
	}
	if tokenString == "" {
		return "", errors.New("missing token")
	}

	token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, jwt.ErrSignatureInvalid
		}
		return []byte(jwtSecret), nil
	})
	if err != nil || !token.Valid {
		return "", errors.New("invalid token")
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return "", errors.New("invalid claims")
	}

	userID, ok := claims["sub"].(string)
	if !ok || strings.TrimSpace(userID) == "" {
		return "", errors.New("missing subject")
	}

	return userID, nil
}
