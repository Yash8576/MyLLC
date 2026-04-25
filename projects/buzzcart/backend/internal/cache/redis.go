package cache

import (
	"context"
	"time"

	"github.com/redis/go-redis/v9"
)

var (
	client *redis.Client
	ctx    = context.Background()
)

// InitRedis initializes the Redis client
func InitRedis(redisURL string) error {
	opt, err := redis.ParseURL(redisURL)
	if err != nil {
		return err
	}

	if opt.DialTimeout == 0 {
		opt.DialTimeout = 200 * time.Millisecond
	}
	if opt.ReadTimeout == 0 {
		opt.ReadTimeout = 200 * time.Millisecond
	}
	if opt.WriteTimeout == 0 {
		opt.WriteTimeout = 200 * time.Millisecond
	}

	client = redis.NewClient(opt)

	// Test connection
	_, err = client.Ping(ctx).Result()
	if err != nil {
		_ = client.Close()
		client = nil
		return err
	}

	return nil
}

// GetClient returns the Redis client instance
func GetClient() *redis.Client {
	return client
}

// Set stores a value in Redis with a TTL
func Set(key string, value interface{}, ttl time.Duration) error {
	if client == nil {
		return nil
	}
	return client.Set(ctx, key, value, ttl).Err()
}

// Get retrieves a value from Redis
func Get(key string) (string, error) {
	if client == nil {
		return "", redis.Nil
	}
	return client.Get(ctx, key).Result()
}

// Delete removes a key from Redis
func Delete(keys ...string) error {
	if client == nil {
		return nil
	}
	return client.Del(ctx, keys...).Err()
}

// Close closes the Redis client connection
func Close() error {
	if client != nil {
		return client.Close()
	}
	return nil
}
