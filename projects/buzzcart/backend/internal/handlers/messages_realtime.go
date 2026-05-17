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
	"github.com/gorilla/websocket"
)

const (
	messageSocketWriteWait           = 10 * time.Second
	messageSocketPongWait            = 75 * time.Second
	messageSocketPingPeriod          = 25 * time.Second
	messageSocketHandshakeWait       = 10 * time.Second
	messageSocketMaxMessageSize      = 8 * 1024
	messageSocketHeartbeatIntervalMS = 15000
)

type MessageHub struct {
	db                  *sql.DB
	mu                  sync.RWMutex
	clients             map[*messageSocketClient]struct{}
	userClients         map[string]map[*messageSocketClient]struct{}
	conversationViewers map[string]map[string]int
	conversationMembers map[string][]string
	activeUsers         map[string]int
	presenceTTL         time.Duration
}

type messageSocketClient struct {
	conn               *websocket.Conn
	hub                *MessageHub
	userID             string
	send               chan []byte
	activeConversation string
	lastPresencePing   time.Time
	isAppActive        bool
	closeConnOnce      sync.Once
	closeSendOnce      sync.Once
}

type messageSocketInbound struct {
	Type           string `json:"type"`
	ConversationID string `json:"conversation_id,omitempty"`
	IsTyping       bool   `json:"is_typing,omitempty"`
	IsActive       bool   `json:"is_active,omitempty"`
}

