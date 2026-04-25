package handlers

import (
	"buzzcart/internal/models"
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

func getProductStockQuantity(db *sql.DB, productID string) (int, error) {
	product, err := getProductForCart(db, productID)
	if err != nil {
		return 0, err
	}

	if product.StockQuantity < 0 {
		return 0, nil
	}

	return product.StockQuantity, nil
}

func getProductForCart(db *sql.DB, productID string) (models.Product, error) {
	product, err := getProductByID(db, productID)
	if err != nil {
		product, err = getProductByIDLegacy(db, productID)
		if err != nil {
			return models.Product{}, err
		}
	}

	return product, nil
}

func applyProductSnapshotToCartItem(item *models.CartItem, product models.Product) bool {
	changed := false

	image := ""
	if len(product.Images) > 0 {
		image = product.Images[0]
	}

	if item.Price != product.Price {
		item.Price = product.Price
		changed = true
	}

	compareChanged := false
	switch {
	case item.CompareAtPrice == nil && product.CompareAtPrice == nil:
		compareChanged = false
	case item.CompareAtPrice == nil || product.CompareAtPrice == nil:
		compareChanged = true
	case *item.CompareAtPrice != *product.CompareAtPrice:
		compareChanged = true
	}
	if compareChanged {
		item.CompareAtPrice = product.CompareAtPrice
		changed = true
	}

	if item.Title != product.Title {
		item.Title = product.Title
		changed = true
	}

	if item.SellerName != product.SellerName {
		item.SellerName = product.SellerName
		changed = true
	}

	if item.Image != image {
		item.Image = image
		changed = true
	}

	if item.StockQuantity != product.StockQuantity {
		item.StockQuantity = product.StockQuantity
		changed = true
	}

	if item.Quantity > product.StockQuantity {
		item.Quantity = product.StockQuantity
		changed = true
	}

	return changed
}

func GetCart(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		// Log the user_id for debugging
		fmt.Printf("GetCart - user_id from context: %s\n", userID)

		if userID == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
			return
		}

		var itemsJSON []byte
		var updatedAt time.Time
		err := db.QueryRow("SELECT items, updated_at FROM carts WHERE user_id = $1", userID).Scan(&itemsJSON, &updatedAt)

		if err == sql.ErrNoRows {
			// Return empty cart if not found
			c.JSON(http.StatusOK, models.CartResponse{
				Items:     []models.CartItem{},
				Subtotal:  0,
				Discount:  0,
				Total:     0,
				ItemCount: 0,
			})
			return
		} else if err != nil {
			fmt.Printf("GetCart - Database error: %v\n", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to fetch cart: %v", err)})
			return
		}

		var items []models.CartItem
		if err := json.Unmarshal(itemsJSON, &items); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to parse cart items"})
			return
		}

		itemsChanged := false
		for i := range items {
			product, productErr := getProductForCart(db, items[i].ProductID)
			if productErr != nil {
				continue
			}
			if applyProductSnapshotToCartItem(&items[i], product) {
				itemsChanged = true
			}
		}

		if itemsChanged {
			itemsData, marshalErr := json.Marshal(items)
			if marshalErr == nil {
				_, _ = db.Exec(
					"UPDATE carts SET items = $1, updated_at = $2 WHERE user_id = $3",
					itemsData, time.Now(), userID,
				)
			}
		}

		// Calculate totals
		subtotal := 0.0
		discount := 0.0
		total := 0.0
		itemCount := 0
		for _, item := range items {
			originalPrice := item.Price
			if item.CompareAtPrice != nil && *item.CompareAtPrice > item.Price {
				originalPrice = *item.CompareAtPrice
			}

			lineSubtotal := originalPrice * float64(item.Quantity)
			lineTotal := item.Price * float64(item.Quantity)
			lineDiscount := lineSubtotal - lineTotal

			subtotal += lineSubtotal
			discount += lineDiscount
			total += lineTotal
			itemCount += item.Quantity
		}

		c.JSON(http.StatusOK, models.CartResponse{
			Items:     items,
			Subtotal:  subtotal,
			Discount:  discount,
			Total:     total,
			ItemCount: itemCount,
		})
	}
}

