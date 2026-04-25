package handlers

import (
	"buzzcart/internal/models"
	"database/sql"
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/lib/pq"
)

const (
	messageTypeText        = "text"
	messageTypeProductLink = "product_link"
	messageTypeImage       = "image"
)

func SendMessage(db *sql.DB, hub *MessageHub) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		var req models.MessageCreate
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		if err := validateMessageRequest(userID, req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		tx, err := db.Begin()
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start message transaction"})
			return
		}
		defer tx.Rollback()

		connected, err := usersAreMutualConnections(tx, userID, req.ReceiverID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to verify connection status"})
			return
		}
		if !connected {
			c.JSON(http.StatusForbidden, gin.H{"error": "Messaging is currently limited to mutual connections"})
			return
		}

		conversationID, err := getOrCreateConversation(tx, userID, req.ReceiverID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create conversation"})
			return
		}

		metadataJSON, err := marshalMessageMetadata(req.Metadata)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid message metadata"})
			return
		}

		now := time.Now().UTC()
		messageID := uuid.New().String()
		messageType := normalizeMessageType(req.MessageType)

		_, err = tx.Exec(
			`INSERT INTO messages (id, conversation_id, sender_id, message_text, message_type, product_id, metadata, is_read, created_at)
			 VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb, $8, $9)`,
			messageID,
			conversationID,
			userID,
			strings.TrimSpace(req.Content),
			messageType,
			req.ProductID,
			string(metadataJSON),
			false,
			now,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to send message"})
			return
		}

		_, err = tx.Exec(
			`UPDATE conversations
			 SET last_message_at = $2, updated_at = $2
			 WHERE id = $1`,
			conversationID,
			now,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update conversation"})
			return
		}

		if err := tx.Commit(); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to finalize message"})
			return
		}

		message, err := fetchMessageByID(db, conversationID, messageID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Message created but could not be loaded"})
			return
		}

		if hub != nil {
			hub.PublishMessage(conversationID, []string{userID, req.ReceiverID}, message)
		}

		c.JSON(http.StatusCreated, message)
	}
}

func GetConnections(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		rows, err := db.Query(
			`SELECT
				u.id,
				u.name,
				u.avatar,
				conv.id
			FROM users u
			JOIN user_follows outgoing
				ON outgoing.following_id = u.id
				AND outgoing.follower_id = $1
			JOIN user_follows incoming
				ON incoming.follower_id = u.id
				AND incoming.following_id = $1
			LEFT JOIN conversations conv
				ON (conv.participant_1_id = $1 AND conv.participant_2_id = u.id)
				OR (conv.participant_1_id = u.id AND conv.participant_2_id = $1)
			WHERE u.id <> $1
			ORDER BY LOWER(u.name) ASC`,
			userID,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch connections"})
			return
		}
		defer rows.Close()

		connections := []models.ConversationConnection{}
		for rows.Next() {
			var connection models.ConversationConnection
			var conversationID sql.NullString
			if err := rows.Scan(&connection.ID, &connection.Name, &connection.Avatar, &conversationID); err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode connections"})
				return
			}
			if conversationID.Valid {
				connection.ConversationID = &conversationID.String
				connection.HasExistingConversation = true
			}
			connection.Avatar = readableMediaURLPtr(connection.Avatar)
			connections = append(connections, connection)
		}

		c.JSON(http.StatusOK, connections)
	}
}

