import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../state/hospital_store.dart';
import '../util/dates.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_view.dart';
import 'staff_form_screen.dart';

class WardHomeScreen extends StatefulWidget {
  final String wardId;
  const WardHomeScreen({super.key, required this.wardId});

  @override
  State<WardHomeScreen> createState() => _WardHomeScreenState();
}

class _WardHomeScreenState extends State<WardHomeScreen> {
  List<Map<String, dynamic>> _staff = [];
  List<Map<String, dynamic>> _schedules = [];
  bool _loading = true;
  bool _busyRoster = false;
  String? _error;
  String _search = '';

  String? get _hid => HospitalStore.instance.hospitalId;
  bool get _canWrite => ApiService.instance.canWrite;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant WardHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wardId != widget.wardId) _load();
  }

  Future<void> _load() async {
    final hid = _hid;
    if (hid == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ApiService.instance;
      final results = await Future.wait([
        api.get('/api/hospitals/$hid/staff'),
        api.get('/api/hospitals/$hid/schedules'),
      ]);
      setState(() {
        _staff = api.asMaps(results[0]);
        _schedules = api.asMaps(results[1]);
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _wardStaff {
    final q = _search.trim().toLowerCase();
    return _staff.where((s) {
      if (s['wardId']?.toString() != widget.wardId) return false;
      if (q.isEmpty) return true;
      final name = '${s['firstName'] ?? ''} ${s['lastName'] ?? ''}'.toLowerCase();
      return name.contains(q) || (s['rank']?.toString().toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Map<String, dynamic>? get _latestSchedule {
    final list = _schedules.where((s) => s['wardId']?.toString() == widget.wardId).toList()
      ..sort((a, b) => (b['startDate'] ?? '').toString().compareTo((a['startDate'] ?? '').toString()));
    return list.isEmpty ? null : list.first;
  }

  Future<void> _makeThisMonth(Map<String, dynamic> ward) async {
    final hid = _hid;
    if (hid == null) return;
    setState(() {
      _busyRoster = true;
      _error = null;
    });
    final range = currentMonthRange();
    try {
      final data = await ApiService.instance.post('/api/hospitals/$hid/schedules', {
        'wardId': ward['_id'],
        'startDate': range.startDate,
        'endDate': range.endDate,
        'name': '${ward['name']} · ${range.label}',
      });
      final id = (data as Map)['_id']?.toString();
      if (id != null && mounted) context.push('/schedule/$id');
    } on ApiException catch (e) {
      final existing = e.data?['scheduleId']?.toString();
      if (e.statusCode == 409 && existing != null && mounted) {
        context.push('/schedule/$existing');
      } else {
        setState(() => _error = e.message);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busyRoster = false);
    }
  }

  Future<void> _deleteStaff(Map<String, dynamic> s) async {
    final hid = _hid;
    if (hid == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove person'),
        content: Text('Remove ${s['firstName']} ${s['lastName']}? Their assignments will also be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.instance.delete('/api/hospitals/$hid/staff/${s['_id']}');
      await _load();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _openStaffForm({Map<String, dynamic>? staff}) async {
    final store = HospitalStore.instance;
    final ward = store.wardById(widget.wardId);
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StaffFormScreen(
          hospitalId: _hid!,
          departments: store.departments,
          wards: store.wards,
          staff: staff,
          defaultDepartmentId: ward?['departmentId']?.toString() ?? store.departments.first['_id']?.toString(),
          defaultWardId: widget.wardId,
        ),
      ),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final store = HospitalStore.instance;
    final ward = store.wardById(widget.wardId);
    if (ward == null) {
      return const Center(child: Text('Ward not found'));
    }
    final dept = store.departmentById(ward['departmentId']?.toString());
    final latest = _latestSchedule;
    final people = _wardStaff;

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && people.isEmpty && latest == null) {
      return ErrorView(message: _error!, onRetry: _load);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            (dept?['name'] ?? 'Department').toString().toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: Colors.grey),
          ),
          Text(ward['name']?.toString() ?? 'Ward', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          Text('${people.length} ${people.length == 1 ? 'person' : 'people'} on this ward.'),
          if (latest != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Current cycle: ${formatRange(latest['startDate'], latest['endDate'])}',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (latest != null)
              FilledButton(
                onPressed: () => context.push('/schedule/${latest['_id']}'),
                child: const Text('Open roster'),
              )
            else if (_canWrite)
              FilledButton(
                onPressed: _busyRoster ? null : () => _makeThisMonth(ward),
                child: Text(_busyRoster ? 'Creating…' : 'Make this month’s roster'),
              ),
            if (_canWrite) ...[
              OutlinedButton(
                onPressed: () => context.push('/import/${widget.wardId}'),
                child: const Text('Import roster'),
              ),
              OutlinedButton(
                onPressed: () => _openStaffForm(),
                child: const Text('Add person'),
              ),
            ],
          ]),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(hintText: 'Search by name or rank...', prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() => _search = v),
          ),
          const SizedBox(height: 12),
          if (people.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: EmptyState(
                icon: Icons.people_outline,
                message: _canWrite
                    ? 'Import a duty roster or add people, then open the calendar to edit shifts.'
                    : 'No staff have been assigned to this ward.',
                actionLabel: _canWrite ? 'Add person' : null,
                onAction: _canWrite ? () => _openStaffForm() : null,
              ),
            )
          else
            ...people.map((s) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text('${s['firstName'] ?? ''} ${s['lastName'] ?? ''}'),
                    subtitle: Text(s['rank']?.toString() ?? s['category']?.toString() ?? 'Staff'),
                    trailing: _canWrite
                        ? Row(mainAxisSize: MainAxisSize.min, children: [
                            TextButton(onPressed: () => _openStaffForm(staff: s), child: const Text('Edit')),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deleteStaff(s),
                            ),
                          ])
                        : _badge(s),
                  ),
                )),
        ],
      ),
    );
  }

  Widget? _badge(Map<String, dynamic> s) {
    final type = s['staffType']?.toString();
    if (type == 'pno') return const Chip(label: Text('PNO+'), visualDensity: VisualDensity.compact);
    if (type == 'senior') return const Chip(label: Text('SENIOR'), visualDensity: VisualDensity.compact);
    return null;
  }
}
