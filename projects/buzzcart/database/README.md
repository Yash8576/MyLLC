# Like2Share Database Documentation

## Overview
The Like2Share database is built on PostgreSQL and includes tables for users, posts, likes, shares, comments, and social features.

## Database Schema

### Tables

#### 1. **users**
Stores user account information.
- `id` (UUID): Primary key
- `username` (VARCHAR): Unique username
- `email` (VARCHAR): Unique email (optional if mobile is provided)
- `mobile_number` (VARCHAR): Unique mobile number (optional if email is provided)
- `password_hash` (VARCHAR): Hashed password
- `bio` (TEXT): User biography
- `profile_pic_url` (VARCHAR): Profile picture URL
- `created_at` (TIMESTAMPTZ): Account creation timestamp
- `updated_at` (TIMESTAMPTZ): Last update timestamp

**Constraints:**
- Must provide either email OR mobile_number
- Username must be unique
- Automatic `updated_at` trigger

#### 2. **posts**
Stores user posts/content.
- `id` (UUID): Primary key
- `user_id` (UUID): Foreign key to users
- `title` (VARCHAR): Post title
- `content` (TEXT): Post content
- `media_url` (VARCHAR): URL to media file
- `media_type` (VARCHAR): Type of media (image, video, etc.)
- `like_count` (INTEGER): Number of likes (auto-updated)
- `share_count` (INTEGER): Number of shares (auto-updated)
- `view_count` (INTEGER): Number of views
- `is_published` (BOOLEAN): Publication status
- `is_deleted` (BOOLEAN): Soft delete flag
- `created_at` (TIMESTAMPTZ): Post creation timestamp
- `updated_at` (TIMESTAMPTZ): Last update timestamp

**Triggers:**
- Auto-updates `like_count` on likes table changes
- Auto-updates `share_count` on shares table changes
- Auto-updates `updated_at` on modification

#### 3. **likes**
Tracks post likes by users.
- `id` (UUID): Primary key
- `user_id` (UUID): Foreign key to users
- `post_id` (UUID): Foreign key to posts
- `created_at` (TIMESTAMPTZ): Like timestamp

**Constraints:**
- Unique combination of (user_id, post_id) - one like per user per post

#### 4. **shares**
Tracks post shares by users.
- `id` (UUID): Primary key
- `user_id` (UUID): Foreign key to users
- `post_id` (UUID): Foreign key to posts
- `share_message` (TEXT): Optional message when sharing
- `created_at` (TIMESTAMPTZ): Share timestamp

#### 5. **comments**
Stores comments on posts with support for nested replies.
- `id` (UUID): Primary key
- `user_id` (UUID): Foreign key to users
- `post_id` (UUID): Foreign key to posts
- `content` (TEXT): Comment content
- `parent_comment_id` (UUID): Foreign key to comments (for replies)
- `is_deleted` (BOOLEAN): Soft delete flag
- `created_at` (TIMESTAMPTZ): Comment creation timestamp
- `updated_at` (TIMESTAMPTZ): Last update timestamp

#### 6. **followers**
Manages follower/following relationships.
- `id` (UUID): Primary key
- `follower_id` (UUID): Foreign key to users (who is following)
- `following_id` (UUID): Foreign key to users (who is being followed)
- `created_at` (TIMESTAMPTZ): Follow timestamp

**Constraints:**
- Unique combination of (follower_id, following_id)
- Users cannot follow themselves

## Setup Instructions

### Using Docker Compose (Recommended for Development)

1. **Windows:**
   ```bash
   scripts\setup-database.bat
   ```

2. **Linux/Mac:**
   ```bash
   chmod +x scripts/setup-database.sh
   ./scripts/setup-database.sh
   ```

### Manual Setup

1. **Create .env file:**
   ```bash
   cp .env.example .env
   ```
   Edit `.env` and set your database credentials.

2. **Start database:**
   ```bash
   cd docker
   docker-compose up -d postgres
   ```

3. **Verify:**
   ```bash
   docker exec like2share_db psql -U like2share_user -d like2share_db -c "\dt"
   ```

### Using Kubernetes

1. **Create namespace:**
   ```bash
   kubectl apply -f k8s/namespace.yaml
   ```

2. **Apply secrets (update passwords first!):**
   ```bash
   kubectl apply -f k8s/secrets.yaml
   ```

3. **Apply ConfigMaps:**
   ```bash
   kubectl apply -f k8s/configmap.yaml
   ```

4. **Deploy PostgreSQL:**
   ```bash
   kubectl apply -f k8s/postgres/
   ```

## Migrations

Migrations are located in `database/migrations/` and run automatically when the database initializes:

- `001_init.sql`: Creates users table and base functions
- `002_add_share_count.sql`: Creates posts, likes, shares, comments, and followers tables

To add new migrations:
1. Create a new file: `003_your_migration_name.sql`
2. Follow the naming convention with incrementing numbers
3. Migrations run in alphabetical/numerical order

## Database Connection

### Development
```
Host: localhost
Port: 5432
Database: like2share_db
User: like2share_user
Password: like2share_dev_password
```

Connection string:
```
postgres://like2share_user:like2share_dev_password@localhost:5432/like2share_db?sslmode=disable
```

### Production
Use environment variables from `.env` file and enable SSL:
```
postgres://like2share_user:${POSTGRES_PASSWORD}@postgres:5432/like2share_db?sslmode=require
```

## Useful Commands

### Access PostgreSQL CLI
```bash
docker exec -it like2share_db psql -U like2share_user -d like2share_db
```

### List all tables
```sql
\dt
```

### Describe table structure
```sql
\d users
\d posts
```

### View table data
```sql
SELECT * FROM users;
SELECT * FROM posts;
```

### Backup database
```bash
docker exec like2share_db pg_dump -U like2share_user like2share_db > backup.sql
```

### Restore database
```bash
docker exec -i like2share_db psql -U like2share_user like2share_db < backup.sql
```

## Performance Considerations

The schema includes several indexes for optimal query performance:
- User lookups by username and email
- Post queries by user, creation date, and publication status
- Like/share lookups by user and post
- Comment queries with nested reply support
- Follower relationship queries

## Security Notes

1. **Always use hashed passwords** - Never store plain text passwords
2. **Use environment variables** for sensitive data
3. **Enable SSL in production** - Set `sslmode=require`
4. **Regular backups** - Implement automated backup strategy
5. **Update secrets** - Change default passwords in production

## Troubleshooting

### Database won't start
```bash
docker-compose logs postgres
```

### Connection refused
- Ensure Docker is running
- Check if port 5432 is available
- Verify credentials in `.env` file

### Migrations not running
- Check `docker logs like2share_db`
- Verify migration files have correct permissions
- Ensure migrations are in correct order

## Support

For issues and questions, refer to the main project README or create an issue in the repository.
