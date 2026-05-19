import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'quiz_screen.dart';
import 'teacher_dashboard.dart';
import 'results_screen.dart';
import 'main.dart'; 

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _exams = [];
  bool _isLoading = true;
  String _errorMessage = '';
  
  // Track the user's role to show/hide specific buttons
  String _userRole = ''; 

  @override
  void initState() {
    super.initState();
    _fetchExams();
  }

  Future<void> _fetchExams() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) {
        setState(() => _errorMessage = 'No auth token found. Please log in again.');
        return;
      }

      // Decode the JWT Token to find out if they are a Teacher or Student
      try {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payloadString = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
          final payloadMap = json.decode(payloadString);
          setState(() {
            _userRole = payloadMap['role'] ?? 'STUDENT'; 
          });
        }
      } catch (e) {
        print('Error decoding token: $e');
      }

      // Ask the backend for the available exams
      final url = Uri.parse('http://127.0.0.1:5000/api/exams');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _exams = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load exams. Server responded with: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not connect to server: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Exams'),
        actions: [
          // Only show the History icon if the user is a Student
          if (_userRole != 'TEACHER' && _userRole != 'ADMIN')
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'My Results',
              onPressed: () async {
                // Wait for the user to return from the Results screen...
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ResultsScreen()),
                );
                // ...then fetch fresh data!
                _fetchExams();
              },
            ),
            
          // Logout Button (Shows for everyone)
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              // Clear token
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('jwt_token');
              
              if (context.mounted) {
                // Force the app back to the Login Screen properly
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
              : _exams.isEmpty
                  ? const Center(child: Text('No exams available right now.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _exams.length,
                      itemBuilder: (context, index) {
                        final exam = _exams[index];
                        final questionCount = exam['_count']['questions'];

                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(
                              exam['title'],
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                Text(exam['description'] ?? 'No description available.'),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.timer, size: 16, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text('${exam['durationMins']} mins'),
                                    const SizedBox(width: 16),
                                    const Icon(Icons.format_list_numbered, size: 16, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text('$questionCount Questions'),
                                  ],
                                ),
                              ],
                            ),
                            trailing: ElevatedButton(
                              onPressed: () async {
                                // Wait for the student to finish taking the quiz...
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => QuizScreen(
                                      examId: exam['id'],
                                      examTitle: exam['title'],
                                    ),
                                  ),
                                );
                                // ...then refresh the dashboard!
                                _fetchExams();
                              },
                              child: const Text('TAKE'),
                            ),
                          ),
                        );
                      },
                    ),
                    
      // Conditionally show the Teacher Admin button ONLY if role is TEACHER or ADMIN
      floatingActionButton: (_userRole == 'TEACHER' || _userRole == 'ADMIN') 
        ? FloatingActionButton.extended(
            onPressed: () async {
              // Wait for the teacher to finish adding/deleting exams...
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TeacherDashboard()),
              );
              // ...then refresh the dashboard!
              _fetchExams();
            },
            backgroundColor: Colors.teal,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Teacher Admin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        : null, 
    );
  }
}