import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  Future<int> _countUsersByRole(String role) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: role)
        .get();
    return snapshot.size;
  }

  Future<int> _countAppointments() async {
    final snapshot = await FirebaseFirestore.instance.collection('appointments').get();
    return snapshot.size;
  }

  Future<Map<String, int>> _getAppointmentsPerDayThisWeek() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1)); // Monday
    final appointments = await FirebaseFirestore.instance
        .collection('appointments')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
        .get();

    Map<String, int> dailyCounts = {
      for (int i = 0; i < 7; i++) DateFormat.E().format(startOfWeek.add(Duration(days: i))): 0
    };

    for (var doc in appointments.docs) {
      final ts = doc['date'] as Timestamp;
      final day = DateFormat.E().format(ts.toDate());
      if (dailyCounts.containsKey(day)) {
        dailyCounts[day] = dailyCounts[day]! + 1;
      }
    }

    return dailyCounts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const Text('Hospital Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            FutureBuilder(
              future: Future.wait([
                _countUsersByRole('patient'),
                _countUsersByRole('doctor'),
                _countAppointments(),
              ]),
              builder: (context, AsyncSnapshot<List<int>> snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final counts = snapshot.data!;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ReportCard(title: 'Patients', count: counts[0]),
                    _ReportCard(title: 'Doctors', count: counts[1]),
                    _ReportCard(title: 'Appointments', count: counts[2]),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            const Text('Appointments This Week', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            FutureBuilder<Map<String, int>>(
              future: _getAppointmentsPerDayThisWeek(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final data = snapshot.data!;
                final barSpots = data.entries.toList();

                return SizedBox(
                  height: 220,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        barTouchData: BarTouchData(enabled: true),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 1, // Force steps of 1
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(fontSize: 12),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final dayIndex = value.toInt();
                                if (dayIndex < barSpots.length) {
                                  return Text(
                                    barSpots[dayIndex].key.substring(0, 3), // Mon, Tue, etc.
                                    style: const TextStyle(fontSize: 12),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                        ),
                        gridData: FlGridData(show: true),
                        borderData: FlBorderData(show: false),
                        minY: 0, // Always start from zero
                        barGroups: List.generate(barSpots.length, (i) {
                          return BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: barSpots[i].value.toDouble(),
                                color: Colors.blue,
                                width: 14,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          );
                        }),
                      )
                      ,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final int count;

  const _ReportCard({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        elevation: 3,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Text(count.toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