func AddToCart(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		var req models.CartItemAdd
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		if req.Quantity <= 0 {
			req.Quantity = 1
		}

		// Get product details using schema-aware product queries.
		product, err := getProductByID(db, req.ProductID)
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
			return
		}
		if err != nil {
			product, err = getProductByIDLegacy(db, req.ProductID)
			if err == sql.ErrNoRows {
				c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
				return
			}
			if err != nil {
				fmt.Printf("AddToCart - Failed to fetch product %s: %v\n", req.ProductID, err)
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch product"})
				return
			}
		}

		image := ""
		if len(product.Images) > 0 {
			image = product.Images[0]
		}

		cartItem := models.CartItem{
			ProductID:      product.ID,
			Title:          product.Title,
			Price:          product.Price,
			CompareAtPrice: product.CompareAtPrice,
			SellerName:     product.SellerName,
			Image:          image,
			Quantity:       req.Quantity,
			StockQuantity:  product.StockQuantity,
		}

		if product.StockQuantity <= 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Product is out of stock"})
			return
		}

		if cartItem.Quantity > product.StockQuantity {
			cartItem.Quantity = product.StockQuantity
		}

		// Find or create cart
		var itemsJSON []byte
		err = db.QueryRow("SELECT items FROM carts WHERE user_id = $1", userID).Scan(&itemsJSON)

		var items []models.CartItem
		if err == sql.ErrNoRows {
			// Create new cart
			items = []models.CartItem{cartItem}
			itemsData, _ := json.Marshal(items)
			_, err = db.Exec(
				"INSERT INTO carts (user_id, items, updated_at) VALUES ($1, $2, $3)",
				userID, itemsData, time.Now(),
			)
		} else if err == nil {
			// Update existing cart
			json.Unmarshal(itemsJSON, &items)
			found := false
			for i, item := range items {
				if item.ProductID == req.ProductID {
					updatedQty := item.Quantity + req.Quantity
					if updatedQty > product.StockQuantity {
						updatedQty = product.StockQuantity
					}
					applyProductSnapshotToCartItem(&items[i], product)
					items[i].Quantity = updatedQty
					found = true
					break
				}
			}

			if !found {
				items = append(items, cartItem)
			}

			itemsData, _ := json.Marshal(items)
			_, err = db.Exec(
				"UPDATE carts SET items = $1, updated_at = $2 WHERE user_id = $3",
				itemsData, time.Now(), userID,
			)
		}

		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to add to cart"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Added to cart"})
	}
}

func RemoveFromCart(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		var req struct {
			ProductID string `json:"product_id" binding:"required"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// Get current cart items
		var itemsJSON []byte
		err := db.QueryRow("SELECT items FROM carts WHERE user_id = $1", userID).Scan(&itemsJSON)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Cart not found"})
			return
		}

		var items []models.CartItem
		json.Unmarshal(itemsJSON, &items)

		// Remove item
		newItems := []models.CartItem{}
		for _, item := range items {
			if item.ProductID != req.ProductID {
				newItems = append(newItems, item)
			}
		}

		itemsData, _ := json.Marshal(newItems)
		_, err = db.Exec("UPDATE carts SET items = $1, updated_at = $2 WHERE user_id = $3", itemsData, time.Now(), userID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to remove from cart"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Removed from cart"})
	}
}

func UpdateCartItem(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		var req struct {
			ProductID string `json:"product_id" binding:"required"`
			Quantity  int    `json:"quantity" binding:"required,gt=0"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		stockQty, stockErr := getProductStockQuantity(db, req.ProductID)
		if stockErr == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
			return
		}
		if stockErr != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch product"})
			return
		}

		if stockQty <= 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Product is out of stock"})
			return
		}

		if req.Quantity > stockQty {
			req.Quantity = stockQty
		}

		product, productErr := getProductForCart(db, req.ProductID)
		if productErr == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
			return
		}
		if productErr != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch product"})
			return
		}

		// Get current cart items
		var itemsJSON []byte
		err := db.QueryRow("SELECT items FROM carts WHERE user_id = $1", userID).Scan(&itemsJSON)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Cart not found"})
			return
		}

		var items []models.CartItem
		json.Unmarshal(itemsJSON, &items)

		// Update quantity
		for i, item := range items {
			if item.ProductID == req.ProductID {
				applyProductSnapshotToCartItem(&items[i], product)
				items[i].Quantity = req.Quantity
				break
			}
		}

		itemsData, _ := json.Marshal(items)
		_, err = db.Exec("UPDATE carts SET items = $1, updated_at = $2 WHERE user_id = $3", itemsData, time.Now(), userID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update cart"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Cart updated"})
	}
}

func ClearCart(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		_, err := db.Exec("DELETE FROM carts WHERE user_id = $1", userID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to clear cart"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Cart cleared"})
	}
}
