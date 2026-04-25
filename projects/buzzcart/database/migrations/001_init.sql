-- This command enables the "uuid-ossp" extension if it's not already enabled.
-- This extension provides functions to generate universally unique identifiers (UUIDs).
-- We'll use UUIDs as the primary key for our users table for unique, non-sequential IDs.
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- This block defines a reusable function named "update_updated_at_column".
-- This function is designed to be used as a trigger.
-- When triggered, it updates the "updated_at" column of a row to the current timestamp.
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
   -- 'NEW' is a special variable in PostgreSQL triggers that holds the new database row for INSERT/UPDATE operations.
   -- This line sets the 'updated_at' field of the row being inserted or updated to the current time.
   NEW.updated_at = NOW();
   -- This returns the modified row, allowing the INSERT or UPDATE operation to proceed.
   RETURN NEW;
END;
$$ language 'plpgsql';

-- This command creates the "users" table, which will store information about each user.
-- 'CREATE TABLE' is the standard SQL command to create a new table in the database.
CREATE TABLE users (
    -- 'id' will be the unique identifier for each user. It's the primary key for this table.
    -- 'UUID' is the data type for the ID, a 128-bit number that is unique across tables and databases.
    -- 'PRIMARY KEY' constraint ensures that each 'id' is unique and not null.
    -- 'DEFAULT uuid_generate_v4()' automatically generates a new version 4 UUID for each new user record.
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- 'username' will store the user's public name.
    -- 'VARCHAR(50)' is a text field with a maximum length of 50 characters.
    -- 'UNIQUE' ensures no two users can have the same username.
    -- 'NOT NULL' means this field cannot be empty.
    username VARCHAR(50) UNIQUE NOT NULL,

    -- 'email' will store the user's email address.
    -- 'VARCHAR(255)' allows for a standard email length.
    -- 'UNIQUE' ensures no two users can register with the same email address.
    email VARCHAR(255) UNIQUE,

    -- 'mobile_number' will store the user's mobile phone number.
    -- 'VARCHAR(20)' provides enough space for a phone number including country code.
    -- 'UNIQUE' ensures no two users can have the same mobile number.
    mobile_number VARCHAR(20) UNIQUE,

    -- 'password_hash' will store the user's password in a securely hashed format.
    -- 'VARCHAR(255)' provides enough space for common hashing algorithm outputs.
    -- 'NOT NULL' means a password is required for every user.
    -- IMPORTANT: Never store plain-text passwords. This field is for a hash.
    password_hash VARCHAR(255) NOT NULL,

    -- 'bio' will store a short biography or description for the user's profile.
    -- 'TEXT' is used for longer-form text with no predefined length limit.
    bio TEXT,

    -- 'profile_pic_url' will store the URL to the user's profile picture.
    -- 'VARCHAR(255)' is typically sufficient for a URL.
    profile_pic_url VARCHAR(255),

    -- 'created_at' is a timestamp that records when the user account was created.
    -- 'TIMESTAMPTZ' is a timestamp with time zone information.
    -- 'NOT NULL DEFAULT NOW()' automatically sets this to the current time when a user is created.
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- 'updated_at' is a timestamp that records the last time the user's information was updated.
    -- 'TIMESTAMPTZ' is a timestamp with time zone information.
    -- 'NOT NULL DEFAULT NOW()' sets an initial value, which will be updated by the trigger.
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- This is a 'CHECK' constraint to enforce a business rule.
    -- It ensures that a user must provide either an email or a mobile number to register.
    -- One of them can be NULL, but not both.
    CONSTRAINT email_or_mobile_check CHECK (email IS NOT NULL OR mobile_number IS NOT NULL)
);

-- This command creates a trigger named "update_users_updated_at".
-- A trigger is an automated action that the database performs when a certain operation occurs.
-- 'BEFORE UPDATE ON users' means this trigger will fire just before any row in the 'users' table is updated.
-- 'FOR EACH ROW' specifies that the trigger should be executed for each row that is being updated.
-- 'EXECUTE FUNCTION update_updated_at_column()' specifies that the "update_updated_at_column" function we defined earlier should be called.
-- This setup automates keeping the 'updated_at' field current.
CREATE TRIGGER update_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- This command creates an index on the 'username' column of the 'users' table.
-- Indexes are used to speed up the retrieval of rows by providing quick access to data.
-- An index on 'username' is useful because we will likely search for users by their username frequently.
CREATE INDEX idx_users_username ON users(username);

-- This command creates an index on the 'email' column of the 'users' table.
-- This will speed up lookups based on a user's email address, for example, during login or when checking for duplicate emails.
CREATE INDEX idx_users_email ON users(email);