import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:afcm_assignment/screen/registration.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Add this print to see if code even starts
  debugPrint("Starting app initialization...");

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("Firebase initialized successfully!");
    runApp(const MyApp());
  } catch (e, stackTrace) {
    // This will print the EXACT error to your terminal
    debugPrint("CRITICAL ERROR: $e");
    debugPrint("STACK TRACE: $stackTrace");
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CarPool App',
      debugShowCheckedModeBanner: false, // Cleaner UI
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const RegistrationScreen(),
    );
  }
}