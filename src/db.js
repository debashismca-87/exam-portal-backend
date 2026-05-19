const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
require('dotenv').config();

// 1. Create the PostgreSQL adapter using your Neon connection string
const adapter = new PrismaPg({
    connectionString: process.env.DATABASE_URL
});

// 2. Initialize the Prisma Client with the adapter
const prisma = new PrismaClient({ adapter });

module.exports = prisma;