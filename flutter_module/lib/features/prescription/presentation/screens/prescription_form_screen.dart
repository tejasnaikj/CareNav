import 'package:flutter/material.dart';
import '../../../../core/services/firebase_service.dart';

class PrescriptionFormScreen extends StatefulWidget {
  final String doctorId;
  final String? patientId;
  final String? patientName;

  const PrescriptionFormScreen({
    super.key,
    required this.doctorId,
    this.patientId,
    this.patientName,
  });

  @override
  State<PrescriptionFormScreen> createState() => _PrescriptionFormScreenState();
}

class _PrescriptionFormScreenState extends State<PrescriptionFormScreen> {
  final FirebaseService _firebase = FirebaseService.instance;
  final _medicationController = TextEditingController();
  final _dosageController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _daysController = TextEditingController();
  final _patientNameController = TextEditingController();
  
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.patientName != null) {
      _patientNameController.text = widget.patientName!;
    }
  }

  @override
  void dispose() {
    _medicationController.dispose();
    _dosageController.dispose();
    _instructionsController.dispose();
    _daysController.dispose();
    _patientNameController.dispose();
    super.dispose();
  }

  Future<void> _savePrescription() async {
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

    if (widget.patientId == null && _patientNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter patient name')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final days = int.parse(_daysController.text.trim());
      final expiryDate = DateTime.now().add(Duration(days: days));

      final userData = await _firebase.getCurrentUserData();

      await _firebase.savePrescription({
        'doctorId': widget.doctorId,
        'doctorName': userData?['fullName'] ?? 'Dr. Unknown',
        'patientId': widget.patientId ?? 'unknown',
        'patientName': widget.patientId != null ? widget.patientName! : _patientNameController.text.trim(),
        'medication': _medicationController.text.trim(),
        'dosage': _dosageController.text.trim(),
        'instructions': _instructionsController.text.trim(),
        'days': days,
        'expiryDate': expiryDate.toIso8601String(),
        'status': 'active',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prescription saved successfully'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error saving prescription: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Prescription'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.blue.shade700, Colors.blue.shade500]),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (widget.patientId == null)
              TextField(
                controller: _patientNameController,
                decoration: const InputDecoration(
                  labelText: 'Patient Name *',
                  border: OutlineInputBorder(),
                ),
              ),
            if (widget.patientId == null) const SizedBox(height: 16),
            
            TextField(
              controller: _medicationController,
              decoration: const InputDecoration(
                labelText: 'Medication *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _dosageController,
              decoration: const InputDecoration(
                labelText: 'Dosage',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _daysController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Number of Days *',
                hintText: 'e.g., 7, 14, 30',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _instructionsController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Instructions',
                hintText: 'e.g., Take after meals, twice daily',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            
            ElevatedButton(
              onPressed: _saving ? null : _savePrescription,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Save Prescription', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
