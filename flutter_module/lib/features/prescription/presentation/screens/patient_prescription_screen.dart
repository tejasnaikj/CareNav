import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/firebase_service.dart';

class PatientPrescriptionScreen extends StatefulWidget {
  final String patientId;

  const PatientPrescriptionScreen({
    super.key,
    required this.patientId,
  });

  @override
  State<PatientPrescriptionScreen> createState() => _PatientPrescriptionScreenState();
}

class _PatientPrescriptionScreenState extends State<PatientPrescriptionScreen> with SingleTickerProviderStateMixin {
  final FirebaseService _firebase = FirebaseService.instance;
  late TabController _tabController;
  List<Map<String, dynamic>> _activePrescriptions = [];
  List<Map<String, dynamic>> _historyPrescriptions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPrescriptions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPrescriptions() async {
    setState(() => _loading = true);

    try {
      print('📋 Loading prescriptions for patient: ${widget.patientId}');
      
      final allPrescriptions = await _firebase.getPatientPrescriptions(widget.patientId);
      
      print('📋 Found ${allPrescriptions.length} total prescriptions');

      final now = DateTime.now();
      final active = <Map<String, dynamic>>[];
      final history = <Map<String, dynamic>>[];

      for (var rx in allPrescriptions) {
        print('📋 Prescription: ${rx['medication']} - Status: ${rx['status']}');
        
        // Auto-update expired prescriptions
        if (rx['status'] == 'active' && rx['expiryDate'] != null) {
          final expiry = DateTime.parse(rx['expiryDate']);
          if (now.isAfter(expiry)) {
            print('📋 Prescription expired, moving to history');
            await _firebase.firestore.collection('prescriptions').doc(rx['id']).update({'status': 'inactive'});
            rx['status'] = 'inactive';
          }
        }

        if (rx['status'] == 'active') {
          active.add(rx);
        } else {
          history.add(rx);
        }
      }

      print('📋 Active: ${active.length}, History: ${history.length}');

      setState(() {
        _activePrescriptions = active;
        _historyPrescriptions = history;
        _loading = false;
      });
    } catch (e) {
      print('❌ Error loading prescriptions: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Prescriptions'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade700, Colors.green.shade500],
            ),
          ),
        ),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'Active (${_activePrescriptions.length})', icon: const Icon(Icons.medication)),
            Tab(text: 'History (${_historyPrescriptions.length})', icon: const Icon(Icons.history)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPrescriptionList(_activePrescriptions, isActive: true),
                _buildPrescriptionList(_historyPrescriptions, isActive: false),
              ],
            ),
    );
  }

  Widget _buildPrescriptionList(List<Map<String, dynamic>> prescriptions, {required bool isActive}) {
    if (prescriptions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medication_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              isActive ? 'No active prescriptions' : 'No prescription history',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: prescriptions.length,
      itemBuilder: (context, index) {
        final rx = prescriptions[index];
        final date = DateTime.parse(rx['createdAt']);
        final expiryDate = rx['expiryDate'] != null ? DateTime.parse(rx['expiryDate']) : null;
        final daysLeft = expiryDate != null ? expiryDate.difference(DateTime.now()).inDays : null;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: isActive ? Colors.green.shade100 : Colors.grey.shade200,
              child: Icon(
                Icons.medication,
                color: isActive ? Colors.green.shade700 : Colors.grey.shade600,
              ),
            ),
            title: Text(
              rx['medication'] ?? 'N/A',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Dr. ${rx['doctorName'] ?? 'Unknown'}'),
                Text(
                  DateFormat('MMM dd, yyyy').format(date),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                if (daysLeft != null && isActive) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: daysLeft > 0 ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      daysLeft > 0 ? '$daysLeft days remaining' : 'Expired',
                      style: TextStyle(
                        color: daysLeft > 0 ? Colors.green.shade700 : Colors.red.shade700,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Dosage', rx['dosage'] ?? 'N/A'),
                    const SizedBox(height: 8),
                    _buildDetailRow('Duration', '${rx['days'] ?? 'N/A'} days'),
                    const SizedBox(height: 8),
                    _buildDetailRow('Instructions', rx['instructions'] ?? 'Take as directed'),
                    if (expiryDate != null) ...[
                      const SizedBox(height: 8),
                      _buildDetailRow('Expires On', DateFormat('MMM dd, yyyy').format(expiryDate)),
                    ],
                    const SizedBox(height: 8),
                    _buildDetailRow('Prescribed', DateFormat('MMM dd, yyyy hh:mm a').format(date)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}