func NewMessageHub(db *sql.DB) *MessageHub {
	hub := &MessageHub{
		db:                  db,
		clients:             make(map[*messageSocketClient]struct{}),
		userClients:         make(map[string]map[*messageSocketClient]struct{}),
		conversationViewers: make(map[string]map[string]int),
		conversationMembers: make(map[string][]string),
		activeUsers:         make(map[string]int),
		presenceTTL:         40 * time.Second,
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
	h.setAppActive(client, false)

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

func (h *MessageHub) setAppActive(client *messageSocketClient, isActive bool) {
	if h == nil || h.db == nil {
		return
	}

	if isActive && !canShareActiveStatus(h.db, client.userID) {
		isActive = false
	}

	h.mu.Lock()
	previouslyActive := client.isAppActive
	if previouslyActive == isActive {
		if isActive {
			client.lastPresencePing = time.Now()
		}
		effectiveActive := h.activeUsers[client.userID] > 0
		h.mu.Unlock()
		if isActive && effectiveActive {
			return
		}
		return
	}

	client.isAppActive = isActive
	if isActive {
		client.lastPresencePing = time.Now()
		h.activeUsers[client.userID]++
	} else {
		client.lastPresencePing = time.Time{}
		if h.activeUsers[client.userID] > 1 {
			h.activeUsers[client.userID]--
		} else {
			delete(h.activeUsers, client.userID)
		}
	}
	effectiveActive := h.activeUsers[client.userID] > 0
	h.mu.Unlock()

	recipients := getActiveStatusRecipients(h.db, client.userID)
	h.broadcastToUsers(recipients, map[string]any{
		"type":      "app_presence",
		"user_id":   client.userID,
		"is_active": effectiveActive,
	})
}

func (h *MessageHub) SetActiveConversation(client *messageSocketClient, conversationID string, participants []string) {
	h.mu.Lock()
	oldConversationID := client.activeConversation
	now := time.Now()
	if oldConversationID == conversationID {
		client.lastPresencePing = now
		if conversationID != "" && len(participants) > 0 {
			h.conversationMembers[conversationID] = uniqueNonEmptyStrings(participants)
		}
		h.mu.Unlock()
		h.broadcastConversationPresence(conversationID)
		return
	}

	h.removeActiveConversationLocked(client)

	if conversationID != "" {
		if len(participants) > 0 {
			h.conversationMembers[conversationID] = uniqueNonEmptyStrings(participants)
		}
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
	recipients := append([]string(nil), h.conversationMembers[conversationID]...)
	activeUserIDs := make([]string, 0, len(viewerCounts))
	for userID := range viewerCounts {
		activeUserIDs = append(activeUserIDs, userID)
	}
	h.mu.RUnlock()

	if len(recipients) == 0 {
		recipients = activeUserIDs
	}

	h.broadcastToUsers(recipients, map[string]any{
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
			delete(h.conversationMembers, client.activeConversation)
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

func (c *messageSocketClient) sendJSON(payload any) {
	encoded, err := json.Marshal(payload)
	if err != nil {
		return
	}

	select {
	case c.send <- encoded:
	default:
		go c.close()
	}
}

func (c *messageSocketClient) readLoop(db *sql.DB) {
	c.conn.SetReadLimit(messageSocketMaxMessageSize)
	_ = c.conn.SetReadDeadline(time.Now().Add(messageSocketPongWait))
	c.conn.SetPongHandler(func(string) error {
		return c.conn.SetReadDeadline(time.Now().Add(messageSocketPongWait))
	})

	for {
		_, payload, err := c.conn.ReadMessage()
		if err != nil {
			return
		}

		_ = c.conn.SetReadDeadline(time.Now().Add(messageSocketPongWait))

		var inbound messageSocketInbound
		if err := json.Unmarshal(payload, &inbound); err != nil {
			continue
		}

		handleSocketInbound(db, c.hub, c, inbound)
	}
}

func (c *messageSocketClient) writeLoop() {
	ticker := time.NewTicker(messageSocketPingPeriod)
	defer ticker.Stop()

	for {
		select {
		case payload, ok := <-c.send:
			_ = c.conn.SetWriteDeadline(time.Now().Add(messageSocketWriteWait))
			if !ok {
				_ = c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			if err := c.conn.WriteMessage(websocket.TextMessage, payload); err != nil {
				return
			}
		case <-ticker.C:
			_ = c.conn.SetWriteDeadline(time.Now().Add(messageSocketWriteWait))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

func MessagesSocket(db *sql.DB, jwtSecret string, allowedOrigins []string, hub *MessageHub) gin.HandlerFunc {
	allowAllOrigins, allowedOriginSet := buildAllowedOriginSet(allowedOrigins)
	upgrader := websocket.Upgrader{
		HandshakeTimeout: messageSocketHandshakeWait,
		ReadBufferSize:   1024,
		WriteBufferSize:  1024,
		CheckOrigin: func(r *http.Request) bool {
			return isWebSocketOriginAllowed(r, allowAllOrigins, allowedOriginSet)
		},
		EnableCompression: false,
	}

	return func(c *gin.Context) {
		userID, err := authenticateSocketUser(c, jwtSecret)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid websocket token"})
			return
		}

		initialConversationID := strings.TrimSpace(c.Query("conversation_id"))

		ws, err := upgrader.Upgrade(c.Writer, c.Request, nil)
		if err != nil {
			return
		}

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

		if initialConversationID != "" && canAccessConversation(db, userID, initialConversationID) {
			participants, err := getConversationParticipants(db, initialConversationID)
			if err == nil {
				hub.SetActiveConversation(client, initialConversationID, participants)
			}
		}

		client.sendJSON(map[string]any{
			"type":                  "welcome",
			"user_id":               userID,
			"heartbeat_interval_ms": messageSocketHeartbeatIntervalMS,
			"server_time":           time.Now().UTC().Format(time.RFC3339),
		})
		hub.sendInitialAppPresence(client)

		if client.activeConversation != "" {
			hub.broadcastConversationPresence(client.activeConversation)
		}

		client.readLoop(db)
	}
}

func handleSocketInbound(db *sql.DB, hub *MessageHub, client *messageSocketClient, inbound messageSocketInbound) {
	conversationID := strings.TrimSpace(inbound.ConversationID)

	switch strings.TrimSpace(inbound.Type) {
	case "ping":
		client.sendJSON(map[string]any{
			"type":        "pong",
			"server_time": time.Now().UTC().Format(time.RFC3339),
		})
		if client.isAppActive {
			hub.setAppActive(client, true)
		}
	case "open_conversation":
		if conversationID != "" && canAccessConversation(db, client.userID, conversationID) {
			participants, err := getConversationParticipants(db, conversationID)
			if err != nil {
				return
			}
			hub.SetActiveConversation(client, conversationID, participants)
		}
	case "close_conversation":
		if conversationID == "" || client.activeConversation == conversationID {
			hub.SetActiveConversation(client, "", nil)
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
	case "app_state":
		hub.setAppActive(client, inbound.IsActive)
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
	expiredClients := make([]*messageSocketClient, 0)

	h.mu.Lock()
	for client := range h.clients {
		if !client.isAppActive || client.lastPresencePing.IsZero() {
			continue
		}
		if now.Sub(client.lastPresencePing) <= h.presenceTTL {
			continue
		}
		if client.activeConversation != "" {
			affectedConversations[client.activeConversation] = struct{}{}
		}
		expiredClients = append(expiredClients, client)
	}
	h.mu.Unlock()

	for _, client := range expiredClients {
		h.setAppActive(client, false)
	}

	for conversationID := range affectedConversations {
		h.broadcastConversationPresence(conversationID)
	}
}

func buildAllowedOriginSet(allowedOrigins []string) (bool, map[string]struct{}) {
	allowAllOrigins := len(allowedOrigins) == 0
	allowedOriginSet := make(map[string]struct{}, len(allowedOrigins))

	for _, origin := range allowedOrigins {
		trimmed := strings.TrimSpace(origin)
		if trimmed == "" {
			continue
		}
		if trimmed == "*" {
			allowAllOrigins = true
			continue
		}
		allowedOriginSet[trimmed] = struct{}{}
	}

	return allowAllOrigins, allowedOriginSet
}

func isWebSocketOriginAllowed(request *http.Request, allowAllOrigins bool, allowedOriginSet map[string]struct{}) bool {
	origin := strings.TrimSpace(request.Header.Get("Origin"))
	if origin == "" {
		return true
	}
	if allowAllOrigins {
		return true
	}
	_, ok := allowedOriginSet[origin]
	return ok
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

func uniqueNonEmptyStrings(values []string) []string {
	seen := make(map[string]struct{}, len(values))
	result := make([]string, 0, len(values))
	for _, value := range values {
		value = strings.TrimSpace(value)
		if value == "" {
			continue
		}
		if _, exists := seen[value]; exists {
			continue
		}
		seen[value] = struct{}{}
		result = append(result, value)
	}
	return result
}

func canShareActiveStatus(db *sql.DB, userID string) bool {
	var status string
	var visibilityPreferencesRaw string
	err := db.QueryRow(
		`SELECT
			COALESCE(status::text, 'active'),
			COALESCE(visibility_preferences::text, '{"photos": true, "videos": true, "reels": true, "purchases": true, "active_status": true}')
		 FROM users
		 WHERE id = $1`,
		userID,
	).Scan(&status, &visibilityPreferencesRaw)
	if err != nil {
		return false
	}
	if !strings.EqualFold(status, "active") {
		return false
	}

	preferences := parseVisibilityPreferences(visibilityPreferencesRaw, "custom")
	return preferences[preferenceActiveStatus]
}

func getActiveStatusRecipients(db *sql.DB, userID string) []string {
	return getActiveStatusPeerIDs(db, userID)
}

func getActiveStatusPeerIDs(db *sql.DB, userID string) []string {
	rows, err := db.Query(
		`SELECT DISTINCT other_user_id
		 FROM (
			SELECT
				CASE
					WHEN conv.participant_1_id = $1 THEN conv.participant_2_id
					ELSE conv.participant_1_id
				END AS other_user_id
			FROM conversations conv
			WHERE conv.participant_1_id = $1 OR conv.participant_2_id = $1

			UNION

			SELECT u.id AS other_user_id
			FROM users u
			JOIN user_follows outgoing
				ON outgoing.following_id = u.id
				AND outgoing.follower_id = $1
			JOIN user_follows incoming
				ON incoming.follower_id = u.id
				AND incoming.following_id = $1
			WHERE u.id <> $1
		) peers`,
		userID,
	)
	if err != nil {
		return nil
	}
	defer rows.Close()

	recipients := make([]string, 0)
	for rows.Next() {
		var recipientID string
		if err := rows.Scan(&recipientID); err != nil {
			continue
		}
		recipients = append(recipients, recipientID)
	}

	return uniqueNonEmptyStrings(recipients)
}

func (h *MessageHub) sendInitialAppPresence(client *messageSocketClient) {
	if h == nil || h.db == nil || client == nil {
		return
	}

	peerIDs := getActiveStatusPeerIDs(h.db, client.userID)
	if len(peerIDs) == 0 {
		return
	}

	h.mu.RLock()
	defer h.mu.RUnlock()

	for _, peerID := range peerIDs {
		if h.activeUsers[peerID] <= 0 {
			continue
		}
		client.sendJSON(map[string]any{
			"type":      "app_presence",
			"user_id":   peerID,
			"is_active": true,
		})
	}
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
