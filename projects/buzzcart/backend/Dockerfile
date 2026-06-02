# Backend Dockerfile - Go Multi-stage Build
FROM golang:1.25-alpine AS builder

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -o buzzcart ./cmd/server

# Final stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates && adduser -D -H -u 10001 appuser

WORKDIR /app

# Copy the binary from builder
COPY --from=builder /app/buzzcart .

# Expose port
EXPOSE 8080

USER appuser

# Run the application
CMD ["./buzzcart"]
