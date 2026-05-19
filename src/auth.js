const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const prisma = require('./db');

const router = express.Router();
const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_key_change_me';

// 1. REGISTER ENDPOINT
router.post('/register', async (req, res) => {
    try {
        const { name, email, password, role } = req.body;

        // Check if user already exists
        const existingUser = await prisma.user.findUnique({ where: { email } });
        if (existingUser) {
            return res.status(400).json({ error: "Email already registered." });
        }

        // Hash the password
        const hashedPassword = await bcrypt.hash(password, 10);

        // Create user in Neon DB
        const newUser = await prisma.user.create({
            data: {
                name,
                email,
                password: hashedPassword,
                role: role || 'STUDENT' // Defaults to STUDENT if not specified
            }
        });

        res.status(201).json({ message: "User registered successfully!", userId: newUser.id });
    } catch (error) {
        res.status(500).json({ error: "Registration failed.", details: error.message });
    }
});

// 2. LOGIN ENDPOINT
router.post('/login', async (req, res) => {
    try {
        const { email, password } = req.body;

        // Find user by email
        const user = await prisma.user.findUnique({ where: { email } });
        if (!user) {
            return res.status(400).json({ error: "Invalid email or password." });
        }

        // Compare password hashes
        const isPasswordValid = await bcrypt.compare(password, user.password);
        if (!isPasswordValid) {
            return res.status(400).json({ error: "Invalid email or password." });
        }

        // Generate a JWT Token valid for 24 hours
        const token = jwt.sign(
            { userId: user.id, role: user.role }, 
            JWT_SECRET, 
            { expiresIn: '24h' }
        );

        res.json({
            message: "Login successful!",
            token,
            user: { id: user.id, name: user.name, role: user.role }
        });
    } catch (error) {
        res.status(500).json({ error: "Login failed.", details: error.message });
    }
});

module.exports = router;