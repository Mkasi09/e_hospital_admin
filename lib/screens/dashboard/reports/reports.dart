import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html; // for web
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int selectedWeekOffset = 0; // 0 = this week, 1 = last week
  bool _isGeneratingPdf = false;

  // Count users by role
  Future<int> _countUsersByRole(String role) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: role)
          .get();
      return snapshot.size;
    } catch (e) {
      return 0;
    }
  }

  // Count total appointments
  Future<int> _countAppointments() async {
    try {
      final snapshot =
      await FirebaseFirestore.instance.collection('appointments').get();
      return snapshot.size;
    } catch (e) {
      return 0;
    }
  }

  // Get appointments per day for a specific week
  Future<Map<String, int>> _getAppointmentsForWeek(int weekOffset) async {
    try {
      final now = DateTime.now();
      final startOfCurrentWeek = now.subtract(Duration(days: now.weekday - 1));
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
    } catch (e) {
      return {
        'Monday': 0,
        'Tuesday': 0,
        'Wednesday': 0,
        'Thursday': 0,
        'Friday': 0,
        'Saturday': 0,
        'Sunday': 0,
      };
    }
  }

  // Get appointments by status
  Future<Map<String, int>> _getAppointmentsByStatus() async {
    try {
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
    } catch (e) {
      return {
        'pending': 0,
        'rejected': 0,
        'confirmed': 0,
        'cancelled': 0,
      };
    }
  }

  // Generate PDF report with pie chart visualization
  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();

    // Get all data needed for the report
    final patientCount = await _countUsersByRole('patient');
    final doctorCount = await _countUsersByRole('doctor');
    final appointmentCount = await _countAppointments();
    final weeklyData = await _getAppointmentsForWeek(selectedWeekOffset);
    final statusData = await _getAppointmentsByStatus();

    // Calculate totals for percentages
    final totalAppointments = statusData.values.fold<int>(0, (sum, v) => sum + v);
    final maxWeeklyValue = weeklyData.values.fold<int>(0, (max, value) => value > max ? value : max);

    // Define text styles
    final headerStyle = pw.TextStyle(
      fontSize: 18,
      fontWeight: pw.FontWeight.bold,
    );

    final titleStyle = pw.TextStyle(
      fontSize: 16,
      fontWeight: pw.FontWeight.bold,
    );

    final boldStyle = pw.TextStyle(
      fontSize: 12,
      fontWeight: pw.FontWeight.bold,
    );

    final normalStyle = pw.TextStyle(
      fontSize: 12,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(bottom: 20),
          child: pw.Text(
            'Hospital Report - ${DateFormat('MMMM dd, yyyy').format(DateTime.now())}',
            style: headerStyle,
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 20),
          pw.Text(
            'Hospital Overview',
            style: titleStyle,
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: [
              _buildPdfStatCard('Patients', patientCount),
              _buildPdfStatCard('Doctors', doctorCount),
              _buildPdfStatCard('Appointments', appointmentCount),
            ],
          ),
          pw.SizedBox(height: 30),
          pw.Text(
            'Weekly Appointments',
            style: titleStyle,
          ),
          pw.SizedBox(height: 10),
          // Weekly appointments table
          pw.Table(
            border: pw.TableBorder.all(),
            children: [
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8.0),
                    child: pw.Text('Day', style: boldStyle),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8.0),
                    child: pw.Text('Appointments', style: boldStyle),
                  ),
                ],
              ),
              ...weeklyData.entries.map((entry) => pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8.0),
                    child: pw.Text(entry.key, style: normalStyle),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8.0),
                    child: pw.Text(entry.value.toString(), style: normalStyle),
                  ),
                ],
              )),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Weekly Appointments Chart',
            style: titleStyle,
          ),
          pw.SizedBox(height: 10),
          // Bar chart representation
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Daily Appointment Distribution:', style: boldStyle),
                pw.SizedBox(height: 10),
                ...weeklyData.entries.map((entry) {
                  final percentage = maxWeeklyValue == 0 ? 0 : (entry.value / maxWeeklyValue * 100);
                  return pw.Column(
                    children: [
                      pw.Row(
                        children: [
                          pw.Container(
                            width: 80,
                            child: pw.Text(entry.key, style: normalStyle),
                          ),
                          pw.SizedBox(width: 10),
                          pw.Container(
                            width: 40,
                            child: pw.Text(
                              entry.value.toString(),
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                              ),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                          pw.SizedBox(width: 10),
                          pw.Expanded(
                            child: pw.Container(
                              height: 20,
                              decoration: pw.BoxDecoration(
                                color: PdfColors.blue,
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                              width: percentage * 2.0,
                              child: entry.value > 0 ? pw.Center(
                                child: pw.Text(
                                  '${percentage.toStringAsFixed(0)}%',
                                  style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ) : pw.SizedBox(),
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                    ],
                  );
                }),
              ],
            ),
          ),
          pw.SizedBox(height: 30),
          pw.Text(
            'Appointments by Status',
            style: titleStyle,
          ),
          pw.SizedBox(height: 10),
          // Status table
          pw.Table(
            border: pw.TableBorder.all(),
            children: [
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8.0),
                    child: pw.Text('Status', style: boldStyle),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8.0),
                    child: pw.Text('Count', style: boldStyle),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8.0),
                    child: pw.Text('Percentage', style: boldStyle),
                  ),
                ],
              ),
              ...statusData.entries.map((entry) {
                final percentage = totalAppointments == 0 ? 0.0 : (entry.value / totalAppointments * 100);
                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8.0),
                      child: pw.Row(
                        children: [
                          pw.Container(
                            width: 10,
                            height: 10,
                            decoration: pw.BoxDecoration(
                              color: _getPdfStatusColor(entry.key),
                              shape: pw.BoxShape.circle,
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Text(_capitalize(entry.key), style: normalStyle),
                        ],
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8.0),
                      child: pw.Text(entry.value.toString(), style: normalStyle),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8.0),
                      child: pw.Text('${percentage.toStringAsFixed(1)}%', style: normalStyle),
                    ),
                  ],
                );
              }),
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8.0),
                    child: pw.Text('Total', style: boldStyle),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8.0),
                    child: pw.Text(totalAppointments.toString(), style: boldStyle),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8.0),
                    child: pw.Text('100%', style: boldStyle),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Status Distribution Pie Chart',
            style: titleStyle,
          ),
          pw.SizedBox(height: 10),
          // Simplified Pie Chart Visualization using colored circles
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              children: [
                // Pie chart representation using concentric circles
                pw.Container(
                  height: 180,
                  child: pw.Stack(
                    alignment: pw.Alignment.center,
                    children: [
                      // Background circle
                      pw.Container(
                        width: 150,
                        height: 150,
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey100,
                          shape: pw.BoxShape.circle,
                        ),
                      ),
                      // Concentric circles representing percentages
                      ..._buildConcentricCircles(statusData, totalAppointments),
                      // Center text
                      pw.Container(
                        width: 60,
                        height: 60,
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          shape: pw.BoxShape.circle,
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            'Total\n$totalAppointments',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                // Legend
                pw.Wrap(
                  spacing: 15,
                  runSpacing: 8,
                  children: statusData.entries.map((entry) {
                    final percentage = totalAppointments == 0 ? 0.0 : (entry.value / totalAppointments * 100);
                    return pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Container(
                          width: 12,
                          height: 12,
                          decoration: pw.BoxDecoration(
                            color: _getPdfStatusColor(entry.key),
                            shape: pw.BoxShape.circle,
                          ),
                        ),
                        pw.SizedBox(width: 6),
                        pw.Text(
                          '${_capitalize(entry.key)}: ${entry.value} (${percentage.toStringAsFixed(1)}%)',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    return pdf.save();
  }

// Helper method to build concentric circles for pie chart representation
  List<pw.Widget> _buildConcentricCircles(Map<String, int> statusData, int total) {
    if (total == 0) return [];

    final List<pw.Widget> circles = [];
    final statusEntries = statusData.entries.where((entry) => entry.value > 0).toList();

    // Calculate circle sizes based on percentages
    for (int i = 0; i < statusEntries.length; i++) {
      final entry = statusEntries[i];
      final percentage = entry.value / total;

      // Size decreases for each subsequent status
      final circleSize = 150 - (i * 30); // Start from 150 and decrease by 30 for each status

      circles.add(
        pw.Container(
          width: circleSize.toDouble(),
          height: circleSize.toDouble(),
          decoration: pw.BoxDecoration(
            color: _getPdfStatusColor(entry.key),
            shape: pw.BoxShape.circle,
          ),
          child: pw.Center(
            child: pw.Text(
              '${(percentage * 100).toStringAsFixed(0)}%',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: circleSize > 100 ? 12 : 8,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    return circles;
  }

// Helper method to get PDF colors for status
  PdfColor _getPdfStatusColor(String status) {
    switch (status) {
      case 'pending':
        return PdfColors.orange;
      case 'rejected':
        return PdfColors.red;
      case 'confirmed':
        return PdfColors.green;
      case 'cancelled':
        return PdfColors.grey;
      default:
        return PdfColors.blue;
    }
  }


  pw.Widget _buildPdfStatCard(String title, int count) {
    return pw.Container(
      width: 100,
      height: 80,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(title, style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 5),
          pw.Text(
            count.toString(),
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // Save and share PDF with web support
  Future<void> _saveAndSharePdf() async {
    if (_isGeneratingPdf) return;

    setState(() {
      _isGeneratingPdf = true;
    });

    try {
      // Show generating dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          title: Text('Generating PDF'),
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Creating your report...'),
            ],
          ),
        ),
      );

      final pdfBytes = await _generatePdf();
      final fileName = 'hospital_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';

      if (mounted) {
        Navigator.of(context).pop();

        if (kIsWeb) {
          // Web download
          final blob = html.Blob([pdfBytes], 'application/pdf');
          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.AnchorElement(href: url)
            ..setAttribute('download', fileName)
            ..click();
          html.Url.revokeObjectUrl(url);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF download started!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // Mobile download
          try {
            final dir = await getTemporaryDirectory();
            final file = File('${dir.path}/$fileName');
            await file.writeAsBytes(pdfBytes);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('PDF saved at: ${file.path}'),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            // Fallback for mobile if file system fails
            _showPdfDownloadOptions(pdfBytes, fileName);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPdf = false;
        });
      }
    }
  }

  // Fallback PDF download options
  Future<void> _showPdfDownloadOptions(Uint8List pdfBytes, String fileName) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.picture_as_pdf, color: Colors.red),
            SizedBox(width: 8),
            Text('PDF Ready for Download'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File: $fileName'),
            Text('Size: ${(pdfBytes.length / 1024).toStringAsFixed(1)} KB'),
            const SizedBox(height: 20),
            const Text(
              'Download Options:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildDownloadOption(
              Icons.download,
              'Download PDF File',
              'Get the actual PDF file to save on your device',
                  () {
                Navigator.of(context).pop();
                _downloadPdfFile(pdfBytes, fileName);
              },
            ),
            const SizedBox(height: 12),
            _buildDownloadOption(
              Icons.preview,
              'View Report Preview',
              'See the complete report data in the app',
                  () {
                Navigator.of(context).pop();
                _previewReport();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadOption(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        onTap: onTap,
      ),
    );
  }

  void _downloadPdfFile(Uint8List pdfBytes, String fileName) {
    // Convert to base64 for easy sharing
    final base64Pdf = base64Encode(pdfBytes);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download PDF'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your PDF is ready! Follow these steps to download it:'),
              const SizedBox(height: 20),
              _buildDownloadStep(1, 'Copy the PDF data below (tap and hold to select all)'),
              _buildDownloadStep(2, 'Go to: https://base64.guru/converter/decode/pdf'),
              _buildDownloadStep(3, 'Paste the copied data into the input box'),
              _buildDownloadStep(4, 'Click "DECODE BASE64 TO PDF"'),
              _buildDownloadStep(5, 'Download your PDF file'),
              const SizedBox(height: 20),
              const Text(
                'PDF Data (select and copy all text below):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: 200,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    base64Pdf,
                    style: const TextStyle(fontSize: 6, fontFamily: 'monospace'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              // Show copy confirmation
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Select and copy the text above, then follow the download steps'),
                  duration: Duration(seconds: 5),
                ),
              );
            },
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadStep(int number, String text) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  number.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        )
    );
  }

  // Preview report data
  Future<void> _previewReport() async {
    if (_isGeneratingPdf) return;

    setState(() {
      _isGeneratingPdf = true;
    });

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          title: Text('Loading Report'),
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Loading report data...'),
            ],
          ),
        ),
      );

      // Get all the data for the preview
      final patientCount = await _countUsersByRole('patient');
      final doctorCount = await _countUsersByRole('doctor');
      final appointmentCount = await _countAppointments();
      final weeklyData = await _getAppointmentsForWeek(selectedWeekOffset);
      final statusData = await _getAppointmentsByStatus();
      final totalAppointments = statusData.values.fold<int>(0, (sum, v) => sum + v);

      if (mounted) {
        Navigator.of(context).pop();

        // Show the actual report data
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.analytics, color: Colors.blue),
                SizedBox(width: 8),
                Text('Hospital Report'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Center(
                    child: Text(
                      'Hospital Report - ${DateFormat('MMMM dd, yyyy').format(DateTime.now())}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Hospital Overview
                  const Text(
                    'Hospital Overview',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildPreviewStatCard('Patients', patientCount),
                      _buildPreviewStatCard('Doctors', doctorCount),
                      _buildPreviewStatCard('Appointments', appointmentCount),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Weekly Appointments
                  const Text(
                    'Weekly Appointments',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        // Table Header
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Day',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Appointments',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Table Rows
                        ...weeklyData.entries.map((entry) => Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: Colors.grey[300]!)),
                          ),
                          child: Row(
                            children: [
                              Expanded(child: Text(entry.key)),
                              Expanded(
                                child: Text(
                                  entry.value.toString(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Appointments by Status
                  const Text(
                    'Appointments by Status',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        // Table Header
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Status',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Count',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Percentage',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Table Rows
                        ...statusData.entries.map((entry) {
                          final percentage = totalAppointments == 0 ? 0.0 : (entry.value / totalAppointments * 100);
                          return Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border(top: BorderSide(color: Colors.grey[300]!)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(entry.key),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(_capitalize(entry.key)),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    entry.value.toString(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '${percentage.toStringAsFixed(1)}%',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Total Appointments: $totalAppointments',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _saveAndSharePdf();
                },
                child: const Text('Download PDF'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPdf = false;
        });
      }
    }
  }

  Widget _buildPreviewStatCard(String title, int count) {
    return Container(
        width: 80,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        )
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      case 'confirmed':
        return Colors.green;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  String _capitalize(String text) {
    return text[0].toUpperCase() + text.substring(1);
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
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'preview':
                  _previewReport();
                  break;
                case 'pdf':
                  _saveAndSharePdf();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'preview',
                child: Row(
                  children: [
                    Icon(Icons.preview, size: 20),
                    SizedBox(width: 8),
                    Text('View Report'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, size: 20),
                    SizedBox(width: 8),
                    Text('Download PDF'),
                  ],
                ),
              ),
            ],
            icon: _isGeneratingPdf
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.analytics),
          ),
        ],
      ),
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
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
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
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
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
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final statusData = snapshot.data!;
                final total = statusData.values.fold<int>(0, (sum, v) => sum + v);

                return Column(
                  children: [
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sections: statusData.entries.map((entry) {
                            final percentage = total == 0 ? 0.0 : (entry.value / total * 100);
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