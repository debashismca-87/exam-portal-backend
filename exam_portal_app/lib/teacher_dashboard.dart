import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  List<dynamic> _existingExams = [];
  bool _isLoading = true;
  
  // View states: 'list' (show all exams), 'createExam' (form), 'addQuestions' (form)
  String _currentView = 'list'; 
  int? _activeExamId;
  String _activeExamTitle = '';
  List<dynamic> _addedQuestions = [];

  // Controllers
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _durationController = TextEditingController();
  final _passingMarksController = TextEditingController();
  final _qTextController = TextEditingController();
  final _optAController = TextEditingController();
  final _optBController = TextEditingController();
  final _optCController = TextEditingController();
  final _optDController = TextEditingController();
  String _correctOption = 'A';

  @override
  void initState() {
    super.initState();
    _fetchAllExams();
  }

  // --- 1. FETCH EXAMS ---
  Future<void> _fetchAllExams() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final url = Uri.parse('http://127.0.0.1:5000/api/exams');
      final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});

      if (response.statusCode == 200) {
        setState(() => _existingExams = json.decode(response.body));
      }
    } catch (e) {
      _showSnack('Error fetching exams: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- 2. DELETE EXAM ---
  Future<void> _deleteExam(int examId) async {
    // Show confirmation dialog first
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Exam?'),
        content: const Text('This will permanently delete the exam and all its questions.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('DELETE', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final url = Uri.parse('http://127.0.0.1:5000/api/exams/$examId');
      final response = await http.delete(url, headers: {'Authorization': 'Bearer $token'});

      if (response.statusCode == 200) {
        _showSnack('Exam deleted successfully', Colors.green);
        _fetchAllExams(); // Refresh the list
      } else {
        _showSnack('Failed to delete exam', Colors.red);
      }
    } catch (e) {
      _showSnack('Error: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- 3. DELETE QUESTION ---
  Future<void> _deleteQuestion(int questionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final url = Uri.parse('http://127.0.0.1:5000/api/exams/questions/$questionId');
      await http.delete(url, headers: {'Authorization': 'Bearer $token'});
      
      _showSnack('Question removed', Colors.orange);
      _fetchAddedQuestions(); // Refresh question list
    } catch (e) {
      _showSnack('Error deleting question', Colors.red);
    }
  }

  // --- CREATE EXAM & QUESTION LOGIC (From previous version) ---
  Future<void> _createExam() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final response = await http.post(
        Uri.parse('http://127.0.0.1:5000/api/exams/create'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: json.encode({
          'title': _titleController.text,
          'description': _descController.text,
          'durationMins': int.tryParse(_durationController.text) ?? 30,
          'passingMarks': int.tryParse(_passingMarksController.text) ?? 50,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        setState(() {
          _activeExamId = data['exam']['id'];
          _activeExamTitle = data['exam']['title'];
          _currentView = 'addQuestions';
          _addedQuestions = [];
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAddedQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final response = await http.get(
      Uri.parse('http://127.0.0.1:5000/api/exams/$_activeExamId/questions'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      setState(() => _addedQuestions = json.decode(response.body));
    }
  }

  Future<void> _addQuestion() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final optionsArray = [
        {"id": "A", "text": _optAController.text}, {"id": "B", "text": _optBController.text},
        {"id": "C", "text": _optCController.text}, {"id": "D", "text": _optDController.text},
      ];

      final response = await http.post(
        Uri.parse('http://127.0.0.1:5000/api/exams/$_activeExamId/questions'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: json.encode({'questionText': _qTextController.text, 'options': optionsArray, 'correctOptionId': _correctOption, 'marks': 1}),
      );

      if (response.statusCode == 201) {
        _qTextController.clear(); _optAController.clear(); _optBController.clear(); _optCController.clear(); _optDController.clear();
        await _fetchAddedQuestions();
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  // --- UI BUILDERS ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentView == 'list' ? 'Manage Exams' : _activeExamId == null ? 'Create New Exam' : 'Editing: $_activeExamTitle'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        leading: _currentView != 'list' 
            ? IconButton(
                icon: const Icon(Icons.arrow_back), 
                onPressed: () {
                  setState(() => _currentView = 'list');
                  _fetchAllExams();
                }) 
            : null,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : _currentView == 'list' 
              ? _buildExamList() 
              : _currentView == 'createExam' 
                  ? _buildExamMaker() 
                  : _buildQuestionMaker(),
      floatingActionButton: _currentView == 'list' ? FloatingActionButton.extended(
        onPressed: () => setState(() {
          _titleController.clear(); _descController.clear(); _durationController.clear(); _passingMarksController.clear();
          _currentView = 'createExam';
          _activeExamId = null;
        }),
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Exam', style: TextStyle(color: Colors.white)),
      ) : null,
    );
  }

  Widget _buildExamList() {
    if (_existingExams.isEmpty) return const Center(child: Text('No exams found. Create one!'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _existingExams.length,
      itemBuilder: (context, index) {
        final exam = _existingExams[index];
        return Card(
          child: ListTile(
            title: Text(exam['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${exam['_count']['questions']} Questions'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () {
                    setState(() {
                      _activeExamId = exam['id'];
                      _activeExamTitle = exam['title'];
                      _currentView = 'addQuestions';
                    });
                    _fetchAddedQuestions();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteExam(exam['id']),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExamMaker() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Exam Title', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _descController, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextField(controller: _durationController, decoration: const InputDecoration(labelText: 'Duration', border: OutlineInputBorder()))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _passingMarksController, decoration: const InputDecoration(labelText: 'Passing Marks', border: OutlineInputBorder()))),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _createExam, style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white), child: const Text('SAVE & PROCEED'))
        ],
      ),
    );
  }

  Widget _buildQuestionMaker() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_addedQuestions.isNotEmpty) ...[
            const Text('Existing Questions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ..._addedQuestions.map((q) => Card(
              child: ListTile(
                title: Text(q['questionText']),
                trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteQuestion(q['id'])),
              ),
            )),
            const Divider(height: 32),
          ],
          const Text('Add New Question', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(controller: _qTextController, decoration: const InputDecoration(labelText: 'Question Text', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _optAController, decoration: const InputDecoration(labelText: 'Option A')),
          TextField(controller: _optBController, decoration: const InputDecoration(labelText: 'Option B')),
          TextField(controller: _optCController, decoration: const InputDecoration(labelText: 'Option C')),
          TextField(controller: _optDController, decoration: const InputDecoration(labelText: 'Option D')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _correctOption,
            decoration: const InputDecoration(labelText: 'Correct Option', border: OutlineInputBorder()),
            items: ['A', 'B', 'C', 'D'].map((String val) => DropdownMenuItem(value: val, child: Text('Option $val'))).toList(),
            onChanged: (newValue) => setState(() => _correctOption = newValue!),
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _addQuestion, style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white), child: const Text('ADD QUESTION'))
        ],
      ),
    );
  }
}