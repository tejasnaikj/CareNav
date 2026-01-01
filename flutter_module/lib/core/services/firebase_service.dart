import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  static final FirebaseService instance = FirebaseService._();
  FirebaseService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  FirebaseFirestore get firestore => _firestore;

  Future<User?> getCurrentUser() async {
    try {
      await _auth.currentUser?.reload();
      return _auth.currentUser;
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCurrentUserData() async {
    final user = await getCurrentUser();
    if (user == null) return null;
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (data != null) data['id'] = doc.id;
      return data;
    } catch (e) {
      print('Error fetching user data: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> login(String username, String password) async {
    try {
      final query = await _firestore.collection('users').where('username', isEqualTo: username).limit(1).get();
      if (query.docs.isEmpty) throw FirebaseAuthException(code: 'user-not-found');
      final userDoc = query.docs.first;
      final email = userDoc['email'] as String;
      
      final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      final data = userDoc.data();
      data['id'] = userDoc.id;
      return data;
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }

  Future<bool> usernameExists(String username) async {
    try {
      final query = await _firestore.collection('users').where('username', isEqualTo: username).limit(1).get();
      return query.docs.isNotEmpty;
    } catch (e) {
      print('Error checking username: $e');
      return false;
    }
  }

  Future<bool> registerUser(Map<String, dynamic> userData) async {
    try {
      final email = userData['email'] as String;
      final password = userData['password'] as String;
      final username = userData['username'] as String;

      if (await usernameExists(username)) return false;

      final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      userData['uid'] = credential.user!.uid;
      userData['userType'] = userData['role'] ?? 'patient';
      userData['role'] = userData['role'] ?? 'patient';

      await _firestore.collection('users').doc(credential.user!.uid).set(userData);
      return true;
    } catch (e) {
      print('Register error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Stream<QuerySnapshot> watchDoctorActiveSession(String doctorId) {
    return _firestore.collection('sessions')
        .where('doctorId', isEqualTo: doctorId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .snapshots();
  }

  Stream<QuerySnapshot> watchDoctorQueue(String doctorId) {
    return _firestore.collection('queues').where('doctorId', isEqualTo: doctorId).snapshots();
  }

  Future<void> removeFromQueue(String queueId) async {
    await _firestore.collection('queues').doc(queueId).delete();
  }

  Future<String> createSession(Map<String, dynamic> data) async {
    final ref = await _firestore.collection('sessions').add(data);
    return ref.id;
  }

  Future<List<Map<String, dynamic>>> getAllDoctors() async {
    final snapshot = await _firestore.collection('users').where('userType', isEqualTo: 'doctor').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Future<void> addToQueue(Map<String, dynamic> queueData) async {
    await _firestore.collection('queues').add(queueData);
  }

  Future<void> sendMessage(String sessionId, Map<String, dynamic> message) async {
    final messageData = Map<String, dynamic>.from(message);
    messageData['timestamp'] = DateTime.now().toIso8601String();
    messageData['serverTimestamp'] = FieldValue.serverTimestamp();
    
    await _firestore.collection('sessions').doc(sessionId).collection('messages').add(messageData);
  }

  Future<void> updateSession(String sessionId, Map<String, dynamic> updates) async {
    await _firestore.collection('sessions').doc(sessionId).update(updates);
  }

  Stream<QuerySnapshot> watchSessionMessages(String sessionId) {
    return _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots();
  }

  Future<List<Map<String, dynamic>>> getDoctorPatients(String doctorId) async {
    final sessionsSnapshot = await _firestore.collection('sessions')
        .where('doctorId', isEqualTo: doctorId)
        .get();

    final Map<String, Map<String, dynamic>> patientsMap = {};
    
    for (var doc in sessionsSnapshot.docs) {
      final data = doc.data();
      final patientId = data['patientId'];
      if (patientId != null && !patientsMap.containsKey(patientId)) {
        patientsMap[patientId] = {
          'patientId': patientId,
          'patientName': data['patientName'],
          'lastSeen': data['endTime'] ?? data['startTime'],
        };
      }
    }

    final patients = patientsMap.values.toList();
    patients.sort((a, b) => (b['lastSeen'] ?? '').compareTo(a['lastSeen'] ?? ''));
    return patients;
  }

  Future<List<Map<String, dynamic>>> getPatientSessions(String doctorId, String patientId) async {
    print('🔍 Getting sessions for doctor: $doctorId, patient: $patientId');
    
    final snapshot = await _firestore.collection('sessions')
        .where('doctorId', isEqualTo: doctorId)
        .get();

    print('🔍 Found ${snapshot.docs.length} total sessions');

    final sessions = snapshot.docs.where((doc) {
      final data = doc.data();
      return data['patientId'] == patientId && data['status'] == 'completed';
    }).map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();

    sessions.sort((a, b) {
      final aTime = a['startTime'] ?? '';
      final bTime = b['startTime'] ?? '';
      return bTime.toString().compareTo(aTime.toString());
    });

    print('🔍 Found ${sessions.length} completed sessions for this patient');

    return sessions;
  }

  Future<Map<String, dynamic>?> getSession(String sessionId) async {
    final doc = await _firestore.collection('sessions').doc(sessionId).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    data['id'] = doc.id;
    return data;
  }

  Future<void> saveDrawing(String sessionId, String imageBase64, String? notes) async {
    await _firestore.collection('drawings').add({
      'sessionId': sessionId,
      'imageData': imageBase64,
      'notes': notes ?? '',
      'timestamp': DateTime.now().toIso8601String(),
      'serverTimestamp': FieldValue.serverTimestamp(),
    });
  }

  // FIXED: Get drawings without index requirement
  Future<List<Map<String, dynamic>>> getSessionDrawings(String sessionId) async {
    print('🎨 Getting drawings for session: $sessionId');
    
    try {
      // Simple query - only filter by sessionId, NO orderBy
      final snapshot = await _firestore.collection('drawings')
          .where('sessionId', isEqualTo: sessionId)
          .get();

      print('🎨 Found ${snapshot.docs.length} drawings');

      // Get all drawings
      final drawings = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort by timestamp on client side
      drawings.sort((a, b) {
        final aTime = a['timestamp'] ?? '';
        final bTime = b['timestamp'] ?? '';
        return aTime.toString().compareTo(bTime.toString());
      });

      return drawings;
    } catch (e) {
      print('❌ Error getting drawings: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getDoctorPastSessions(String doctorId) async {
    final snapshot = await _firestore.collection('sessions')
        .where('doctorId', isEqualTo: doctorId)
        .get();
    
    final completed = snapshot.docs.where((doc) {
      return doc.data()['status'] == 'completed';
    }).map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();

    completed.sort((a, b) {
      final aTime = a['endTime'] ?? '';
      final bTime = b['endTime'] ?? '';
      return bTime.toString().compareTo(aTime.toString());
    });

    return completed.take(50).toList();
  }

  Stream<QuerySnapshot> watchPrescriptions() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.empty();
    return _firestore
        .collection('prescriptions')
        .where('patientId', isEqualTo: uid)
        .snapshots();
  }

  Future<void> savePrescription(Map<String, dynamic> prescription) async {
    prescription['createdAt'] = DateTime.now().toIso8601String();
    prescription['serverTimestamp'] = FieldValue.serverTimestamp();
    await _firestore.collection('prescriptions').add(prescription);
  }

  Future<List<Map<String, dynamic>>> getPatientPrescriptions(String patientId, {String? status}) async {
    print('💊 Getting prescriptions for patient: $patientId, status: $status');
    
    final snapshot = await _firestore.collection('prescriptions')
        .where('patientId', isEqualTo: patientId)
        .get();

    print('💊 Found ${snapshot.docs.length} total prescriptions');

    var prescriptions = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();

    if (status != null) {
      prescriptions = prescriptions.where((rx) => rx['status'] == status).toList();
    }

    prescriptions.sort((a, b) {
      final aTime = a['createdAt'] ?? '';
      final bTime = b['createdAt'] ?? '';
      return bTime.toString().compareTo(aTime.toString());
    });

    print('💊 Returning ${prescriptions.length} prescriptions');

    return prescriptions;
  }

  Future<List<Map<String, dynamic>>> getDoctorPrescriptions(String doctorId) async {
    final snapshot = await _firestore.collection('prescriptions')
        .where('doctorId', isEqualTo: doctorId)
        .get();
    
    final prescriptions = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();

    prescriptions.sort((a, b) {
      final aTime = a['createdAt'] ?? '';
      final bTime = b['createdAt'] ?? '';
      return bTime.toString().compareTo(aTime.toString());
    });

    return prescriptions.take(50).toList();
  }

  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> createUserWithEmailAndPassword(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }
}
