import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class AdminHomeScreen extends StatelessWidget {
  final Function(int) onNavigate;

  const AdminHomeScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'dashHomme.json',
              width: 180,
              height: 180,
              repeat: true,
            ),
            const SizedBox(height: 10),
            const Text(
              'Welcome to eHospital Admin Panel',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Manage doctors, patients, appointments, and more.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            Wrap(
              spacing: 20,
              runSpacing: 20,
              alignment: WrapAlignment.center,
              children: [
                _buildQuickAccessCard(Icons.calendar_today, 'Appointments', 1),
                _buildQuickAccessCard(Icons.people, 'Patients', 2),
                _buildQuickAccessCard(Icons.medical_services, 'Doctors', 3),
                _buildQuickAccessCard(Icons.mark_unread_chat_alt, 'Chats', 4),
                _buildQuickAccessCard(Icons.assignment, 'Requests', 5),
                _buildQuickAccessCard(Icons.design_services, 'Services', 6),
                _buildQuickAccessCard(Icons.money, 'Bills', 7),
                _buildQuickAccessCard(Icons.analytics, 'Reports', 8),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessCard(IconData icon, String title, int index) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => onNavigate(index),
        child: SizedBox(
          width: 160,
          height: 140,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Colors.teal),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
