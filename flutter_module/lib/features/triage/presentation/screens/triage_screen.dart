import 'package:flutter/material.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../../core/services/firebase_service.dart';

class TriageScreen extends StatefulWidget {
  final User patient;
  const TriageScreen({super.key, required this.patient});

  @override
  State<TriageScreen> createState() => _TriageScreenState();
}

class _TriageScreenState extends State<TriageScreen> {
  final FirebaseService _firebase = FirebaseService.instance;
  final _symptomsController = TextEditingController();
  String? _selectedDoctor;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _doctors = [];
  int _currentQuestionIndex = 0;
  final Map<String, bool> _answers = {};
  
  final List<Map<String, dynamic>> _triageQuestions = [
    {'question': 'Are you experiencing severe chest pain?', 'weight': 10},
    {'question': 'Do you have difficulty breathing?', 'weight': 10},
    {'question': 'Are you bleeding heavily?', 'weight': 10},
    {'question': 'Have you lost consciousness recently?', 'weight': 9},
    {'question': 'Do you have severe abdominal pain?', 'weight': 8},
    {'question': 'Are you experiencing severe headache with vision changes?', 'weight': 8},
    {'question': 'Do you have a high fever (above 103°F)?', 'weight': 6},
    {'question': 'Have symptoms started suddenly?', 'weight': 5},
    {'question': 'Are you in moderate pain?', 'weight': 4},
    {'question': 'Have you had these symptoms for more than 3 days?', 'weight': 3},
  ];

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  @override
  void dispose() {
    _symptomsController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    final doctors = await _firebase.getAllDoctors();
    setState(() => _doctors = doctors);
    if (_doctors.isNotEmpty) {
      _selectedDoctor = _doctors.first['id'];
    }
  }

  int _calculatePriority() {
    int totalScore = 0;
    _answers.forEach((question, answer) {
      if (answer) {
        final questionData = _triageQuestions.firstWhere(
          (q) => q['question'] == question,
          orElse: () => {'weight': 0},
        );
        totalScore += (questionData['weight'] as int);
      }
    });
    if (totalScore >= 15) return 1;
    if (totalScore >= 8) return 2;
    return 3;
  }

  String _getPriorityLabel(int priority) {
    switch (priority) {
      case 1: return 'High Priority';
      case 2: return 'Medium Priority';
      default: return 'Low Priority';
    }
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 1: return Colors.red;
      case 2: return Colors.orange;
      default: return Colors.green;
    }
  }

  Future<void> _submitTriage() async {
    if (_symptomsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe your symptoms')),
      );
      return;
    }

    if (_selectedDoctor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a doctor')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final calculatedPriority = _calculatePriority();
      
      // FIXED: Ensure all fields are strings
      final queueData = {
        'patientId': widget.patient.id.toString(),
        'patientName': widget.patient.fullName.toString(),
        'patientPhone': (widget.patient.phone ?? 'N/A').toString(),
        'doctorId': _selectedDoctor.toString(),
        'priority': calculatedPriority,
        'status': 'waiting',
        'checkinTime': DateTime.now().toIso8601String(),
        'symptoms': _symptomsController.text.trim(),
        'triageAnswers': _answers.toString(),
        'priorityScore': calculatedPriority,
      };

      print('📝 Submitting queue data: $queueData');
      await _firebase.addToQueue(queueData);
      print('✅ Successfully added to queue!');

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Added to queue as ${_getPriorityLabel(calculatedPriority)}'),
            backgroundColor: _getPriorityColor(calculatedPriority),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to join queue'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Triage'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.green.shade600, Colors.green.shade400]),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green.shade50, Colors.white],
          ),
        ),
        child: _currentQuestionIndex < _triageQuestions.length ? _buildQuestionScreen() : _buildSummaryScreen(),
      ),
    );
  }

  Widget _buildQuestionScreen() {
    final question = _triageQuestions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / _triageQuestions.length;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Question ${_currentQuestionIndex + 1} of ${_triageQuestions.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${(progress * 100).toInt()}%', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(Colors.green.shade600),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.help_outline, size: 64, color: Colors.green.shade600),
                      const SizedBox(height: 24),
                      Text(question['question'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.4), textAlign: TextAlign.center),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  children: [
                    Expanded(child: _buildAnswerButton(label: 'NO', color: Colors.red, icon: Icons.close, onTap: () => _answerQuestion(false))),
                    const SizedBox(width: 16),
                    Expanded(child: _buildAnswerButton(label: 'YES', color: Colors.green, icon: Icons.check, onTap: () => _answerQuestion(true))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnswerButton({required String label, required Color color, required IconData icon, required VoidCallback onTap}) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        shadowColor: color.withOpacity(0.5),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ],
      ),
    );
  }

  void _answerQuestion(bool answer) {
    setState(() {
      _answers[_triageQuestions[_currentQuestionIndex]['question']] = answer;
      _currentQuestionIndex++;
    });
  }

  Widget _buildSummaryScreen() {
    final priority = _calculatePriority();
    final priorityColor = _getPriorityColor(priority);
    final priorityLabel = _getPriorityLabel(priority);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [priorityColor, priorityColor.withOpacity(0.7)]),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: priorityColor.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Column(
              children: [
                Icon(priority == 1 ? Icons.error : priority == 2 ? Icons.warning : Icons.check_circle, size: 80, color: Colors.white),
                const SizedBox(height: 16),
                const Text('Your Priority Level', style: TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 8),
                Text(priorityLabel, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text('Describe Your Symptoms', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _symptomsController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Describe your symptoms...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          const Text('Select Doctor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedDoctor,
                items: _doctors.map<DropdownMenuItem<String>>((doctor) {
                  return DropdownMenuItem<String>(
                    value: doctor['id'],
                    child: Text('Dr. ${doctor['fullName']}'),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedDoctor = value),
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submitTriage,
            icon: _isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_circle, size: 24),
            label: Text(_isSubmitting ? 'Joining Queue...' : 'Join Queue', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }
}
