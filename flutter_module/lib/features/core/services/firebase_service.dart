import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  static FirebaseService get instance => _instance;

  final firebase.FirebaseAuth _auth = firebase.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<firebase.User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      print('🔐 FirebaseAuth: Logging in as $email with empty reCAPTCHA token'); // Match your logs
      final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return credential.user;
    } catch (e) {
      throw Exception('Sign-in failed: $e');
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<Map<String, dynamic>?> getUserData(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.data();
  }

  Stream<firebase.User?> get authStateChanges => _auth.authStateChanges();

  // Expose for demo (remove in prod)
  firebase.FirebaseAuth get _authExposed => _auth;
  FirebaseFirestore get _firestoreExposed => _firestore;
}