func GetConversations(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		rows, err := db.Query(
			`SELECT
				conv.id,
				conv.updated_at,
				other.id,
				other.name,
				other.avatar,
				COALESCE(unread.unread_count, 0),
				last_msg.id,
				last_msg.sender_id,
				CASE
					WHEN last_msg.sender_id = conv.participant_1_id THEN conv.participant_2_id
					ELSE conv.participant_1_id
				END AS receiver_id,
				last_msg.message_text,
				last_msg.message_type,
				last_msg.product_id,
				last_msg.metadata,
				last_msg.is_read,
				last_msg.created_at,
				prod.id,
				prod.title,
				prod.price,
				COALESCE((
					SELECT ARRAY_AGG(pi.image_url ORDER BY pi.display_order)
					FROM product_images pi
					WHERE pi.product_id = prod.id
				), ARRAY[]::text[])
			FROM conversations conv
			JOIN users other
				ON other.id = CASE
					WHEN conv.participant_1_id = $1 THEN conv.participant_2_id
					ELSE conv.participant_1_id
				END
			LEFT JOIN LATERAL (
				SELECT
					m.id,
					m.sender_id,
					m.message_text,
					m.message_type,
					m.product_id,
					m.metadata,
					m.is_read,
					m.created_at
				FROM messages m
				WHERE m.conversation_id = conv.id
				ORDER BY m.created_at DESC
				LIMIT 1
			) last_msg ON true
			LEFT JOIN products prod ON prod.id = last_msg.product_id
			LEFT JOIN LATERAL (
				SELECT COUNT(*) AS unread_count
				FROM messages unread_messages
				WHERE unread_messages.conversation_id = conv.id
					AND unread_messages.sender_id <> $1
					AND unread_messages.is_read = FALSE
			) unread ON true
			WHERE conv.participant_1_id = $1 OR conv.participant_2_id = $1
			ORDER BY COALESCE(conv.last_message_at, conv.updated_at, conv.created_at) DESC`,
			userID,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch conversations"})
			return
		}
		defer rows.Close()

		conversations := []models.ConversationSummary{}
		for rows.Next() {
			conversation, err := scanConversationSummary(rows)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode conversations"})
				return
			}
			conversations = append(conversations, conversation)
		}

		c.JSON(http.StatusOK, conversations)
	}
}

func GetMessages(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		conversationID := c.Param("conversation_id")

		participant, err := getConversationParticipant(db, conversationID, userID)
		if err != nil {
			switch {
			case errors.Is(err, sql.ErrNoRows):
				c.JSON(http.StatusNotFound, gin.H{"error": "Conversation not found"})
			default:
				c.JSON(http.StatusForbidden, gin.H{"error": "You do not have access to this conversation"})
			}
			return
		}

		_, _ = db.Exec(
			`UPDATE messages
			 SET is_read = TRUE
			 WHERE conversation_id = $1
				AND sender_id <> $2
				AND is_read = FALSE`,
			conversationID,
			userID,
		)

		rows, err := db.Query(
			`SELECT
				m.id,
				m.conversation_id,
				m.sender_id,
				CASE
					WHEN m.sender_id = conv.participant_1_id THEN conv.participant_2_id
					ELSE conv.participant_1_id
				END AS receiver_id,
				m.message_text,
				m.message_type,
				m.product_id,
				m.metadata,
				m.created_at,
				m.is_read,
				prod.id,
				prod.title,
				prod.price,
				COALESCE((
					SELECT ARRAY_AGG(pi.image_url ORDER BY pi.display_order)
					FROM product_images pi
					WHERE pi.product_id = prod.id
				), ARRAY[]::text[])
			FROM messages m
			JOIN conversations conv ON conv.id = m.conversation_id
			LEFT JOIN products prod ON prod.id = m.product_id
			WHERE m.conversation_id = $1
			ORDER BY m.created_at ASC`,
			conversationID,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch messages"})
			return
		}
		defer rows.Close()

		messages := []models.Message{}
		for rows.Next() {
			message, err := scanMessage(rows)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode messages"})
				return
			}
			messages = append(messages, message)
		}

		if len(messages) == 0 {
			messages = []models.Message{}
		}

		c.JSON(http.StatusOK, gin.H{
			"conversation_id": conversationID,
			"participant":     participant,
			"messages":        messages,
		})
	}
}

func validateMessageRequest(senderID string, req models.MessageCreate) error {
	if strings.TrimSpace(req.ReceiverID) == "" {
		return errors.New("receiver_id is required")
	}
	if req.ReceiverID == senderID {
		return errors.New("cannot message yourself")
	}

	messageType := normalizeMessageType(req.MessageType)
	content := strings.TrimSpace(req.Content)

	switch messageType {
	case messageTypeText:
		if content == "" {
			return errors.New("content is required for text messages")
		}
	case messageTypeProductLink:
		if req.ProductID == nil {
			return errors.New("product_id is required for product shares")
		}
	case messageTypeImage:
		if content == "" && len(req.Metadata) == 0 {
			return errors.New("image shares require content or metadata")
		}
	default:
		return errors.New("unsupported message_type")
	}

	if content == "" && req.ProductID == nil && len(req.Metadata) == 0 {
		return errors.New("message must include content or share payload")
	}

	return nil
}

