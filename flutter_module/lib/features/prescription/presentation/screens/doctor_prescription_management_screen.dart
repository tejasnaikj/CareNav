import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/firebase_service.dart';

class DoctorPrescriptionManagementScreen extends StatefulWidget {
  final String doctorId;
  final String patientId;
  final String patientName;

  const DoctorPrescriptionManagementScreen({
    super.key,
    required this.doctorId,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<DoctorPrescriptionManagementScreen> createState() => _DoctorPrescriptionManagementScreenState();
}

class _DoctorPrescriptionManagementScreenState extends State<DoctorPrescriptionManagementScreen> with SingleTickerProviderStateMixin {
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
      final allPrescriptions = await _firebase.getPatientPrescriptions(widget.patientId);
      
      final now = DateTime.now();
      final active = <Map<String, dynamic>>[];
      final history = <Map<String, dynamic>>[];

      for (var rx in allPrescriptions) {
        // Auto-update expired prescriptions
        if (rx['status'] == 'active' && rx['expiryDate'] != null) {
          final expiry = DateTime.parse(rx['expiryDate']);
          if (now.isAfter(expiry)) {
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

      setState(() {
        _activePrescriptions = active;
        _historyPrescriptions = history;
        _loading = false;
      });
    } catch (e) {
      print('Error loading prescriptions: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Prescriptions: ${widget.patientName}'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.blue.shade700, Colors.blue.shade500]),
          ),
        ),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Active', icon: Icon(Icons.medication)),
            Tab(text: 'History', icon: Icon(Icons.history)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddPrescriptionDialog(),
          ),
        ],
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
            Icon(Icons.medication_outlined, size: 80, color: Colors.grey.shade300),
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
            title: Text(rx['medication'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Prescribed: ${DateFormat('MMM dd, yyyy').format(date)}'),
                if (daysLeft != null && isActive)
                  Text(
                    daysLeft > 0 ? '$daysLeft days remaining' : 'Expired',
                    style: TextStyle(
                      color: daysLeft > 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            trailing: isActive
                ? PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(value: 'deactivate', child: Text('Deactivate')),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editPrescription(rx);
                      } else if (value == 'deactivate') {
                        _deactivatePrescription(rx['id']);
                      }
                    },
                  )
                : null,
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
                    _buildDetailRow('Instructions', rx['instructions'] ?? 'N/A'),
                    if (expiryDate != null) ...[
                      const SizedBox(height: 8),
                      _buildDetailRow('Expires', DateFormat('MMM dd, yyyy').format(expiryDate)),
                    ],
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
          width: 100,
          child: Text(
            '$label:',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }

  Future<void> _showAddPrescriptionDialog() async {
    final medicationController = TextEditingController();
    final dosageController = TextEditingController();
    final instructionsController = TextEditingController();
    final daysController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Prescription'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: medicationController,
                decoration: const InputDecoration(labelText: 'Medication Name *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dosageController,
                decoration: const InputDecoration(labelText: 'Dosage'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: daysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Number of Days *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: instructionsController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Instructions'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (medicationController.text.trim().isEmpty || daysController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill required fields')),
                );
                return;
              }

              try {
                final days = int.parse(daysController.text.trim());
                final expiryDate = DateTime.now().add(Duration(days: days));

                await _firebase.savePrescription({
                  'doctorId': widget.doctorId,
                  'doctorName': 'Dr. Name', // TODO: Get from context
                  'patientId': widget.patientId,
                  'patientName': widget.patientName,
                  'medication': medicationController.text.trim(),
                  'dosage': dosageController.text.trim(),
                  'instructions': instructionsController.text.trim(),
                  'days': days,
                  'expiryDate': expiryDate.toIso8601String(),
                  'status': 'active',
                });

                Navigator.pop(context);
                _loadPrescriptions();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Prescription added'), backgroundColor: Colors.green),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _editPrescription(Map<String, dynamic> rx) async {
    final medicationController = TextEditingController(text: rx['medication']);
    final dosageController = TextEditingController(text: rx['dosage']);
    final instructionsController = TextEditingController(text: rx['instructions']);
    final daysController = TextEditingController(text: rx['days']?.toString());

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Prescription'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: medicationController,
                decoration: const InputDecoration(labelText: 'Medication Name *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dosageController,
                decoration: const InputDecoration(labelText: 'Dosage'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: daysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Number of Days *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: instructionsController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Instructions'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final days = int.parse(daysController.text.trim());
                final originalDate = DateTime.parse(rx['createdAt']);
                final expiryDate = originalDate.add(Duration(days: days));

                await _firebase.firestore.collection('prescriptions').doc(rx['id']).update({
                  'medication': medicationController.text.trim(),
                  'dosage': dosageController.text.trim(),
                  'instructions': instructionsController.text.trim(),
                  'days': days,
                  'expiryDate': expiryDate.toIso8601String(),
                });

                Navigator.pop(context);
                _loadPrescriptions();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Prescription updated'), backgroundColor: Colors.green),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deactivatePrescription(String rxId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate Prescription'),
        content: const Text('Move this prescription to history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firebase.firestore.collection('prescriptions').doc(rxId).update({'status': 'inactive'});
      _loadPrescriptions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prescription moved to history')),
        );
      }
    }
  }
}
