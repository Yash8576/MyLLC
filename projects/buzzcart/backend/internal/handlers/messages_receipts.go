package handlers

import (
	"database/sql"
	"sync"
	"time"
)

var (
	messageReceiptsOnce sync.Once
	messageReceiptsErr  error
)

// EnsureMessageReceiptsSchema adds the delivered_at column used for
// WhatsApp-style receipts (sent -> delivered -> read) on first call.
// The error is cached — a startup failure is fatal (schema won't be retried).
func EnsureMessageReceiptsSchema(db *sql.DB) error {
	messageReceiptsOnce.Do(func() {
		statements := []string{
			`ALTER TABLE messages
				ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMP WITH TIME ZONE`,
			`UPDATE messages
				SET delivered_at = created_at
				WHERE is_read = TRUE AND delivered_at IS NULL`,
			`CREATE INDEX IF NOT EXISTS idx_messages_undelivered
				ON messages(conversation_id)
				WHERE delivered_at IS NULL`,
		}
		for _, statement := range statements {
			if _, err := db.Exec(statement); err != nil {
				messageReceiptsErr = err
				return
			}
		}
	})
	return messageReceiptsErr
}

// markUndeliveredMessagesDelivered flags every message addressed to userID
// that hasn't reached them yet as delivered (their device just came online /
// synced), then tells each affected sender so their ticks flip to double.
func markUndeliveredMessagesDelivered(db *sql.DB, hub *MessageHub, userID string) {
	rows, err := db.Query(
		`UPDATE messages m
		 SET delivered_at = NOW()
		 FROM conversations c
		 WHERE c.id = m.conversation_id
			AND (c.participant_1_id = $1 OR c.participant_2_id = $1)
			AND m.sender_id <> $1
			AND m.delivered_at IS NULL
		 RETURNING m.conversation_id, m.sender_id`,
		userID,
	)
	if err != nil {
		return
	}
	defer rows.Close()

	// conversation -> sender of the undelivered messages in it
	sendersByConversation := make(map[string]map[string]struct{})
	for rows.Next() {
		var conversationID, senderID string
		if err := rows.Scan(&conversationID, &senderID); err != nil {
			continue
		}
		if sendersByConversation[conversationID] == nil {
			sendersByConversation[conversationID] = make(map[string]struct{})
		}
		sendersByConversation[conversationID][senderID] = struct{}{}
	}

	if hub == nil {
		return
	}
	for conversationID, senders := range sendersByConversation {
		recipients := make([]string, 0, len(senders))
		for senderID := range senders {
			recipients = append(recipients, senderID)
		}
		hub.broadcastToUsers(recipients, map[string]any{
			"type":            "messages_delivered",
			"conversation_id": conversationID,
			"delivered_at":    time.Now().UTC().Format(time.RFC3339),
		})
	}
}

// markConversationMessagesRead marks every message addressed to readerID in
// the conversation as read (and implicitly delivered), then tells the other
// participant so their ticks flip to blue.
func markConversationMessagesRead(db *sql.DB, hub *MessageHub, conversationID, readerID string) {
	result, err := db.Exec(
		`UPDATE messages
		 SET is_read = TRUE,
			delivered_at = COALESCE(delivered_at, NOW())
		 WHERE conversation_id = $1
			AND sender_id <> $2
			AND is_read = FALSE`,
		conversationID,
		readerID,
	)
	if err != nil || hub == nil {
		return
	}
	if affected, err := result.RowsAffected(); err == nil && affected == 0 {
		return
	}

	participants, err := getConversationParticipants(db, conversationID)
	if err != nil {
		return
	}
	recipients := make([]string, 0, 1)
	for _, participantID := range participants {
		if participantID != readerID {
			recipients = append(recipients, participantID)
		}
	}
	hub.broadcastToUsers(recipients, map[string]any{
		"type":            "messages_read",
		"conversation_id": conversationID,
		"reader_id":       readerID,
		"read_at":         time.Now().UTC().Format(time.RFC3339),
	})
}

// IsUserConnected reports whether the user has at least one live socket —
// i.e. a pushed message will reach their device right now.
func (h *MessageHub) IsUserConnected(userID string) bool {
	if h == nil {
		return false
	}
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.userClients[userID]) > 0
}

// IsUserViewingConversation reports whether the user currently has the
// conversation open on screen — i.e. a pushed message is seen immediately.
func (h *MessageHub) IsUserViewingConversation(conversationID, userID string) bool {
	if h == nil {
		return false
	}
	h.mu.RLock()
	defer h.mu.RUnlock()
	return h.conversationViewers[conversationID][userID] > 0
}
