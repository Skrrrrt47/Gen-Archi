const express = require("express");
const sqlite3 = require("sqlite3").verbose();
const bodyParser = require("body-parser");
const path = require("path");
const helmet = require("helmet");

const app = express();
const port = 3000;

// Use Helmet to set Content Security Policy
app.use(helmet());

// Serve static files from the 'public' folder
app.use(express.static(path.join(__dirname, "public")));

// Middleware to parse JSON bodies
app.use(bodyParser.json());

// Set up SQLite database
const db = new sqlite3.Database("db.sqlite");

// Create a simple table for demo purposes
db.serialize(() => {
  db.run(
    "CREATE TABLE IF NOT EXISTS names (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)"
  );
});

// Get all data from the DB
app.get("/data", (req, res) => {
  db.all("SELECT name FROM names", [], (err, rows) => {
    if (err) {
      return res.status(500).json({ error: err.message });
    }
    res.json(rows);
  });
});

// Insert new data into the DB
app.post("/data", (req, res) => {
  const { name } = req.body;
  db.run("INSERT INTO names (name) VALUES (?)", [name], function (err) {
    if (err) {
      return res.status(500).json({ error: err.message });
    }
    res.json({ id: this.lastID, name });
  });
});

// Handle favicon requests (suppress errors)
app.get("/favicon.ico", (req, res) => res.status(204).end());

// Start the server
app.listen(port, () => {
  console.log(`Server running at http://localhost:${port}`);
});
