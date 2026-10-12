import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../state/hospital_store.dart';
import '../theme/app_theme.dart';
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
  bool _gridView = false;

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
        title: const Text('Remove staff'),
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
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AppColors.teal),
          ),
          Text(ward['name']?.toString() ?? 'Ward', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          Text(
            '${people.length} ${people.length == 1 ? 'staff member' : 'staff'} on this ward.',
            style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w500),
          ),
          if (latest != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Current cycle: ${formatRange(latest['startDate'], latest['endDate'])}',
                style: const TextStyle(color: AppColors.muted, fontSize: 13, fontWeight: FontWeight.w500),
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
                child: const Text('Add staff'),
              ),
            ],
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(hintText: 'Search by name or rank...', prefixIcon: Icon(Icons.search)),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            if (people.isNotEmpty) ...[
              const SizedBox(width: 8),
              _ViewPill(
                gridView: _gridView,
                onChanged: (v) => setState(() => _gridView = v),
              ),
            ],
          ]),
          const SizedBox(height: 12),
          if (people.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: EmptyState(
                icon: Icons.people_outline,
                message: _canWrite
                    ? 'Import a duty roster or add staff, then open the calendar to edit shifts.'
                    : 'No staff have been assigned to this ward.',
                actionLabel: _canWrite ? 'Add staff' : null,
                onAction: _canWrite ? () => _openStaffForm() : null,
              ),
            )
          else if (_gridView)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: people.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.95,
              ),
              itemBuilder: (context, i) => _StaffGridCard(
                staff: people[i],
                canWrite: _canWrite,
                badge: _badge(people[i]),
                onEdit: () => _openStaffForm(staff: people[i]),
                onDelete: () => _deleteStaff(people[i]),
              ),
            )
          else
            ...people.map((s) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(_initials(s)),
                    ),
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

  String _initials(Map<String, dynamic> s) {
    final a = (s['firstName']?.toString() ?? '').trim();
    final b = (s['lastName']?.toString() ?? '').trim();
    return '${a.isNotEmpty ? a[0] : ''}${b.isNotEmpty ? b[0] : ''}'.toUpperCase();
  }
}

class _ViewPill extends StatelessWidget {
  final bool gridView;
  final ValueChanged<bool> onChanged;

  const _ViewPill({required this.gridView, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 1))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pillIcon(
            selected: !gridView,
            tooltip: 'List',
            onTap: () => onChanged(false),
            icon: Icons.menu,
          ),
          _pillIcon(
            selected: gridView,
            tooltip: 'Grid',
            onTap: () => onChanged(true),
            icon: Icons.grid_view_rounded,
          ),
        ],
      ),
    );
  }

  Widget _pillIcon({
    required bool selected,
    required String tooltip,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    const green = Color(0xFF006B3F);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected ? green : Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(icon, size: 18, color: selected ? Colors.white : const Color(0xFF94A3B8)),
          ),
        ),
      ),
    );
  }
}

class _StaffGridCard extends StatelessWidget {
  final Map<String, dynamic> staff;
  final bool canWrite;
  final Widget? badge;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StaffGridCard({
    required this.staff,
    required this.canWrite,
    required this.badge,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final first = staff['firstName']?.toString() ?? '';
    final last = staff['lastName']?.toString() ?? '';
    final initials = '${first.isNotEmpty ? first[0] : ''}${last.isNotEmpty ? last[0] : ''}'.toUpperCase();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(radius: 18, child: Text(initials, style: const TextStyle(fontSize: 12))),
              const Spacer(),
              if (badge != null) badge!,
            ]),
            const SizedBox(height: 10),
            Text('$first $last', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(
              staff['rank']?.toString() ?? staff['category']?.toString() ?? 'Staff',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Spacer(),
            if (canWrite)
              Row(children: [
                TextButton(onPressed: onEdit, child: const Text('Edit')),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: onDelete,
                ),
              ]),
          ],
        ),
      ),
    );
  }
}
