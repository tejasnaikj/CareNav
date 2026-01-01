import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <--- 1. Import needed for SystemNavigator
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/register_screen.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/dashboard/presentation/screens/patient_dashboard.dart';
import 'features/dashboard/presentation/screens/doctor_dashboard.dart';
import 'features/dashboard/presentation/screens/admin_dashboard.dart';
import 'core/services/seed_demo_users.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    print('✅ Firebase initialized');
    await DemoDataSeeder.seedDemoUsers();
  } catch (e) {
    print('❌ Firebase initialization error: $e');
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medical Translation System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const UnityExitWrapper(child: LoginScreen()), // Wrap routes too
        '/register': (context) => const UnityExitWrapper(child: RegisterScreen()),
      },
    );
  }
}

// 2. Helper Widget: Adds a floating "Back to Unity" button on top of any screen
class UnityExitWrapper extends StatelessWidget {
  final Widget child;
  const UnityExitWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child, // The actual screen (Dashboard/Login)
        Positioned(
          top: 40, // Adjust for status bar
          left: 10,
          child: Material(
            color: Colors.transparent,
            child: FloatingActionButton.small(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 4,
              onPressed: () {
                print("⬅️ Exiting Flutter, returning to Unity...");
                SystemNavigator.pop(); // <--- This closes Flutter and shows Unity
              },
              child: const Icon(Icons.arrow_back),
            ),
          ),
        ),
      ],
    );
  }
}

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          print('🔍 No user - showing login');
          // 3. Wrap screens with the Exit Logic
          return const UnityExitWrapper(child: LoginScreen());
        }

        print('🔍 User found: ${user.username} (${user.userType}) - ID: ${user.id}');

        // Navigate based on user type
        if (user.userType.toLowerCase() == 'patient') {
          print('➡️ Navigating to Patient Dashboard');
          return UnityExitWrapper(child: PatientDashboard(patient: user));
        } else if (user.userType.toLowerCase() == 'doctor') {
          print('➡️ Navigating to Doctor Dashboard');
          return UnityExitWrapper(child: DoctorDashboard(doctor: user));
        } else if (user.userType.toLowerCase() == 'admin') {
          print('➡️ Navigating to Admin Dashboard');
          return UnityExitWrapper(child: AdminDashboard(admin: user));
        } else {
          print('⚠️ Unknown user type: ${user.userType}');
          return const UnityExitWrapper(child: LoginScreen());
        }
      },
      loading: () {
        print('⏳ Loading auth state...');
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading...'),
              ],
            ),
          ),
        );
      },
      error: (error, stack) {
        print('❌ Auth error: $error');
        return UnityExitWrapper( // Allow exit even on error screen
          child: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: $error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(authNotifierProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}