func normalizeMessageType(messageType string) string {
	switch strings.TrimSpace(messageType) {
	case "", messageTypeText:
		return messageTypeText
	case messageTypeProductLink:
		return messageTypeProductLink
	case messageTypeImage:
		return messageTypeImage
	default:
		return messageTypeText
	}
}

func orderedParticipants(userA, userB string) (string, string) {
	if userA < userB {
		return userA, userB
	}
	return userB, userA
}

func usersAreMutualConnections(q interface {
	QueryRow(query string, args ...any) *sql.Row
}, userA, userB string) (bool, error) {
	var connected bool
	err := q.QueryRow(
		`SELECT EXISTS(
			SELECT 1
			FROM user_follows outgoing
			JOIN user_follows incoming
				ON incoming.follower_id = outgoing.following_id
				AND incoming.following_id = outgoing.follower_id
			WHERE outgoing.follower_id = $1
				AND outgoing.following_id = $2
		)`,
		userA,
		userB,
	).Scan(&connected)
	return connected, err
}

func getOrCreateConversation(tx *sql.Tx, userA, userB string) (string, error) {
	participant1, participant2 := orderedParticipants(userA, userB)

	var conversationID string
	err := tx.QueryRow(
		`SELECT id
		 FROM conversations
		 WHERE participant_1_id = $1 AND participant_2_id = $2`,
		participant1,
		participant2,
	).Scan(&conversationID)
	if err == nil {
		return conversationID, nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return "", err
	}

	conversationID = uuid.New().String()
	now := time.Now().UTC()
	_, err = tx.Exec(
		`INSERT INTO conversations (id, participant_1_id, participant_2_id, created_at, updated_at)
		 VALUES ($1, $2, $3, $4, $4)`,
		conversationID,
		participant1,
		participant2,
		now,
	)
	return conversationID, err
}

func getConversationParticipant(db *sql.DB, conversationID, userID string) (models.ConversationParticipant, error) {
	var participant models.ConversationParticipant
	err := db.QueryRow(
		`SELECT other.id, other.name, other.avatar
		 FROM conversations conv
		 JOIN users other
			ON other.id = CASE
				WHEN conv.participant_1_id = $2 THEN conv.participant_2_id
				ELSE conv.participant_1_id
			END
		 WHERE conv.id = $1
			AND (conv.participant_1_id = $2 OR conv.participant_2_id = $2)`,
		conversationID,
		userID,
	).Scan(&participant.ID, &participant.Name, &participant.Avatar)
	participant.Avatar = readableMediaURLPtr(participant.Avatar)
	return participant, err
}

func getConversationParticipants(db *sql.DB, conversationID string) ([]string, error) {
	var participant1, participant2 string
	err := db.QueryRow(
		`SELECT participant_1_id, participant_2_id
		 FROM conversations
		 WHERE id = $1`,
		conversationID,
	).Scan(&participant1, &participant2)
	if err != nil {
		return nil, err
	}
	return []string{participant1, participant2}, nil
}

func fetchMessageByID(db *sql.DB, conversationID, messageID string) (models.Message, error) {
	row := db.QueryRow(
		`SELECT
			m.id,
			m.conversation_id,
			m.sender_id,
			CASE
				WHEN m.sender_id = conv.participant_1_id THEN conv.participant_2_id
				ELSE conv.participant_1_id
			END AS receiver_id,
			m.message_text,
			m.message_type,
			m.product_id,
			m.metadata,
			m.created_at,
			m.is_read,
			prod.id,
			prod.title,
			prod.price,
			COALESCE((
				SELECT ARRAY_AGG(pi.image_url ORDER BY pi.display_order)
				FROM product_images pi
				WHERE pi.product_id = prod.id
			), ARRAY[]::text[])
		FROM messages m
		JOIN conversations conv ON conv.id = m.conversation_id
		LEFT JOIN products prod ON prod.id = m.product_id
		WHERE m.conversation_id = $1 AND m.id = $2`,
		conversationID,
		messageID,
	)
	return scanMessage(row)
}

