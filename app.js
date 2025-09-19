import express from "express";
import cors from "cors";
import { fileURLToPath } from "url";
import path from "path";
import mysql from 'mysql2/promise';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = process.env.PORT || 3000;

const MAX_RETRIES = 10;
const RETRY_DELAY = 10000;

let db = null;
let dbConnected = false;
let dbConnectionAttempts = 0;

console.log('=== ENVIRONMENT VARIABLES DEBUG ===');
console.log('DB_HOST:', process.env.DB_HOST);
console.log('DB_USER:', process.env.DB_USER);
console.log('DB_PASSWORD:', process.env.DB_PASSWORD ? '[SET]' : '[NOT SET]');
console.log('DB_NAME:', process.env.DB_NAME);
console.log('=====================================');

async function connectWithRetry(retries = MAX_RETRIES) {
  try {
    dbConnectionAttempts++;
    console.log(`Database connection attempt ${dbConnectionAttempts}...`);
    console.log(`Connecting to: ${process.env.DB_HOST}:3306`);
    console.log(`Database: ${process.env.DB_NAME}`);
    console.log(`User: ${process.env.DB_USER}`);
    
    const connection = await mysql.createConnection({
      host: process.env.DB_HOST,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME,
      connectTimeout: 10000,  // Reduced timeout
      acquireTimeout: 10000,
      timeout: 10000,
      // Add connection pool settings
      waitForConnections: true,
      connectionLimit: 10,
      queueLimit: 0
    });
    
    console.log('Successfully connected to MySQL');
    dbConnected = true;
    db = connection;
    
    await initializeDatabase();
    return connection;
  } catch (err) {
    console.error(`MySQL connection failed (attempt ${dbConnectionAttempts}): ${err.message}`);
    console.error(`Error code: ${err.code}`);
    console.error(`Error errno: ${err.errno}`);
    
    if (retries > 0) {
      console.log(`Retrying in ${RETRY_DELAY/1000} seconds... (${retries} attempts left)`);
      await new Promise(resolve => setTimeout(resolve, RETRY_DELAY));
      return connectWithRetry(retries - 1);
    }
    
    console.error('MySQL connection failed after all retries. App will continue without database.');
    dbConnected = false;
    db = null;
    return null;
  }
}

async function initializeDatabase() {
  try {
    console.log('Initializing database...');
    await db.execute(`
      CREATE TABLE IF NOT EXISTS inquiries (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
        email VARCHAR(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
        inquiry VARCHAR(256) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT CHK_Email CHECK (
          email REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,20}$'
        )
      )
    `);
    console.log('Database initialized successfully');
  } catch (error) {
    console.error('Database initialization error:', error);
    throw error;
  }
}

app.use(cors());
app.use(express.json({ extended: true }));
app.use(express.static(path.join(__dirname, 'public')));

app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ 
    error: 'Internal Server Error', 
    message: err.message 
  });
});

app.get("/", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "index.html"));
});

// Simple startup endpoint for debugging
app.get("/status", (req, res) => {
  res.status(200).json({
    status: 'running',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: {
      PORT: process.env.PORT,
      NODE_ENV: process.env.NODE_ENV || 'development'
    }
  });
});

