import 'package:e_hospotal_admin/screens/dashboard/reports/reports.dart';
import 'package:e_hospotal_admin/screens/dashboard/service_requests/service_requests_management.dart';
import 'package:flutter/material.dart';
import 'appointments/appointments_management.dart';
import 'doctors/doctors_management.dart';
import 'home/home_screen.dart';
import 'patients/patients_manageent.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int selectedIndex = 0;

  void handleNavigation(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Move pages here so handleNavigation is in scope
    final List<Widget> pages = [
      AdminHomeScreen(onNavigate: handleNavigation),
      const AppointmentsScreen(),
      const PatientsScreen(),
      const DoctorsScreen(),
      const ReportsScreen(),
      const ServiceRequestsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 60),
            const SizedBox(width: 8),
            const Text('eHospital Admin Dashboard'),
          ],
        ),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // TODO: Implement Firebase sign-out
            },
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: handleNavigation,
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard),
                label: Text('Home'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.calendar_today),
                label: Text('Appointments'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people),
                label: Text('Patients'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.medical_services),
                label: Text('Doctors'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.analytics),
                label: Text('Reports'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.assignment),
                label: Text('Requests'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: pages[selectedIndex],
            ),
          ),
        ],
      ),
    );
  }
}
