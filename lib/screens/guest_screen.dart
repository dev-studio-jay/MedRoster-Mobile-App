import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../util/guest_storage.dart';
import 'sandbox_schedule_screen.dart';

class GuestScreen extends StatefulWidget {
  const GuestScreen({super.key});

  @override
  State<GuestScreen> createState() => _GuestScreenState();
}

class _GuestScreenState extends State<GuestScreen> {
  late Map<String, dynamic> _schedule;
  bool _hydrated = false;
  bool _exporting = false;
  bool _showBanner = true;
  int _exportsLeft = maxGuestExports;
  String? _toast;

  @override
  void initState() {
    super.initState();
    _schedule = defaultMonthSchedule();
    _hydrate();
  }

  Future<void> _hydrate() async {
    final saved = await getGuestSchedule();
    final left = await getGuestExportsRemaining();
    if (!mounted) return;
    setState(() {
      if (saved != null) _schedule = saved;
      _exportsLeft = left;
      _hydrated = true;
    });
  }

  Future<void> _onChange(Map<String, dynamic> next) async {
    setState(() => _schedule = next);
    if (_hydrated) await saveGuestSchedule(next);
  }

  Future<void> _export(String format) async {
    if (_exportsLeft <= 0 || !await consumeGuestExport()) {
      if (!mounted) return;
      setState(() => _toast = 'Export limit reached ($maxGuestExports). Register to keep exporting.');
      return;
    }
    final left = await getGuestExportsRemaining();
    setState(() {
      _exportsLeft = left;
      _exporting = true;
      _toast = null;
    });
    try {
      await exportSandboxSchedule(_schedule, format: format, hospitalLabel: 'Guest roster (not saved to cloud)');
    } catch (e) {
      setState(() => _toast = 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hydrated) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return SandboxScheduleScreen(
      mode: 'guest',
      schedule: _schedule,
      onChange: _onChange,
      exporting: _exporting,
      title: _schedule['wardName']?.toString() ?? 'Guest roster',
      subtitle: '$_exportsLeft exports left · not saved to cloud',
      backLabel: 'Sign in / register',
      onBack: () => context.go('/auth/login'),
      onExport: _export,
      banner: _showBanner
          ? Material(
              color: AppColors.teal.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                child: Row(children: [
                  const Expanded(
                    child: Text(
                      'Trying MedRoster as a guest. Register to save schedules to the cloud.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(onPressed: () => context.go('/auth/register'), child: const Text('Register')),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _showBanner = false),
                  ),
                ]),
              ),
            )
          : (_toast != null
              ? MaterialBanner(
                  content: Text(_toast!),
                  actions: [TextButton(onPressed: () => setState(() => _toast = null), child: const Text('OK'))],
                )
              : null),
    );
  }
}
