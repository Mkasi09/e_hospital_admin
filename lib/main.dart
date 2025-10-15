import 'package:e_hospotal_admin/firebase_auth/admin_signIn.dart';
import 'package:e_hospotal_admin/screens/dashboard/admin_dashboard.dart';
import 'package:e_hospotal_admin/screens/dashboard/doctors/add_doctor.dart';
import 'package:e_hospotal_admin/screens/dashboard/doctors/doctors_management.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: webFirebaseOptions);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eHospital',
      theme: ThemeData(
        scaffoldBackgroundColor: Color(0xFFE0F2F1), // ✅ Screen background
        primarySwatch: Colors.teal, // ✅ Widgets & buttons teal
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF00796B), // ✅ AppBar teal
          foregroundColor: Colors.white, // ✅ AppBar text/icons white
          elevation: 0,
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: AdminDashboard(),
    );
  }
}