app.get('/health', async (req, res) => {
  try {
    if (dbConnected && db) {
      await db.query('SELECT 1');
      res.status(200).json({ 
        status: 'healthy', 
        database: 'connected',
        attempts: dbConnectionAttempts,
        timestamp: new Date().toISOString()
      });
    } else {
      res.status(200).json({ 
        status: 'healthy', 
        database: 'disconnected',
        attempts: dbConnectionAttempts,
        message: 'Database connection in progress',
        timestamp: new Date().toISOString()
      });
    }
  } catch (error) {
    res.status(200).json({ 
      status: 'healthy', 
      database: 'error',
      attempts: dbConnectionAttempts,
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

app.get('/debug', (req, res) => {
  res.json({
    env_vars: {
      DB_HOST: process.env.DB_HOST,
      DB_USER: process.env.DB_USER,
      DB_PASSWORD: process.env.DB_PASSWORD ? '[SET]' : '[NOT SET]',
      DB_NAME: process.env.DB_NAME
    },
    db_status: {
      connected: dbConnected,
      attempts: dbConnectionAttempts
    }
  });
});

app.get('/test-connection', async (req, res) => {
  try {
    console.log('Testing database connection...');
    const connection = await mysql.createConnection({
      host: process.env.DB_HOST,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      connectTimeout: 5000
    });
    
    await connection.query('SELECT 1');
    await connection.end();
    
    res.json({ 
      status: 'success', 
      message: 'Database connection test successful (without database name)' 
    });
  } catch (error) {
    console.error('Database connection test failed:', error);
    res.json({ 
      status: 'error', 
      message: error.message,
      code: error.code,
      errno: error.errno,
      sqlState: error.sqlState
    });
  }
});

app.get('/test-db-creation', async (req, res) => {
  try {
    console.log('Testing database creation...');
    const connection = await mysql.createConnection({
      host: process.env.DB_HOST,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      connectTimeout: 5000
    });
    
    await connection.query(`CREATE DATABASE IF NOT EXISTS ${process.env.DB_NAME}`);
    await connection.query(`USE ${process.env.DB_NAME}`);
    await connection.query('SELECT 1');
    await connection.end();
    
    res.json({ 
      status: 'success', 
      message: 'Database creation and connection test successful' 
    });
  } catch (error) {
    console.error('Database creation test failed:', error);
    res.json({ 
      status: 'error', 
      message: error.message,
      code: error.code,
      errno: error.errno,
      sqlState: error.sqlState
    });
  }
});

app.get("/inquiries", async (req, res) => {
  if (!dbConnected || !db) {
    return res.status(503).json({ 
      error: 'Database not available',
      message: 'Database connection is being established. Please try again in a few moments.',
      attempts: dbConnectionAttempts
    });
  }
  
  try {
    const [data] = await db.query("SELECT * FROM inquiries ORDER BY created_at DESC");
    res.json(data);
  } catch (error) {
    console.error('Database query error:', error);
    res.status(500).json({ error: 'Database query failed' });
  }
});

app.post("/inquiries", async (req, res) => {
  if (!dbConnected || !db) {
    return res.status(503).json({ 
      error: 'Database not available',
      message: 'Database connection is being established. Your message will be saved once the connection is ready.',
      attempts: dbConnectionAttempts
    });
  }

  const { name, email, inquiry } = req.body;

  if (!name || !email || !inquiry) {
    return res.status(400).json({ 
      error: "Missing required fields",
      message: "Please provide name, email, and inquiry"
    });
  }

  try {
    const [result] = await db.execute(
      "INSERT INTO inquiries (name, email, inquiry) VALUES (?,?,?)",
      [name, email, inquiry]
    );
    res.json({ 
      success: result.affectedRows > 0,
      message: "Your message has been saved successfully!"
    });
  } catch (error) {
    console.error("Database query error:", error);
    res.status(500).json({ 
      error: "Database query failed", 
      message: error.message 
    });
  }
});

app.get('/test-db', async (req, res) => {
  if (!dbConnected || !db) {
    return res.status(503).json({ 
      status: 'Database not available',
      message: 'Connection will be retried automatically',
      attempts: dbConnectionAttempts
    });
  }
  
  try {
    const [rows] = await db.query('SELECT 1');
    res.json({ 
      status: 'Database connection is working',
      attempts: dbConnectionAttempts,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('Error connecting to the database:', error);
    res.status(500).json({ 
      status: 'Database connection failed',
      attempts: dbConnectionAttempts,
      error: error.message
    });
  }
});

app.patch("/inquiries/:id", async (req, res) => {
  if (!dbConnected || !db) {
    return res.status(503).json({ 
      error: 'Database not available',
      message: 'Please try again later'
    });
  }

  const { id } = req.params;
  const { name } = req.body;
  if (isNaN(id) || !name) return res.status(400).json({ error: "Bad request" });

  try {
    const [data] = await db.execute("UPDATE inquiries SET name = ? WHERE id = ?", [
      name,
      id,
    ]);
    res.json({ success: data.affectedRows > 0 });
  } catch (error) {
    console.error("Database query error:", error);
    res.status(500).json({ error: "Database query failed", message: error.message });
  }
});

app.delete("/inquiries/:id", async (req, res) => {
  if (!dbConnected || !db) {
    return res.status(503).json({ 
      error: 'Database not available',
      message: 'Please try again later'
    });
  }

  const { id } = req.params;
  try {
    const [data] = await db.execute("DELETE FROM inquiries WHERE id=?", [id]);
    res.json({ success: data.affectedRows > 0 });
  } catch (error) {
    console.error("Database query error:", error);
    res.status(500).json({ error: "Database query failed", message: error.message });
  }
});

app.get("/messages", async (req, res) => {
  if (!dbConnected || !db) {
    return res.status(503).json({ 
      success: false,
      error: "Database not available",
      message: "Please try again later"
    });
  }

  try {
    const [rows] = await db.execute("SELECT * FROM inquiries ORDER BY created_at DESC");
    res.json({
      success: true,
      messages: rows
    });
  } catch (error) {
    console.error("Error fetching messages:", error);
    res.status(500).json({
      success: false,
      error: "Failed to fetch messages"
    });
  }
});

process.on("SIGTERM", async () => {
  console.log("SIGTERM received, shutting down gracefully");
  if (db) {
    await db.end();
  }
  process.exit(0);
});

process.on("SIGINT", async () => {
  console.log("SIGINT received, shutting down gracefully");
  if (db) {
    await db.end();
  }
  process.exit(0);
});

process.on("unhandledRejection", (reason, promise) => {
  console.error("Unhandled Rejection at:", promise, "reason:", reason);
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server is running on port ${PORT} on all interfaces (0.0.0.0)`);
  console.log(`Database status: ${dbConnected ? 'Connected' : 'Disconnected'}`);
  
  // Start database connection in background without blocking
  setTimeout(async () => {
    try {
      console.log('Starting database connection in background...');
      await connectWithRetry();
    } catch (error) {
      console.error('Failed to start database connection:', error.message);
    }
  }, 2000);
});

// Handle server startup errors
app.on('error', (err) => {
  console.error('Server error:', err);
  if (err.code === 'EADDRINUSE') {
    console.error(`Port ${PORT} is already in use`);
  }
});

// Ensure the server doesn't crash on uncaught exceptions
process.on('uncaughtException', (err) => {
  console.error('Uncaught Exception:', err);
  // Don't exit the process, just log the error
});
