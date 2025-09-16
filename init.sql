-- This file serves as documentation and backup for database schema
-- The actual table creation is handled automatically by the Node.js application
-- See app.js initializeDatabase() function

CREATE DATABASE IF NOT EXISTS myappdb;

USE myappdb;

CREATE TABLE IF NOT EXISTS inquiries (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
    email VARCHAR(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
    inquiry VARCHAR(256) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
    CONSTRAINT CHK_Email CHECK (
        email REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,20}$'
    )
);
