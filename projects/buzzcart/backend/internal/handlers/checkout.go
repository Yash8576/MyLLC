package handlers

import (
	"buzzcart/internal/database"
	"buzzcart/internal/models"
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type checkoutRequest struct {
	ShippingAddressLine1 string `json:"shipping_address_line1" binding:"required"`
	ShippingAddressLine2 string `json:"shipping_address_line2"`
	ShippingCity         string `json:"shipping_city" binding:"required"`
	ShippingState        string `json:"shipping_state" binding:"required"`
	ShippingPostalCode   string `json:"shipping_postal_code" binding:"required"`
	ShippingCountry      string `json:"shipping_country" binding:"required"`
	PhoneNumber          string `json:"phone_number"`
}

type checkoutResponse struct {
	OrderID     string  `json:"order_id"`
	OrderNumber string  `json:"order_number"`
	Subtotal    float64 `json:"subtotal"`
	Total       float64 `json:"total"`
	ItemCount   int     `json:"item_count"`
}

type checkoutLineItem struct {
	ProductID    string
	SellerID     string
	ProductTitle string
	ProductSKU   string
	ProductImage string
	Quantity     int
	UnitPrice    float64
	Subtotal     float64
}

func CheckoutCart(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		if strings.TrimSpace(userID) == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
			return
		}

		var req checkoutRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		var itemsJSON []byte
		if err := db.QueryRow("SELECT items FROM carts WHERE user_id = $1", userID).Scan(&itemsJSON); err != nil {
			if err == sql.ErrNoRows {
				c.JSON(http.StatusBadRequest, gin.H{"error": "Cart is empty"})
				return
			}
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load cart"})
			return
		}

		var cartItems []models.CartItem
		if err := json.Unmarshal(itemsJSON, &cartItems); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to parse cart"})
			return
		}

		if len(cartItems) == 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Cart is empty"})
			return
		}

		aggregated := make(map[string]int)
		productImageByID := make(map[string]string)
		for _, item := range cartItems {
			if item.Quantity <= 0 || strings.TrimSpace(item.ProductID) == "" {
				continue
			}
			aggregated[item.ProductID] += item.Quantity
			if _, exists := productImageByID[item.ProductID]; !exists {
				productImageByID[item.ProductID] = strings.TrimSpace(item.Image)
			}
		}

		if len(aggregated) == 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Cart is empty"})
			return
		}

		ctx, cancel := database.NewContext()
		defer cancel()

		tx, err := db.BeginTx(ctx, nil)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start checkout"})
			return
		}
		defer tx.Rollback()

		var buyerName string
		if err := tx.QueryRowContext(ctx, "SELECT COALESCE(name, username, '') FROM users WHERE id = $1", userID).Scan(&buyerName); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to resolve buyer"})
			return
		}

		lineItems := make([]checkoutLineItem, 0, len(aggregated))
		total := 0.0
		itemCount := 0

		for productID, quantity := range aggregated {
			var (
				lineItem checkoutLineItem
				stockQty int
				price    float64
			)

			err := tx.QueryRowContext(
				ctx,
				`SELECT id, seller_id, title, COALESCE(sku, ''), COALESCE(price, 0), COALESCE(stock_quantity, 0)
				 FROM products
				 WHERE id = $1 AND COALESCE(is_active, TRUE) = TRUE
				 FOR UPDATE`,
				productID,
			).Scan(&lineItem.ProductID, &lineItem.SellerID, &lineItem.ProductTitle, &lineItem.ProductSKU, &price, &stockQty)
			if err == sql.ErrNoRows {
				c.JSON(http.StatusNotFound, gin.H{"error": fmt.Sprintf("Product %s not found", productID)})
				return
			}
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch product"})
				return
			}

			if quantity > stockQty {
				c.JSON(http.StatusConflict, gin.H{
					"error":   fmt.Sprintf("Not enough stock for %s", lineItem.ProductTitle),
					"product": lineItem.ProductID,
					"stock":   stockQty,
				})
				return
			}

			lineItem.Quantity = quantity
			lineItem.ProductImage = productImageByID[productID]
			lineItem.UnitPrice = price
			lineItem.Subtotal = price * float64(quantity)
			lineItems = append(lineItems, lineItem)
			total += lineItem.Subtotal
			itemCount += quantity
		}

		orderID := uuid.NewString()
		orderNumber := fmt.Sprintf("BZC-%s", strings.ToUpper(strings.ReplaceAll(uuid.NewString()[:8], "-", "")))
		now := time.Now().UTC()
		phoneNumber := strings.TrimSpace(req.PhoneNumber)
		metadata := map[string]any{
			"phone_number": phoneNumber,
			"source":       "cart_checkout",
		}
		metadataJSON, _ := json.Marshal(metadata)

		if _, err := tx.ExecContext(
			ctx,
			`INSERT INTO orders (
				id, user_id, order_number, status, subtotal, tax, shipping, discount, total,
				currency, shipping_name, shipping_address_line1, shipping_address_line2,
				shipping_city, shipping_state, shipping_postal_code, shipping_country,
				payment_method, payment_status, notes, metadata, created_at, updated_at, completed_at
			) VALUES (
				$1, $2, $3, 'delivered', $4, 0, 0, 0, $5,
				'USD', $6, $7, $8,
				$9, $10, $11, $12,
				'manual', 'captured', 'Cart checkout', $13, $14, $14, $14
			)`,
			orderID,
			userID,
			orderNumber,
			total,
			total,
			buyerName,
			req.ShippingAddressLine1,
			req.ShippingAddressLine2,
			req.ShippingCity,
			req.ShippingState,
			req.ShippingPostalCode,
			req.ShippingCountry,
			metadataJSON,
			now,
		); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create order"})
			return
		}

		for _, lineItem := range lineItems {
			lineItemMetadata := map[string]any{
				"source": "cart_checkout",
			}
			if lineItem.ProductImage != "" {
				lineItemMetadata["product_image"] = lineItem.ProductImage
			}
			lineItemMetadataJSON, _ := json.Marshal(lineItemMetadata)

			if _, err := tx.ExecContext(
				ctx,
				`INSERT INTO order_items (
					id, order_id, product_id, seller_id, product_title, product_sku,
					quantity, unit_price, subtotal, metadata, created_at
				) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
				uuid.NewString(),
				orderID,
				lineItem.ProductID,
				lineItem.SellerID,
				lineItem.ProductTitle,
				lineItem.ProductSKU,
				lineItem.Quantity,
				lineItem.UnitPrice,
				lineItem.Subtotal,
				lineItemMetadataJSON,
				now,
			); err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create order items"})
				return
			}

			if _, err := tx.ExecContext(
				ctx,
				`UPDATE products
				 SET stock_quantity = stock_quantity - $1,
				     updated_at = $2
				 WHERE id = $3`,
				lineItem.Quantity,
				now,
				lineItem.ProductID,
			); err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update stock"})
				return
			}
		}

		if _, err := tx.ExecContext(ctx, `DELETE FROM carts WHERE user_id = $1`, userID); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to clear cart"})
			return
		}

		if err := tx.Commit(); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to complete checkout"})
			return
		}

		c.JSON(http.StatusOK, checkoutResponse{
			OrderID:     orderID,
			OrderNumber: orderNumber,
			Subtotal:    total,
			Total:       total,
			ItemCount:   itemCount,
		})
	}
}

func GetUserPurchases(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		currentUserID := c.GetString("user_id")
		profileUserID := c.Param("user_id")
		if strings.TrimSpace(profileUserID) == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "User ID required"})
			return
		}

		var targetStatus string
		var targetPrivacy string
		var visibilityMode string
		var visibilityPreferences string
		err := db.QueryRow(
			`SELECT
				COALESCE(status::text, 'active'),
				COALESCE(privacy_profile::text, 'public'),
				COALESCE(visibility_mode, 'public'),
				COALESCE(visibility_preferences::text, '{"photos": true, "videos": true, "reels": true, "purchases": true}')
			 FROM users
			 WHERE id = $1`,
			profileUserID,
		).Scan(&targetStatus, &targetPrivacy, &visibilityMode, &visibilityPreferences)
		if err != nil {
			if err == sql.ErrNoRows {
				c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
				return
			}
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load profile"})
			return
		}

		if currentUserID != profileUserID {
			if !strings.EqualFold(targetStatus, "active") {
				c.JSON(http.StatusForbidden, gin.H{"error": "This account is hibernated"})
				return
			}
			if strings.EqualFold(targetPrivacy, "private") {
				c.JSON(http.StatusForbidden, gin.H{"error": "This account is private"})
				return
			}
			if !visibilityBucketAllowed(visibilityMode, visibilityPreferences, contentBucketPurchases, false) {
				c.JSON(http.StatusForbidden, gin.H{"error": "Purchases are private"})
				return
			}
		}

		rows, err := db.Query(
			`SELECT
				oi.product_id,
				COALESCE(p.title, oi.product_title),
				oi.quantity,
				COALESCE(p.price, oi.unit_price),
				p.compare_at_price,
				o.created_at,
				COALESCE(u.id::text, ''),
				COALESCE(u.name, u.username, ''),
				COALESCE((
					SELECT ROUND(AVG(pr.rating)::NUMERIC, 1)::FLOAT8
					FROM product_ratings pr
					WHERE pr.product_id = oi.product_id
						AND pr.is_private = false
						AND pr.moderation_status = 'approved'
				), 0),
				COALESCE((
					SELECT COUNT(*)
					FROM product_ratings pr
					WHERE pr.product_id = oi.product_id
						AND pr.is_private = false
						AND pr.moderation_status = 'approved'
				), 0),
				COALESCE((
					SELECT pr.rating
					FROM product_ratings pr
					WHERE pr.product_id = oi.product_id
						AND pr.user_id = o.user_id
					LIMIT 1
				), 0),
				COALESCE(oi.metadata, '{}'::jsonb),
				COALESCE((
					SELECT pi.image_url
					FROM product_images pi
					WHERE pi.product_id = oi.product_id
					ORDER BY pi.is_primary DESC, pi.display_order ASC
					LIMIT 1
				), '')
			 FROM order_items oi
			 JOIN orders o ON o.id = oi.order_id
			 LEFT JOIN products p ON p.id = oi.product_id
			 LEFT JOIN users u ON u.id = oi.seller_id
			 WHERE o.user_id = $1
			   AND o.status IN ('delivered', 'completed')
			 ORDER BY o.created_at DESC, oi.created_at DESC
			 LIMIT 100`,
			profileUserID,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch purchases"})
			return
		}
		defer rows.Close()

		products := make([]models.Product, 0)
		for rows.Next() {
			var (
				product      models.Product
				quantity     int
				currentPrice float64
				compareAtRaw sql.NullFloat64
				purchasedAt  time.Time
				sellerID     string
				sellerName   string
				globalRating float64
				reviewsCount int
				yourRating   int
				itemMetaRaw  []byte
				fallbackImg  string
			)
			if err := rows.Scan(
				&product.ID,
				&product.Title,
				&quantity,
				&currentPrice,
				&compareAtRaw,
				&purchasedAt,
				&sellerID,
				&sellerName,
				&globalRating,
				&reviewsCount,
				&yourRating,
				&itemMetaRaw,
				&fallbackImg,
			); err != nil {
				continue
			}

			image := strings.TrimSpace(fallbackImg)
			if len(itemMetaRaw) > 0 {
				var itemMeta map[string]any
				if err := json.Unmarshal(itemMetaRaw, &itemMeta); err == nil {
					if img, ok := itemMeta["product_image"].(string); ok && strings.TrimSpace(img) != "" {
						image = strings.TrimSpace(img)
					}
				}
			}

			product.Description = ""
			product.Price = currentPrice
			if compareAtRaw.Valid && compareAtRaw.Float64 > currentPrice {
				compareAt := compareAtRaw.Float64
				product.CompareAtPrice = &compareAt
			}
			product.Currency = "USD"
			product.StockQuantity = quantity
			product.Condition = "purchased"
			product.Images = []string{}
			if image != "" {
				product.Images = []string{image}
			}
			product.Category = ""
			product.Tags = []string{}
			product.SellerID = sellerID
			product.SellerName = sellerName
			product.Rating = globalRating
			product.ReviewsCount = reviewsCount
			product.Views = 0
			product.Buys = quantity
			product.Metadata = map[string]any{
				"purchased_quantity": quantity,
				"your_rating":        yourRating,
			}
			product.CreatedAt = purchasedAt
			products = append(products, product)
		}

		c.JSON(http.StatusOK, products)
	}
}
