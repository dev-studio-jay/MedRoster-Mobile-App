import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/api_service.dart';
import '../widgets/error_view.dart';
import 'sandbox_schedule_screen.dart';

class IndividualScheduleScreen extends StatefulWidget {
  final String scheduleId;
  const IndividualScheduleScreen({super.key, required this.scheduleId});

  @override
  State<IndividualScheduleScreen> createState() => _IndividualScheduleScreenState();
}

class _IndividualScheduleScreenState extends State<IndividualScheduleScreen> {
  Map<String, dynamic>? _schedule;
  String? _error;
  bool _saving = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.instance.get('/api/me/schedules/${widget.scheduleId}');
      final map = Map<String, dynamic>.from(data as Map);
      setState(() {
        _schedule = {
          ...map,
          'wardName': map['wardName'] ?? map['name'] ?? 'Roster',
          'staff': map['staff'] ?? [],
          'assignments': map['assignments'] ?? [],
          'holidays': map['holidays'] ?? [],
        };
        _error = null;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _persist(Map<String, dynamic> next) async {
    setState(() {
      _schedule = next;
      _saving = true;
      _error = null;
    });
    try {
      final updated = await ApiService.instance.patch('/api/me/schedules/${widget.scheduleId}', {
        'name': next['name'] ?? next['wardName'],
        'startDate': next['startDate'],
        'endDate': next['endDate'],
        'staff': next['staff'] ?? [],
        'assignments': next['assignments'] ?? [],
        'holidays': next['holidays'] ?? [],
      });
      final map = Map<String, dynamic>.from(updated as Map);
      setState(() {
        _schedule = {
          ...map,
          'wardName': map['wardName'] ?? map['name'] ?? next['wardName'],
          'staff': map['staff'] ?? [],
          'assignments': map['assignments'] ?? [],
          'holidays': map['holidays'] ?? [],
          'rosterSetup': map['rosterSetup'] ?? next['rosterSetup'],
        };
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _export(String format) async {
    if (_schedule == null) return;
    setState(() => _exporting = true);
    try {
      await exportSandboxSchedule(_schedule!, format: format, hospitalLabel: 'Individual account');
    } catch (e) {
      setState(() => _error = 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_schedule == null && _error == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null && _schedule == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorView(message: _error!, onRetry: _load),
      );
    }
    return SandboxScheduleScreen(
      mode: 'individual',
      schedule: _schedule!,
      onChange: _persist,
      saving: _saving,
      exporting: _exporting,
      title: _schedule!['wardName']?.toString() ?? _schedule!['name']?.toString() ?? 'Roster',
      subtitle: _error,
      backLabel: 'Back to schedules',
      onBack: () => context.go('/individual'),
      onExport: _export,
    );
  }
}
