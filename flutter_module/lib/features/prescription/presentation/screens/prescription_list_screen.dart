import 'package:flutter/material.dart';
import '../../../../core/services/firebase_service.dart';

class PrescriptionListScreen extends StatelessWidget {
  const PrescriptionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseService _firebase = FirebaseService.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('My Prescriptions')),
      body: StreamBuilder(
        stream: _firebase.watchPrescriptions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No prescriptions'));
          }
          final prescriptions = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: prescriptions.length,
            itemBuilder: (context, index) {
              final rx = prescriptions[index].data() as Map<String, dynamic>;
              return Card(
                child: ListTile(
                  title: Text(rx['medication'] ?? 'N/A'),
                  subtitle: Text('Dosage: ${rx['dosage'] ?? 'N/A'}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
