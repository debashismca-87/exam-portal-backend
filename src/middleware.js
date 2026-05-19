const jwt = require('jsonwebtoken');
const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_key_change_me';

const authenticateToken = (req, res, next) => {
    // 1. Look for the token in the headers
    const authHeader = req.headers['authorization'];
    
    // The header usually looks like: "Bearer eyJhbGciOiJIUzI1..."
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
        return res.status(401).json({ error: "Access denied. No token provided." });
    }

    // 2. Verify the token is real and hasn't expired
    jwt.verify(token, JWT_SECRET, (err, user) => {
        if (err) {
            return res.status(403).json({ error: "Invalid or expired token." });
        }

        // 3. Attach the user data to the request so the next function can use it
        req.user = user;
        
        // 4. Let them pass to the actual route
        next();
    });
};

module.exports = authenticateToken;