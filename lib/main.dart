import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Graceful handling if Firebase is already initialized or running in test/mock mode
    debugPrint('Firebase initialization notice: $e');
  }

  runApp(
    const ProviderScope(
      child: UsOnlyApp(),
    ),
  );
}
