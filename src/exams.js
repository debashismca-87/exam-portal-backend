const express = require('express');
const router = express.Router();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const authenticateToken = require('./middleware'); // Assuming your middleware file is named middleware.js

// 1. GET ALL EXAMS (Protected)
router.get('/', authenticateToken, async (req, res) => {
    try {
        const exams = await prisma.exam.findMany({
            include: {
                _count: { select: { questions: true } }
            },
            orderBy: { id: 'desc' }
        });
        res.json(exams);
    } catch (error) {
        console.error("DATABASE ERROR:", error); // <-- Add this line!
        res.status(500).json({ error: "Failed to fetch exams." });
    }
});

// 2. CREATE A NEW EXAM (Protected: Teacher/Admin Only)
router.post('/create', authenticateToken, async (req, res) => {
    try {
        if (req.user.role !== 'TEACHER' && req.user.role !== 'ADMIN') {
            return res.status(403).json({ error: "Access denied. Only teachers can create exams." });
        }

        const { title, description, durationMins, passingMarks } = req.body;

        const newExam = await prisma.exam.create({
            data: { title, description, durationMins, passingMarks }
        });

        res.status(201).json({ message: "Exam created successfully!", exam: newExam });
    } catch (error) {
        res.status(500).json({ error: "Failed to create exam." });
    }
});

// 3. ADD A QUESTION TO AN EXAM (Protected: Teacher/Admin Only)
router.post('/:examId/questions', authenticateToken, async (req, res) => {
    try {
        if (req.user.role !== 'TEACHER' && req.user.role !== 'ADMIN') {
            return res.status(403).json({ error: "Access denied." });
        }

        const examId = parseInt(req.params.examId);
        const { questionText, options, correctOptionId, marks } = req.body;

        const newQuestion = await prisma.question.create({
            data: {
                examId,
                questionText,
                options,
                correctOptionId,
                marks: marks || 1
            }
        });

        res.status(201).json({ message: "Question added successfully!", question: newQuestion });
    } catch (error) {
        res.status(500).json({ error: "Failed to add question." });
    }
});

// 4. GET QUESTIONS FOR AN EXAM (Protected: Logged-in User)
// NOTE: We do NOT send the correctOptionId to the frontend!
router.get('/:examId/questions', authenticateToken, async (req, res) => {
    try {
        const examId = parseInt(req.params.examId);
        
        const questions = await prisma.question.findMany({
            where: { examId: examId },
            select: {
                id: true,
                questionText: true,
                options: true,
                marks: true
                // correctOptionId is intentionally left out!
            }
        });

        res.json(questions);
    } catch (error) {
        res.status(500).json({ error: "Failed to fetch questions." });
    }
});

// 5. SUBMIT EXAM & AUTO-GRADE (Protected: Student)
router.post('/:examId/submit', authenticateToken, async (req, res) => {
    try {
        const examId = parseInt(req.params.examId);
        const userId = req.user.userId;
        const { answers } = req.body; // Format expected: { "questionId": "selectedOptionId" }

        const exam = await prisma.exam.findUnique({ where: { id: examId } });
        const questions = await prisma.question.findMany({ where: { examId: examId } });

        let totalScore = 0;
        let correctAnswersCount = 0;

        questions.forEach((q) => {
            const studentAnswer = answers[q.id.toString()];
            if (studentAnswer === q.correctOptionId) {
                totalScore += q.marks;
                correctAnswersCount++;
            }
        });

        const status = totalScore >= exam.passingMarks ? 'PASSED' : 'FAILED';

        const attempt = await prisma.attempt.create({
            data: {
                userId,
                examId,
                score: totalScore,
                status
            }
        });

        res.json({
            message: "Exam submitted successfully!",
            score: totalScore,
            correctAnswers: correctAnswersCount,
            totalQuestions: questions.length,
            status: status,
            attemptId: attempt.id
        });
    } catch (error) {
        res.status(500).json({ error: "Failed to grade exam." });
    }
});

// 6. GET STUDENT ATTEMPT HISTORY (Protected)
router.get('/history/my-results', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.userId;

        const attempts = await prisma.attempt.findMany({
            where: { userId: parseInt(userId) },
            include: {
                exam: { select: { title: true } }
            },
            orderBy: { id: 'desc' }
        });

        res.json(attempts);
    } catch (error) {
        res.status(500).json({ error: "Failed to fetch results history." });
    }
});

// 7. DELETE AN EXAM (Protected: Teacher/Admin Only)
router.delete('/:id', authenticateToken, async (req, res) => {
    try {
        if (req.user.role !== 'TEACHER' && req.user.role !== 'ADMIN') {
            return res.status(403).json({ error: "Only teachers can delete exams." });
        }

        const examId = parseInt(req.params.id);
        
        // Delete all child questions first to prevent foreign key constraint errors
        await prisma.question.deleteMany({ where: { examId: examId } });
        
        // Delete the exam
        await prisma.exam.delete({ where: { id: examId } });

        res.json({ message: "Exam and all associated questions deleted successfully." });
    } catch (error) {
        res.status(500).json({ error: "Failed to delete exam." });
    }
});

// 8. DELETE A SPECIFIC QUESTION (Protected: Teacher/Admin Only)
router.delete('/questions/:id', authenticateToken, async (req, res) => {
    try {
        if (req.user.role !== 'TEACHER' && req.user.role !== 'ADMIN') {
            return res.status(403).json({ error: "Only teachers can delete questions." });
        }

        await prisma.question.delete({ where: { id: parseInt(req.params.id) } });
        res.json({ message: "Question deleted successfully." });
    } catch (error) {
        res.status(500).json({ error: "Failed to delete question." });
    }
});

module.exports = router;