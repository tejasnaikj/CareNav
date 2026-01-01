import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/firebase_service.dart';
import 'session_detail_screen.dart';

class PatientSessionsScreen extends StatefulWidget {
  final String doctorId;
  final String patientId;
  final String patientName;

  const PatientSessionsScreen({
    super.key,
    required this.doctorId,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<PatientSessionsScreen> createState() => _PatientSessionsScreenState();
}

class _PatientSessionsScreenState extends State<PatientSessionsScreen> {
  final FirebaseService _firebase = FirebaseService.instance;
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _loading = true);

    try {
      final sessions = await _firebase.getPatientSessions(widget.doctorId, widget.patientId);
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } catch (e) {
      print('Error loading sessions: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sessions: ${widget.patientName}'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue.shade500],
            ),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No past sessions', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sessions.length,
                  itemBuilder: (context, index) {
                    final session = _sessions[index];
                    final startTime = DateTime.parse(session['startTime']);
                    final endTime = session['endTime'] != null ? DateTime.parse(session['endTime']) : null;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          DateFormat('MMM dd, yyyy').format(startTime),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Time: ${DateFormat('hh:mm a').format(startTime)}'),
                            if (endTime != null)
                              Text('Duration: ${endTime.difference(startTime).inMinutes} min'),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SessionDetailScreen(
                                sessionId: session['id'],
                                patientName: widget.patientName,
                                doctorName: session['doctorName'] ?? 'Doctor',
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
