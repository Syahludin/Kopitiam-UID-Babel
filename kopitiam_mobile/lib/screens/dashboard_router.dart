import 'package:flutter/material.dart';
import '../models/har_execution.dart';
import 'har_execution_screen.dart';
import 'dashboard_unified.dart' as unified;

class DashboardScreen extends StatelessWidget {
  final Map<String, dynamic> sesi;
  const DashboardScreen({super.key, required this.sesi});
  @override
  Widget build(BuildContext context) {
    if (HarExecution.allowedTypes(sesi).isNotEmpty) return HarExecutionScreen(sesi:sesi);
    return unified.DashboardScreen(sesi:sesi);
  }
}
