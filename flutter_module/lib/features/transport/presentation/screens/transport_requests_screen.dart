import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/firebase_service.dart';

class TransportRequestsScreen extends ConsumerStatefulWidget {
  const TransportRequestsScreen({super.key});

  @override
  ConsumerState<TransportRequestsScreen> createState() => _TransportRequestsScreenState();
}

class _TransportRequestsScreenState extends ConsumerState<TransportRequestsScreen> {
  final FirebaseService _firebase = FirebaseService.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transport Requests'),
        backgroundColor: Colors.orange,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping, size: 100, color: Colors.orange.shade300),
            const SizedBox(height: 20),
            const Text(
              'No transport requests',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            const Text(
              'Transport requests feature coming soon...',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
