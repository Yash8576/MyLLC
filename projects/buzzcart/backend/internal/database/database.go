package database

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"time"

	_ "github.com/lib/pq"
)

var db *sql.DB

const (
	// DefaultQueryTimeout is the default timeout for database queries
	DefaultQueryTimeout = 10 * time.Second
	// LongQueryTimeout is for complex queries that may take longer
	LongQueryTimeout = 30 * time.Second
)

// Connect establishes a connection to the PostgreSQL database
func Connect(dbURL string) (*sql.DB, error) {
	var err error
	db, err = sql.Open("postgres", dbURL)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	// Set connection pool settings for production
	db.SetMaxOpenConns(25)                 // Maximum number of open connections
	db.SetMaxIdleConns(5)                  // Maximum number of idle connections
	db.SetConnMaxLifetime(5 * time.Minute) // Maximum connection lifetime
	db.SetConnMaxIdleTime(1 * time.Minute) // Maximum idle time

	// Ping the database to verify connection
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err = db.PingContext(ctx); err != nil {
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	log.Println("✓ Successfully connected to PostgreSQL")
	return db, nil
}

// Disconnect closes the database connection
func Disconnect() {
	if db != nil {
		if err := db.Close(); err != nil {
			log.Printf("Error closing PostgreSQL connection: %v", err)
		} else {
			log.Println("✓ PostgreSQL connection closed")
		}
	}
}

// GetDB returns the database connection
func GetDB() *sql.DB {
	return db
}

// NewContext creates a new context with the default timeout
func NewContext() (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), DefaultQueryTimeout)
}

// NewLongContext creates a new context with extended timeout for complex queries
func NewLongContext() (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), LongQueryTimeout)
}
