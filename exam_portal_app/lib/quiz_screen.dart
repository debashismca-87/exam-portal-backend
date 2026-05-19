import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class QuizScreen extends StatefulWidget {
  final int examId;
  final String examTitle;

  const QuizScreen({super.key, required this.examId, required this.examTitle});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<dynamic> _questions = [];
  bool _isLoading = true;
  String _errorMessage = '';
  
  // Stores the user's selected answers. Map of Question ID (as String) -> Option ID (A, B, C, D)
  final Map<String, String> _selectedAnswers = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final url = Uri.parse('http://127.0.0.1:5000/api/exams/${widget.examId}/questions');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _questions = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load questions.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Server connection error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitExam() async {
    // Basic validation: Check if they answered everything
    if (_selectedAnswers.length < _questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer all questions before submitting.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final url = Uri.parse('http://127.0.0.1:5000/api/exams/${widget.examId}/submit');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'answers': _selectedAnswers,
        }),
      );

      if (response.statusCode == 200) {
        final resultData = json.decode(response.body);
        _showResultsDialog(resultData);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit exam.'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showResultsDialog(Map<String, dynamic> results) {
    showDialog(
      context: context,
      barrierDismissible: false, // Force them to click OK
      builder: (context) {
        final passed = results['status'] == 'PASSED';
        return AlertDialog(
          title: Text(passed ? 'Congratulations!' : 'Exam Finished'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                passed ? Icons.emoji_events : Icons.assignment_turned_in,
                color: passed ? Colors.amber : Colors.blue,
                size: 60,
              ),
              const SizedBox(height: 16),
              Text('Your Score: ${results['score']}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Correct Answers: ${results['correctAnswers']} / ${results['totalQuestions']}'),
              const SizedBox(height: 8),
              Text('Status: ${results['status']}', style: TextStyle(fontWeight: FontWeight.bold, color: passed ? Colors.green : Colors.red)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close Dialog
                Navigator.pop(context); // Go back to Dashboard
              },
              child: const Text('Return to Dashboard'),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.examTitle),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
              : _questions.isEmpty
                  ? const Center(child: Text('No questions available for this exam.', style: TextStyle(fontSize: 18)))
                  : ListView.builder(
                      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80), // Bottom padding for FAB
                      itemCount: _questions.length,
                      itemBuilder: (context, index) {
                        final question = _questions[index];
                        final questionId = question['id'].toString();
                        
                        // THE FIX: Filter out options that have empty text
                        final validOptions = (question['options'] as List)
                            .where((opt) => opt['text'].toString().trim().isNotEmpty)
                            .toList();

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Q${index + 1}: ${question['questionText']}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                ...validOptions.map((option) {
                                  return RadioListTile<String>(
                                    title: Text(option['text']),
                                    value: option['id'],
                                    groupValue: _selectedAnswers[questionId],
                                    activeColor: Colors.indigo,
                                    contentPadding: EdgeInsets.zero, // Aligns it neatly with the text
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedAnswers[questionId] = value!;
                                      });
                                    },
                                  );
                                }),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
      // A floating button that is always visible at the bottom for easy submission
      floatingActionButton: _questions.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _isSubmitting ? null : _submitExam,
              backgroundColor: Colors.indigo,
              icon: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.send, color: Colors.white),
              label: Text(_isSubmitting ? 'Grading...' : 'Submit Exam', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}