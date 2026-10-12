import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../util/dates.dart';
import '../util/ghana_data.dart';
import '../util/guest_storage.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_view.dart';

class IndividualHomeScreen extends StatefulWidget {
  const IndividualHomeScreen({super.key});

  @override
  State<IndividualHomeScreen> createState() => _IndividualHomeScreenState();
}

class _IndividualHomeScreenState extends State<IndividualHomeScreen> {
  List<Map<String, dynamic>> _schedules = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  bool _showUpgrade = false;
  final _hospitalNameCtrl = TextEditingController();
  String _hospitalType = hospitalTypes.contains('District Hospital') ? 'District Hospital' : hospitalTypes.first;
  String _region = ghanaRegions.contains('Greater Accra') ? 'Greater Accra' : ghanaRegions.first;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _hospitalNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final me = await ApiService.instance.loadProfile();
      if (me['accountType'] == 'enterprise' && (me['hospitalId']?.toString().isNotEmpty ?? false)) {
        if (mounted) context.go('/');
        return;
      }
      final guest = await takeGuestDataForMigration();
      if (guest != null && guest['startDate'] != null && guest['endDate'] != null) {
        await ApiService.instance.post('/api/me/schedules', {
          'name': guest['name'] ?? 'Migrated guest schedule',
          'startDate': guest['startDate'],
          'endDate': guest['endDate'],
          'staff': guest['staff'] ?? [],
          'assignments': guest['assignments'] ?? [],
          'holidays': guest['holidays'] ?? [],
        }).catchError((_) => null);
      }
      final list = await ApiService.instance.get('/api/me/schedules');
      setState(() => _schedules = ApiService.instance.asMaps(list));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final range = currentMonthRange();
      final created = await ApiService.instance.post('/api/me/schedules', {
        'name': range.label,
        'startDate': range.startDate,
        'endDate': range.endDate,
        'staff': [],
        'assignments': [],
      });
      final map = Map<String, dynamic>.from(created as Map);
      setState(() => _schedules = [map, ..._schedules]);
      if (mounted && map['_id'] != null) context.push('/individual/${map['_id']}');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upgrade() async {
    if (_hospitalNameCtrl.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await ApiService.instance.post('/api/auth/upgrade-to-enterprise', {
        'hospitalName': _hospitalNameCtrl.text.trim(),
        'hospitalType': _hospitalType,
        'hospitalRegion': _region,
      });
      await ApiService.instance.loadProfile();
      if (!mounted) return;
      final hid = (data as Map)['hospitalId']?.toString();
      context.go(hid != null ? '/setup' : '/');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    ApiService.instance.clearProfile();
    await AuthService.instance.signOut();
    if (mounted) context.go('/auth/login');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null && _schedules.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('My schedules')),
        body: ErrorView(message: _error!, onRetry: _bootstrap),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My schedules'),
        actions: [
          TextButton(
            onPressed: () => setState(() => _showUpgrade = !_showUpgrade),
            child: Text(_showUpgrade ? 'Cancel' : 'Upgrade', style: const TextStyle(color: Colors.white)),
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _signOut),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Personal monthly rosters — up to 50 staff. Upgrade anytime for a full hospital account.',
            style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w500),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600)),
          ],
          if (_showUpgrade) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('Upgrade to hospital', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _hospitalNameCtrl,
                    decoration: const InputDecoration(labelText: 'Hospital name'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _hospitalType,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: hospitalTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setState(() => _hospitalType = v!),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _region,
                    decoration: const InputDecoration(labelText: 'Region'),
                    items: ghanaRegions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (v) => setState(() => _region = v!),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy ? null : _upgrade,
                    child: Text(_busy ? 'Upgrading…' : 'Create hospital account'),
                  ),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _create,
            icon: const Icon(Icons.add),
            label: Text(_busy ? 'Creating…' : 'New month roster'),
          ),
          const SizedBox(height: 16),
          if (_schedules.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: EmptyState(
                icon: Icons.calendar_month_outlined,
                message: 'No schedules yet. Create one or import a roster after opening it.',
              ),
            )
          else
            for (final s in _schedules)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(s['name']?.toString() ?? 'Roster', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(formatRange(s['startDate'], s['endDate'])),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/individual/${s['_id']}'),
                ),
              ),
        ],
      ),
    );
  }
}
