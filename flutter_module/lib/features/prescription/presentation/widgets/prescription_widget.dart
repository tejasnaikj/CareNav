import 'package:flutter/material.dart';
import '../../../../core/services/firebase_service.dart';

class PrescriptionWidget extends StatefulWidget {
  final String doctorId;
  final String patientId;
  final String patientName;
  final String sessionId;

  const PrescriptionWidget({
    super.key,
    required this.doctorId,
    required this.patientId,
    required this.patientName,
    required this.sessionId,
  });

  @override
  State<PrescriptionWidget> createState() => _PrescriptionWidgetState();
}

class _PrescriptionWidgetState extends State<PrescriptionWidget> {
  final FirebaseService _firebase = FirebaseService.instance;
  final _medicationController = TextEditingController();
  final _dosageController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _daysController = TextEditingController();

  @override
  void dispose() {
    _medicationController.dispose();
    _dosageController.dispose();
    _instructionsController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  Future<void> _addPrescription() async {
    if (_medicationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter medication name')),
      );
      return;
    }

    if (_daysController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter number of days')),
      );
      return;
    }

    try {
      final days = int.parse(_daysController.text.trim());
      final expiryDate = DateTime.now().add(Duration(days: days));

      await _firebase.savePrescription({
        'doctorId': widget.doctorId,
        'patientId': widget.patientId,
        'patientName': widget.patientName,
        'sessionId': widget.sessionId,
        'medication': _medicationController.text.trim(),
        'dosage': _dosageController.text.trim(),
        'instructions': _instructionsController.text.trim(),
        'days': days,
        'expiryDate': expiryDate.toIso8601String(),
        'status': 'active',
      });

      _medicationController.clear();
      _dosageController.clear();
      _instructionsController.clear();
      _daysController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prescription added successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade700,
          child: Row(
            children: [
              const Icon(Icons.medication, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Prescription', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('Patient: ${widget.patientName}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _medicationController,
                decoration: const InputDecoration(
                  labelText: 'Medication Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.medical_services),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _dosageController,
                decoration: const InputDecoration(
                  labelText: 'Dosage (e.g., 500mg, 2 tablets)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.monitor_weight),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _daysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Number of Days *',
                  hintText: 'e.g., 7, 14, 30',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _instructionsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Instructions',
                  hintText: 'e.g., Take after meals, twice daily',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _addPrescription,
                icon: const Icon(Icons.add),
                label: const Text('Add Prescription'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ],
          ),
        ),

        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Active Prescriptions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        
        Expanded(
          child: StreamBuilder(
            stream: _firebase.firestore
                .collection('prescriptions')
                .where('sessionId', isEqualTo: widget.sessionId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No prescriptions yet'));
              }

              final docs = snapshot.data!.docs;
              final now = DateTime.now();

              // Auto-update expired prescriptions
              for (var doc in docs) {
                final data = doc.data();
                if (data['status'] == 'active' && data['expiryDate'] != null) {
                  final expiry = DateTime.parse(data['expiryDate']);
                  if (now.isAfter(expiry)) {
                    _firebase.firestore.collection('prescriptions').doc(doc.id).update({'status': 'inactive'});
                  }
                }
              }

              final activePrescriptions = docs.where((doc) {
                final data = doc.data();
                if (data['status'] != 'active') return false;
                if (data['expiryDate'] == null) return true;
                return DateTime.now().isBefore(DateTime.parse(data['expiryDate']));
              }).toList();

              if (activePrescriptions.isEmpty) {
                return const Center(child: Text('No active prescriptions'));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: activePrescriptions.length,
                itemBuilder: (context, index) {
                  final doc = activePrescriptions[index];
                  final rx = doc.data();
                  final rxId = doc.id;
                  final expiryDate = rx['expiryDate'] != null ? DateTime.parse(rx['expiryDate']) : null;
                  final daysLeft = expiryDate != null ? expiryDate.difference(DateTime.now()).inDays : null;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.medication)),
                      title: Text(rx['medication'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dosage: ${rx['dosage'] ?? 'N/A'}'),
                          if (daysLeft != null)
                            Text(
                              daysLeft > 0 ? '$daysLeft days left' : 'Expired',
                              style: TextStyle(
                                color: daysLeft > 0 ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await _firebase.firestore.collection('prescriptions').doc(rxId).update({'status': 'inactive'});
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