func marshalMessageMetadata(metadata map[string]any) ([]byte, error) {
	if len(metadata) == 0 {
		return []byte("{}"), nil
	}
	return json.Marshal(metadata)
}

func scanConversationSummary(scanner interface {
	Scan(dest ...any) error
}) (models.ConversationSummary, error) {
	var summary models.ConversationSummary
	var (
		lastMessageID sql.NullString
		senderID      sql.NullString
		receiverID    sql.NullString
		content       sql.NullString
		messageType   sql.NullString
		productID     sql.NullString
		metadataBytes []byte
		createdAt     sql.NullTime
		isRead        sql.NullBool
		productRowID  sql.NullString
		productTitle  sql.NullString
		productPrice  sql.NullFloat64
		productImages []string
	)

	err := scanner.Scan(
		&summary.ID,
		&summary.UpdatedAt,
		&summary.Participant.ID,
		&summary.Participant.Name,
		&summary.Participant.Avatar,
		&summary.UnreadCount,
		&lastMessageID,
		&senderID,
		&receiverID,
		&content,
		&messageType,
		&productID,
		&metadataBytes,
		&isRead,
		&createdAt,
		&productRowID,
		&productTitle,
		&productPrice,
		pq.Array(&productImages),
	)
	if err != nil {
		return summary, err
	}
	summary.Participant.Avatar = readableMediaURLPtr(summary.Participant.Avatar)

	if lastMessageID.Valid {
		summary.LastMessage = &models.Message{
			ID:             lastMessageID.String,
			ConversationID: summary.ID,
			SenderID:       senderID.String,
			ReceiverID:     receiverID.String,
			Content:        content.String,
			MessageType:    normalizeMessageType(messageType.String),
			CreatedAt:      createdAt.Time,
			Read:           isRead.Bool,
			Metadata:       unmarshalMessageMetadata(metadataBytes),
		}
		if productID.Valid {
			summary.LastMessage.ProductID = &productID.String
		}
		if productRowID.Valid {
			summary.LastMessage.Product = &models.ProductSimple{
				ID:    productRowID.String,
				Title: productTitle.String,
				Price: productPrice.Float64,
				Image: readableMediaURL(firstImage(productImages)),
			}
		}
	}

	return summary, nil
}

func scanMessage(scanner interface {
	Scan(dest ...any) error
}) (models.Message, error) {
	var (
		message       models.Message
		receiverID    string
		productID     sql.NullString
		metadataBytes []byte
		productRowID  sql.NullString
		productTitle  sql.NullString
		productPrice  sql.NullFloat64
		productImages []string
	)

	err := scanner.Scan(
		&message.ID,
		&message.ConversationID,
		&message.SenderID,
		&receiverID,
		&message.Content,
		&message.MessageType,
		&productID,
		&metadataBytes,
		&message.CreatedAt,
		&message.Read,
		&productRowID,
		&productTitle,
		&productPrice,
		pq.Array(&productImages),
	)
	if err != nil {
		return message, err
	}

	message.ReceiverID = receiverID
	message.Metadata = unmarshalMessageMetadata(metadataBytes)
	if productID.Valid {
		message.ProductID = &productID.String
	}
	if productRowID.Valid {
		message.Product = &models.ProductSimple{
			ID:    productRowID.String,
			Title: productTitle.String,
			Price: productPrice.Float64,
			Image: readableMediaURL(firstImage(productImages)),
		}
	}

	return message, nil
}

func unmarshalMessageMetadata(raw []byte) map[string]any {
	if len(raw) == 0 {
		return nil
	}
	var metadata map[string]any
	if err := json.Unmarshal(raw, &metadata); err != nil {
		return nil
	}
	if len(metadata) == 0 {
		return nil
	}
	return metadata
}

func firstImage(images []string) string {
	if len(images) == 0 {
		return ""
	}
	return images[0]
}
