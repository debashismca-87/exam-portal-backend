# 🎓 Full-Stack Exam Portal

A robust, full-stack online examination platform built with **Flutter (Web/Mobile)**, **Node.js**, and **PostgreSQL**. 

This platform supports role-based access control, allowing Teachers to create and manage exams (including bulk CSV uploads) and Students to take timed assessments with real-time auto-grading.

---

## ✨ Features

### 👨‍🏫 Teacher / Admin Portal
* **Create & Manage Exams:** Define exam titles, descriptions, duration, and passing marks.
* **Dynamic Question Builder:** Add multiple-choice questions natively within the UI.
* **Bulk Question Upload:** Upload massive question banks instantly via CSV parsing.
* **Full CRUD Operations:** Edit existing exams or safely delete deprecated test materials.

### 👩‍🎓 Student Portal
* **Live Dashboard:** View all available, active exams.
* **Interactive Quiz Interface:** Clean, distraction-free testing environment.
* **Auto-Grading:** Instant score calculation and pass/fail status upon submission.
* **Result History:** Dedicated dashboard tracking past attempts and scores.

### 🔐 Security & Architecture
* **JWT Authentication:** Secure login routing and protected API endpoints.
* **Role-Based Access Control (RBAC):** UI and API routes dynamically adapt based on `STUDENT`, `TEACHER`, or `ADMIN` roles.
* **Relational Database Integrity:** Prisma ORM ensures relational safety (e.g., cascading deletes for questions when an exam is removed).

---

## 🛠️ Tech Stack

**Frontend**
* [Flutter](https://flutter.dev/) (Dart) - Cross-platform UI compilation (Web/Android/iOS)
* `http` - API networking
* `shared_preferences` - Local token storage

**Backend**
* [Node.js](https://nodejs.org/) & [Express.js](https://expressjs.com/) - REST API architecture
* [Prisma ORM (v6)](https://www.prisma.io/) - Type-safe database querying and schema management
* [Neon](https://neon.tech/) - Serverless Cloud PostgreSQL
* `jsonwebtoken` & `bcryptjs` - Auth & Cryptography
* `multer` & `csv-parser` - File system and data streaming

---

## 📂 Project Structure (Monorepo)

```text
foundation/
│
├── exam_portal_app/       # Frontend: Flutter Application
│   ├── lib/               # Dart source code (UI, State, API Calls)
│   └── pubspec.yaml       # Flutter dependencies
│
├── prisma/                # Database: Prisma Schema & Migrations
│   └── schema.prisma      # PostgreSQL data models
│
├── src/                   # Backend: Node.js/Express Source Code
│   ├── server.js          # App entry point
│   ├── auth.js            # Authentication routes (Login/Register)
│   ├── exams.js           # Exam CRUD & bulk upload routes
│   └── middleware.js      # JWT verification middleware
│
├── .env                   # Environment variables (Ignored in Git)
└── package.json           # Node.js dependencies