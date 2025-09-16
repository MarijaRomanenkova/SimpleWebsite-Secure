import express from "express";
import cors from "cors";
import { fileURLToPath } from "url";
import path from "path";
import mysql from 'mysql2/promise';

// Resolve __dirname for ES Modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = process.env.PORT || 3000;

const MAX_RETRIES = 5;
const RETRY_DELAY = 5000; // 5 seconds

async function connectWithRetry(retries = MAX_RETRIES) {
  try {
    const connection = await mysql.createConnection({
      host: process.env.DB_HOST,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME
    });
    console.log('Successfully connected to MySQL');
    return connection;
  } catch (err) {
    if (retries > 0) {
      console.log(`MySQL connection failed, retrying... (${retries} attempts left)`);
      await new Promise(resolve => setTimeout(resolve, RETRY_DELAY));
      return connectWithRetry(retries - 1);
    }
    console.error('MySQL connection failed after all retries:', err);
    throw err;
  }
}

// Add this after your database connection setup
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

// Use it in your app
const db = await connectWithRetry();
await initializeDatabase();

app.use(cors());
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ 
    error: 'Internal Server Error', 
    message: err.message 
  });
});

app.use(express.json({ extended: true }));

// Serve static files (CSS, JS, etc.)
app.use(express.static(path.join(__dirname, 'public')));

app.get("/inquiries", async (req, res) => {
  const [data] = await db.query("SELECT * FROM inquiries");
  res.send(data);
});

app.get("/", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "index.html"));
});

app.get('/test-db', async (req, res) => {
  try {
    const [rows] = await db.query('SELECT 1');
    res.send('Database connection is working');
  } catch (error) {
    console.error('Error connecting to the database:', error);
    res.status(500).send('Database connection failed');
  }
});

app.post("/inquiries/", async (req, res) => {
  const { name, email, inquiry} = req.body;

  if (!name || !email || !inquiry) {
    return res.status(400).send("Please provide a name, email, and content");
  }

  

  try {
    const [result] = await db.execute(
      "INSERT INTO inquiries (name, email, inquiry) VALUES (?,?,?)",
      [name, email, inquiry]
    );
    res.send({ success: result.affectedRows > 0 });
  } catch (error) {
    console.error("Database query error:", error); // More detailed error logging
    res.status(500).send({ error: "Database query failed", message: error.message });
  }
});


app.patch("/inquiries/:id", async (req, res) => {
  const { id } = req.params;
  const { name } = req.body;
  if (isNaN(id) || !name) return res.status(400).send("Bad request");

  const [data] = await db.execute("UPDATE inquiries SET name = ? WHERE id = ?", [
    name,
    id,
  ]);
  res.send({ success: data.affectedRows > 0 });
});

app.delete("/inquiries/:id", async (req, res) => {
  const { id } = req.params;
  const [data] = await db.execute("DELETE FROM inquiries WHERE id=?", [id]);
  res.send({ success: data.affectedRows > 0 });
});

app.get('/health', async (req, res) => {
  try {
    await db.query('SELECT 1');
    res.status(200).json({ status: 'healthy' });
  } catch (error) {
    res.status(500).json({ status: 'unhealthy', error: error.message });
  }
});

app.get("/messages", async (req, res) => {
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

process.on("unhandledRejection", (reason, promise) => {
  console.error("Unhandled Rejection at:", promise, "reason:", reason);
});

app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
