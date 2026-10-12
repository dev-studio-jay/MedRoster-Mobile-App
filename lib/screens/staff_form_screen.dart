import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../util/dates.dart';
import '../util/ghana_data.dart';

const _leaveTypes = [
  'Annual',
  'Sick',
  'Maternity',
  'Paternity',
  'Study',
  'Compassionate',
  'Casual',
  'Unpaid',
];

class StaffFormScreen extends StatefulWidget {
  final String hospitalId;
  final List<Map<String, dynamic>> departments;
  final List<Map<String, dynamic>> wards;
  final Map<String, dynamic>? staff;
  final String? defaultDepartmentId;
  final String? defaultWardId;

  const StaffFormScreen({
    super.key,
    required this.hospitalId,
    required this.departments,
    required this.wards,
    this.staff,
    this.defaultDepartmentId,
    this.defaultWardId,
  });

  @override
  State<StaffFormScreen> createState() => _StaffFormScreenState();
}

class _StaffFormScreenState extends State<StaffFormScreen> {
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  String _category = 'Nurse';
  String _rank = 'Staff Nurse';
  String _wardRole = 'regular';
  String? _departmentId;
  String? _wardId;
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>> _leave = [];

  bool get _isEdit => widget.staff != null;

  @override
  void initState() {
    super.initState();
    final s = widget.staff;
    _firstCtrl.text = s?['firstName']?.toString() ?? '';
    _lastCtrl.text = s?['lastName']?.toString() ?? '';
    _category = s?['category']?.toString().isNotEmpty == true ? s!['category'].toString() : 'Nurse';
    final savedRank = s?['rank']?.toString() ?? '';
    final available = ranksForCategory(_category);
    _rank = savedRank.isNotEmpty
        ? savedRank
        : (available.isNotEmpty ? available.first : '');
    _wardRole = s?['wardRole']?.toString() ?? 'regular';
    _departmentId = s?['departmentId']?.toString() ?? widget.defaultDepartmentId;
    _wardId = s?['wardId']?.toString() ?? widget.defaultWardId;
    if (s?['leaveRecords'] is List) {
      _leave = ApiService.instance.asMaps(s!['leaveRecords']);
    }
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_firstCtrl.text.trim().isEmpty || _lastCtrl.text.trim().isEmpty) {
      setState(() => _error = 'First and last name are required');
      return;
    }
    if (_departmentId == null || _wardId == null) {
      setState(() => _error = 'Department and ward are required');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final payload = {
      'firstName': _firstCtrl.text.trim(),
      'lastName': _lastCtrl.text.trim(),
      'category': _category,
      'rank': _rank,
      'departmentId': _departmentId,
      'wardId': _wardId,
      'wardRole': _wardRole,
    };
    try {
      if (_isEdit) {
        await ApiService.instance.patch(
          '/api/hospitals/${widget.hospitalId}/staff/${widget.staff!['_id']}',
          payload,
        );
      } else {
        await ApiService.instance.post('/api/hospitals/${widget.hospitalId}/staff', payload);
      }
      if (mounted) {
        if (context.canPop()) {
          context.pop(true);
        } else {
          context.go('/ward/$_wardId');
        }
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addLeave() async {
    final staffId = widget.staff?['_id']?.toString();
    if (staffId == null) return;
    DateTimeRange? range;
    String leaveType = 'Annual';
    final picked = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        DateTime start = DateTime.now();
        DateTime end = DateTime.now();
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: const Text('Add leave'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: leaveType,
                items: _leaveTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => leaveType = v ?? leaveType,
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('From ${dateKey(start)} to ${dateKey(end)}'),
                trailing: const Icon(Icons.date_range),
                onTap: () async {
                  final next = await showDateRangePicker(
                    context: ctx,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                    initialDateRange: DateTimeRange(start: start, end: end),
                  );
                  if (next != null) {
                    start = next.start;
                    end = next.end;
                    range = next;
                    setLocal(() {});
                  }
                },
              ),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  range ??= DateTimeRange(start: start, end: end);
                  Navigator.pop(ctx, true);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
    if (picked != true) return;
    range ??= DateTimeRange(start: DateTime.now(), end: DateTime.now());
    try {
      await ApiService.instance.post(
        '/api/hospitals/${widget.hospitalId}/staff/$staffId/leave',
        {
          'startDate': dateKey(range!.start),
          'endDate': dateKey(range!.end),
          'leaveType': leaveType,
        },
      );
      final s = await ApiService.instance.get('/api/hospitals/${widget.hospitalId}/staff/$staffId');
      setState(() => _leave = ApiService.instance.asMaps((s as Map)['leaveRecords']));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _removeLeave(String leaveId) async {
    final staffId = widget.staff?['_id']?.toString();
    if (staffId == null) return;
    try {
      await ApiService.instance.delete(
        '/api/hospitals/${widget.hospitalId}/staff/$staffId/leave?leaveId=$leaveId',
      );
      final s = await ApiService.instance.get('/api/hospitals/${widget.hospitalId}/staff/$staffId');
      setState(() => _leave = ApiService.instance.asMaps((s as Map)['leaveRecords']));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ranks = ranksForCategory(_category);
    final rankOptions = [
      if (_rank.isNotEmpty && !ranks.contains(_rank)) _rank,
      ...ranks,
    ];
    final rankValue = rankOptions.contains(_rank)
        ? _rank
        : (rankOptions.isNotEmpty ? rankOptions.first : null);
    final roleValue = wardRoles.any((r) => r.value == _wardRole) ? _wardRole : 'regular';
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit staff' : 'Add staff')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _isEdit ? 'Update profile and leave windows for this person.' : 'Add someone to this ward’s roster.',
            style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          TextField(controller: _firstCtrl, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'First name')),
          const SizedBox(height: 12),
          TextField(controller: _lastCtrl, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Last name')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('category-$_category'),
            initialValue: staffCategories.contains(_category) ? _category : staffCategories.first,
            decoration: const InputDecoration(labelText: 'Category'),
            items: staffCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _category = v;
                final next = ranksForCategory(v);
                _rank = next.contains(_rank) ? _rank : (next.isNotEmpty ? next.first : '');
              });
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('rank-$_category'),
            initialValue: rankValue,
            decoration: const InputDecoration(labelText: 'Rank / grade'),
            items: rankOptions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: (v) => setState(() => _rank = v ?? _rank),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: roleValue,
            decoration: const InputDecoration(labelText: 'Ward role'),
            items: wardRoles
                .map((r) => DropdownMenuItem(value: r.value, child: Text(r.label)))
                .toList(),
            onChanged: (v) => setState(() => _wardRole = v ?? _wardRole),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Save'),
          ),
          if (_isEdit) ...[
            const SizedBox(height: 28),
            Row(children: [
              const Expanded(child: Text('Leave windows', style: TextStyle(fontWeight: FontWeight.w800))),
              TextButton.icon(onPressed: _addLeave, icon: const Icon(Icons.add, size: 18), label: const Text('Add leave')),
            ]),
            Text(
              'Approved leave blocks shift assignment on those days.',
              style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            if (_leave.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No leave recorded.', style: TextStyle(color: AppColors.muted)),
              ),
            for (final rec in _leave)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(rec['leaveType']?.toString() ?? 'Leave', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${dateKeyAny(rec['startDate'])} – ${dateKeyAny(rec['endDate'])}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Remove leave',
                    onPressed: () => _removeLeave((rec['id'] ?? rec['_id']).toString()),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
