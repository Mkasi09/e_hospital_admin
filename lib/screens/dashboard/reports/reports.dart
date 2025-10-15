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
  int selectedWeekOffset = 0; // 0 = this week, 1 = last week

  // Count users by role
  Future<int> _countUsersByRole(String role) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: role)
        .get();
    return snapshot.size;
  }

  // Count total appointments
  Future<int> _countAppointments() async {
    final snapshot =
    await FirebaseFirestore.instance.collection('appointments').get();
    return snapshot.size;
  }

  // Get appointments per day for a specific week
  Future<Map<String, int>> _getAppointmentsForWeek(int weekOffset) async {
    final now = DateTime.now();
    final startOfCurrentWeek = now.subtract(Duration(days: now.weekday - 1)); // Monday
    final startOfTargetWeek =
    startOfCurrentWeek.subtract(Duration(days: 7 * weekOffset));
    final endOfTargetWeek = startOfTargetWeek.add(const Duration(days: 7));

    final appointments = await FirebaseFirestore.instance
        .collection('appointments')
        .where('date',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startOfTargetWeek))
        .where('date', isLessThan: Timestamp.fromDate(endOfTargetWeek))
        .get();

    Map<String, int> dailyCounts = {
      for (int i = 0; i < 7; i++)
        DateFormat.E().format(startOfTargetWeek.add(Duration(days: i))): 0,
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

  // Get appointments by status
  Future<Map<String, int>> _getAppointmentsByStatus() async {
    final snapshot =
    await FirebaseFirestore.instance.collection('appointments').get();
    Map<String, int> statusCounts = {
      'pending': 0,
      'rejected': 0,
      'confirmed': 0,
      'cancelled': 0,
    };

    for (var doc in snapshot.docs) {
      final status = doc['status'] ?? 'cancelled';
      if (statusCounts.containsKey(status)) {
        statusCounts[status] = statusCounts[status]! + 1;
      }
    }

    return statusCounts;
  }

  @override
  Widget build(BuildContext context) {
    final statusColorMap = {
      'pending': Colors.orange,
      'rejected': Colors.red,
      'confirmed': Colors.green,
      'cancelled': Colors.grey,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const Text(
              'Hospital Overview',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            FutureBuilder(
              future: Future.wait([
                _countUsersByRole('patient'),
                _countUsersByRole('doctor'),
                _countAppointments(),
              ]),
              builder: (context, AsyncSnapshot<List<int>> snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
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

            // Week selector dropdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Appointments per Week',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                DropdownButton<int>(
                  value: selectedWeekOffset,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text("This Week")),
                    DropdownMenuItem(value: 1, child: Text("Last Week")),
                    DropdownMenuItem(value: 2, child: Text("2 Weeks Ago")),
                    DropdownMenuItem(value: 3, child: Text("3 Weeks Ago")),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedWeekOffset = value!;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            FutureBuilder<Map<String, int>>(
              future: _getAppointmentsForWeek(selectedWeekOffset),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final data = snapshot.data!;
                final barSpots = data.entries.toList();

                return SizedBox(
                  height: 220,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: BarChart(
                      BarChartData(
                        maxY: (barSpots.map((e) => e.value).fold<int>(0, (p, c) => c > p ? c : p) + 1).toDouble(),
                        alignment: BarChartAlignment.spaceAround,
                        barTouchData: BarTouchData(enabled: true),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                // Only show whole numbers, start from 1
                                if (value % 1 == 0 && value >= 1) {
                                  return Text(
                                    value.toInt().toString(),
                                    style: const TextStyle(fontSize: 12),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          // Hide right titles (they’re showing the unwanted 0.2, 0.4…)
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final dayIndex = value.toInt();
                                if (dayIndex < barSpots.length) {
                                  return Text(
                                    barSpots[dayIndex].key.substring(0, 3),
                                    style: const TextStyle(fontSize: 12),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),

                        gridData: FlGridData(show: true),
                        borderData: FlBorderData(show: false),
                        minY: 1,
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
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),
            const Text(
              'Appointments by Status',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            FutureBuilder<Map<String, int>>(
              future: _getAppointmentsByStatus(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final statusData = snapshot.data!;
                final total =
                statusData.values.fold<int>(0, (sum, v) => sum + v);

                return Column(
                  children: [
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sections: statusData.entries.map((entry) {
                            final percentage =
                            total == 0 ? 0.0 : (entry.value / total * 100);
                            return PieChartSectionData(
                              value: entry.value.toDouble(),
                              color: statusColorMap[entry.key],
                              title: '${percentage.toStringAsFixed(1)}%',
                              radius: 60,
                              titleStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          }).toList(),
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      children: statusData.keys.map((status) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              color: statusColorMap[status],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              status[0].toUpperCase() + status.substring(1),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Report card widget
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
              Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
