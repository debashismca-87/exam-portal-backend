const express = require('express');
const cors = require('cors');
const authRoutes = require('./auth'); // Import the auth file
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json());

// Routes
app.use('/api/auth', require('./auth'));
app.use('/api/exams', require('./exams')); // Add this line

// Health Check
app.get('/api/health', (req, res) => {
    res.json({ status: "active", message: "Online Exam Portal API is running smoothly." });
});

// Start Server
app.listen(PORT, () => {
    console.log(`🚀 Server securely running on port ${PORT}`);
});