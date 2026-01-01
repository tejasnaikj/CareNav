import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../triage/presentation/screens/triage_screen.dart';
import '../../../session/presentation/screens/patient_session_screen.dart';
import '../../../prescription/presentation/screens/patient_prescription_screen.dart';
import '../../../session/presentation/screens/session_detail_screen.dart';

class PatientDashboard extends ConsumerStatefulWidget {
  final User patient;
  const PatientDashboard({super.key, required this.patient});

  @override
  ConsumerState<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends ConsumerState<PatientDashboard> {
  final FirebaseService _firebase = FirebaseService.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Dashboard'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.green.shade600, Colors.green.shade400]),
          ),
        ),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green.shade50, Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- WELCOME CARD ---
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.green.shade600, Colors.green.shade400]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, size: 40, color: Colors.green.shade600),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Welcome,', style: TextStyle(color: Colors.white70, fontSize: 14)),
                          Text(widget.patient.fullName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const Icon(Icons.verified, color: Colors.white, size: 32),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),

              // --- ACTIVE SESSION CARD ---
              StreamBuilder<QuerySnapshot>(
                stream: _firebase.firestore
                    .collection('sessions')
                    .where('patientId', isEqualTo: widget.patient.id)
                    .where('status', isEqualTo: 'active')
                    .limit(1)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    final session = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                    final sessionId = snapshot.data!.docs.first.id;

                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.blue.shade400, Colors.blue.shade600]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
                      ),
                      child: Column(
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.videocam, color: Colors.white, size: 32),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Active Consultation', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                    Text('In progress', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              print('🔵 Patient: Returning to session $sessionId');
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PatientSessionScreen(
                                    sessionId: sessionId,
                                    patientName: widget.patient.fullName,
                                    doctorName: session['doctorName']?.toString() ?? 'Doctor',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Return to Consultation'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.blue,
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    );
                  } else {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.videocam_off, color: Colors.grey.shade400, size: 32),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('No Active Consultation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                Text('Start a consultation from Triage', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
              
              const SizedBox(height: 32),
              
              // --- QUICK ACTIONS GRID ---
              const Text('Quick Actions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.9, // <--- FIX 1: Make cards slightly taller
                children: [
                  _buildActionCard('Start Triage', 'Begin consultation', Icons.add_circle, Colors.green, () {
                    print('🔵 Patient: Start Triage clicked');
                    Navigator.push(context, MaterialPageRoute(builder: (context) => TriageScreen(patient: widget.patient)));
                  }),
                  _buildActionCard('History', 'Past consultations', Icons.history, Colors.orange, () {
                    print('🔵 Patient: History clicked');
                    _viewHistory();
                  }),
                  _buildActionCard('Prescriptions', 'View medicines', Icons.medication, Colors.blue, () {
                    print('🔵 Patient: Prescriptions clicked');
                    Navigator.push(context, MaterialPageRoute(builder: (context) => PatientPrescriptionScreen(patientId: widget.patient.id)));
                  }),
                  _buildActionCard('Help', 'Get assistance', Icons.help, Colors.purple, () {
                    print('🔵 Patient: Help clicked');
                    _showHelpDialog();
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- THE FIXED CARD WIDGET ---
  Widget _buildActionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        print('🟢 Card tapped: $title');
        onTap();
      },
      child: Container(
        // FIX 2: Reduced padding from 20 to 12 to save space
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12), // Reduced from 16
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 28), // Slightly smaller icon
            ),
            const SizedBox(height: 10),
            
            // FIX 3: FittedBox shrinks text if it overflows
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title, 
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)
              ),
            ),
            
            const SizedBox(height: 4),
            
            // FIX 3: FittedBox for subtitle too
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                subtitle, 
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600), 
                textAlign: TextAlign.center
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _viewHistory() async {
    try {
      print('📋 Loading patient history...');
      
      final sessionsSnapshot = await _firebase.firestore
          .collection('sessions')
          .where('patientId', isEqualTo: widget.patient.id)
          .get();

      print('📋 Found ${sessionsSnapshot.docs.length} total sessions');

      final completedSessions = sessionsSnapshot.docs.where((doc) {
        final data = doc.data();
        return data['status'] == 'completed';
      }).toList();

      print('📋 Found ${completedSessions.length} completed sessions');

      completedSessions.sort((a, b) {
        final aTime = a.data()['startTime'] ?? '';
        final bTime = b.data()['startTime'] ?? '';
        return bTime.toString().compareTo(aTime.toString());
      });

      if (!mounted) return;

      if (completedSessions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No past consultations found'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Text(
                    'Past Consultations',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: completedSessions.length,
                      itemBuilder: (context, index) {
                        final sessionDoc = completedSessions[index];
                        final session = sessionDoc.data();
                        final sessionId = sessionDoc.id;
                        final startTime = session['startTime'] != null 
                            ? DateTime.parse(session['startTime']) 
                            : DateTime.now();
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.orange.shade100,
                              child: Icon(Icons.medical_services, color: Colors.orange.shade700),
                            ),
                            title: Text('Dr. ${session['doctorName'] ?? 'Unknown'}'),
                            subtitle: Text(DateFormat('MMM dd, yyyy hh:mm a').format(startTime)),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              print('🔵 Opening session: $sessionId');
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SessionDetailScreen(
                                    sessionId: sessionId,
                                    patientName: widget.patient.fullName,
                                    doctorName: session['doctorName'] ?? 'Doctor',
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    } catch (e) {
      print('❌ Error loading history: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading history: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📞 Emergency: 911'),
            SizedBox(height: 8),
            Text('🏥 Hospital: (555) 123-4567'),
            SizedBox(height: 8),
            Text('💬 Support: support@hospital.com'),
            SizedBox(height: 16),
            Text(
              'For technical assistance, please contact the hospital reception.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}