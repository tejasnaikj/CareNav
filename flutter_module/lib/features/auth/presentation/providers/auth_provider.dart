import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/firebase_service.dart';
import '../../data/models/user_model.dart';

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final FirebaseService _firebase = FirebaseService.instance;

  AuthNotifier() : super(const AsyncValue.loading()) {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    try {
      final userData = await _firebase.getCurrentUserData();
      if (userData != null) {
        final user = User.fromMap(userData);
        print('✅ Found logged in user: ${user.username}');
        state = AsyncValue.data(user);
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, stack) {
      print('❌ Check auth error: $e');
      state = const AsyncValue.data(null);
    }
  }

  Future<bool> login(String username, String password) async {
    try {
      print('🔐 Login attempt: $username');
      state = const AsyncValue.loading();
      
      final userData = await _firebase.login(username, password);
      
      if (userData != null) {
        final user = User.fromMap(userData);
        print('✅ User logged in: ${user.username} (${user.userType})');
        state = AsyncValue.data(user);
        return true;
      } else {
        state = const AsyncValue.data(null);
        return false;
      }
    } catch (e, stack) {
      print('❌ Login error: $e');
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> checkUsername(String username) async {
    return await _firebase.usernameExists(username);
  }

  Future<void> logout() async {
    await _firebase.logout();
    state = const AsyncValue.data(null);
  }
}
