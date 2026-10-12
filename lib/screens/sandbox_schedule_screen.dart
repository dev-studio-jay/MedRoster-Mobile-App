import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../util/dates.dart';
import '../util/ghana_data.dart';
import '../util/roster_export.dart';
import '../util/roster_setup.dart';
import '../util/sandbox_roster.dart';
import '../widgets/rules_sheet.dart';

/// Shared guest / individual roster editor (port of SandboxScheduleShell).
class SandboxScheduleScreen extends StatefulWidget {
  final String mode; // 'guest' | 'individual'
  final Map<String, dynamic> schedule;
  final ValueChanged<Map<String, dynamic>> onChange;
  final String title;
  final String? subtitle;
  final String backLabel;
  final VoidCallback onBack;
  final Widget? banner;
  final Future<void> Function(String format)? onExport;
  final bool exporting;
  final int maxStaff;
  final Widget? extraActions;
  final bool saving;

  const SandboxScheduleScreen({
    super.key,
    required this.mode,
    required this.schedule,
    required this.onChange,
    required this.onBack,
    this.title = 'Roster',
    this.subtitle,
    this.backLabel = 'Back',
    this.banner,
    this.onExport,
    this.exporting = false,
    this.maxStaff = 50,
    this.extraActions,
    this.saving = false,
  });

  @override
  State<SandboxScheduleScreen> createState() => _SandboxScheduleScreenState();
}

class _SandboxScheduleScreenState extends State<SandboxScheduleScreen> {
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  String _rank = 'Staff Nurse';
  bool _generating = false;
  String? _toast;

  List<Map<String, dynamic>> get _shiftTypes => sandboxShiftTypes();
  List<Map<String, dynamic>> get _staff =>
      (_schedule['staff'] as List?)?.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
  List<Map<String, dynamic>> get _assignments =>
      (_schedule['assignments'] as List?)?.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
  Map<String, dynamic> get _schedule => widget.schedule;

  void _patch(Map<String, dynamic> partial) {
    widget.onChange({..._schedule, ...partial});
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    super.dispose();
  }

  Future<void> _openImport() async {
    final result = await context.push<Map<String, dynamic>>(
      '/sandbox-import/${widget.mode}',
      extra: _schedule['rosterSetup'],
    );
    if (result == null || !mounted) return;
    final incoming = (result['staff'] as List?)?.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    final existingIds = _staff.map((s) => s['_id'].toString()).toSet();
    final mergedStaff = [..._staff];
    for (final s in incoming) {
      final id = s['_id'].toString();
      if (existingIds.contains(id)) {
        final idx = mergedStaff.indexWhere((x) => x['_id'].toString() == id);
        if (idx >= 0) mergedStaff[idx] = {...mergedStaff[idx], ...s};
      } else {
        mergedStaff.add(s);
      }
    }
    if (mergedStaff.length > widget.maxStaff) {
      setState(() => _toast = 'Limited to ${widget.maxStaff} staff.');
      mergedStaff.removeRange(widget.maxStaff, mergedStaff.length);
    }
    final newAssignments = (result['assignments'] as List?)?.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    final kept = _assignments.where((a) => mergedStaff.any((s) => s['_id'].toString() == a['staffId'].toString())).toList();
    final byKey = <String, Map<String, dynamic>>{
      for (final a in kept) '${a['staffId']}_${dateKeyAny(a['date'])}': a,
    };
    for (final a in newAssignments) {
      byKey['${a['staffId']}_${dateKeyAny(a['date'])}'] = a;
    }
    _patch({
      'staff': mergedStaff,
      'assignments': byKey.values.toList(),
      if (result['rosterSetup'] != null) 'rosterSetup': result['rosterSetup'],
    });
    setState(() => _toast = 'Imported ${incoming.length} staff');
  }

  void _addStaff() {
    if (_firstCtrl.text.trim().isEmpty || _lastCtrl.text.trim().isEmpty) return;
    if (_staff.length >= widget.maxStaff) {
      setState(() => _toast = 'Limited to ${widget.maxStaff} staff.');
      return;
    }
    _patch({
      'staff': [
        ..._staff,
        {
          '_id': '${widget.mode}_${DateTime.now().millisecondsSinceEpoch}',
          'firstName': _firstCtrl.text.trim(),
          'lastName': _lastCtrl.text.trim(),
          'rank': _rank,
          'wardRole': 'regular',
        },
      ],
    });
    _firstCtrl.clear();
    _lastCtrl.clear();
  }

  void _removeStaff(String id) {
    _patch({
      'staff': _staff.where((s) => s['_id'].toString() != id).toList(),
      'assignments': _assignments.where((a) => a['staffId'].toString() != id).toList(),
    });
  }

  Future<void> _pickShift(Map<String, dynamic> person, DateTime date) async {
    final dk = dateKey(date);
    Map<String, dynamic>? existing;
    for (final a in _assignments) {
      if (a['staffId'].toString() == person['_id'].toString() && dateKeyAny(a['date']) == dk) {
        existing = a;
        break;
      }
    }
    final currentName = existing?['shiftType'] is Map ? (existing!['shiftType'] as Map)['name']?.toString() : null;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('${person['firstName']} ${person['lastName']}'),
              subtitle: Text('${weekdayShort(date)} ${dayNum(date)}'),
            ),
            for (final st in _shiftTypes)
              ListTile(
                title: Text(st['name']?.toString() ?? ''),
                subtitle: Text('${st['startTime']} – ${st['endTime']}'),
                selected: currentName == st['name'],
                onTap: () {
                  Navigator.pop(ctx);
                  _assign(person, date, st);
                },
              ),
            ListTile(
              title: const Text('Clear shift'),
              onTap: () {
                Navigator.pop(ctx);
                _assign(person, date, null);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _assign(Map person, DateTime date, Map? shift) {
    final dk = dateKey(date);
    final without = _assignments
        .where((a) => !(a['staffId'].toString() == person['_id'].toString() && dateKeyAny(a['date']) == dk))
        .toList();
    if (shift == null) {
      _patch({'assignments': without});
      return;
    }
    final sourceCode = preferredSourceCode(shift['name'].toString(), _schedule['rosterSetup'] is Map ? (_schedule['rosterSetup'] as Map)['legend'] as List? : null);
    _patch({
      'assignments': [
        ...without,
        {
          '_id': 'a_${person['_id']}_$dk',
          'staffId': person['_id'],
          'date': '${dk}T00:00:00.000Z',
          if (sourceCode.isNotEmpty) 'sourceCode': sourceCode,
          'shiftType': {
            'name': shift['name'],
            'color': shift['color'],
            'startTime': shift['startTime'],
            'endTime': shift['endTime'],
          },
        },
      ],
    });
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final next = generateSandboxAssignments(
        staff: _staff,
        startDate: _schedule['startDate'],
        endDate: _schedule['endDate'],
        existing: _assignments,
        holidays: _schedule['holidays'] as List? ?? [],
        rosterSetup: _schedule['rosterSetup'] is Map ? _schedule['rosterSetup'] as Map : null,
      );
      final added = next.length - _assignments.length;
      _patch({'assignments': next});
      setState(() => _toast = added > 0 ? 'Filled $added cover slots' : 'No empty cover slots to fill');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _openExport() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Export', style: TextStyle(fontWeight: FontWeight.w800))),
            for (final f in ['pdf', 'xlsx', 'csv'])
              ListTile(
                title: Text(f.toUpperCase()),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onExport?.call(f);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _clearMenu() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear'),
        content: const Text('What should we clear?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'shifts'), child: const Text('Shifts only')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'all'), child: const Text('Setup, shifts & staff')),
        ],
      ),
    );
    if (choice == 'shifts') {
      _patch({'assignments': []});
      setState(() => _toast = 'Cleared shifts');
    } else if (choice == 'all') {
      _patch({'assignments': [], 'staff': [], 'rosterSetup': null});
      setState(() => _toast = 'Clean slate');
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = buildCycle(_schedule['startDate'], _schedule['endDate']);
    final lookup = <String, Map>{
      for (final a in _assignments) '${a['staffId']}_${dateKeyAny(a['date'])}': a,
    };
    final fillable = countGeneratableSlots(
      staff: _staff,
      startDate: _schedule['startDate'],
      endDate: _schedule['endDate'],
      existing: _assignments,
      holidays: _schedule['holidays'] as List? ?? [],
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            if (widget.subtitle != null)
              Text(widget.subtitle!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          if (widget.saving)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
            ),
          IconButton(icon: const Icon(Icons.rule), tooltip: 'Rules', onPressed: () => showRulesSheet(context)),
          if (widget.onExport != null)
            IconButton(
              icon: widget.exporting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.ios_share_outlined),
              onPressed: widget.exporting ? null : _openExport,
            ),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: _clearMenu),
        ],
      ),
      body: Column(
        children: [
          if (widget.banner != null) widget.banner!,
          if (_toast != null)
            MaterialBanner(
              content: Text(_toast!),
              actions: [TextButton(onPressed: () => setState(() => _toast = null), child: const Text('OK'))],
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              formatRange(_schedule['startDate'], _schedule['endDate']),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (widget.extraActions != null) widget.extraActions!,
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: _openImport,
                  child: const Text('Import'),
                ),
                FilledButton(
                  onPressed: _generating || fillable == 0 ? null : _generate,
                  child: Text(_generating ? 'Generating…' : 'Generate${fillable > 0 ? ' ($fillable)' : ''}'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _firstCtrl,
                  decoration: const InputDecoration(hintText: 'First', isDense: true),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _lastCtrl,
                  decoration: const InputDecoration(hintText: 'Last', isDense: true),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 120,
                child: DropdownButtonFormField<String>(
                  initialValue: ranksForCategory('Nurse').contains(_rank) ? _rank : 'Staff Nurse',
                  isDense: true,
                  decoration: const InputDecoration(isDense: true),
                  items: ranksForCategory('Nurse').take(6).map((r) => DropdownMenuItem(value: r, child: Text(r, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) => setState(() => _rank = v ?? _rank),
                ),
              ),
              IconButton(onPressed: _addStaff, icon: const Icon(Icons.person_add_alt_1)),
            ]),
          ),
          if (_staff.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                children: [
                  for (final s in _staff)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InputChip(
                        label: Text('${s['firstName']} ${s['lastName']}', style: const TextStyle(fontSize: 12)),
                        onDeleted: () => _removeStaff(s['_id'].toString()),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: _staff.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Add staff or import a roster to start assigning shifts.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w500),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowHeight: 48,
                        dataRowMinHeight: 40,
                        dataRowMaxHeight: 48,
                        columns: [
                          const DataColumn(label: Text('Staff')),
                          for (final d in days)
                            DataColumn(
                              label: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(weekdayShort(d), style: const TextStyle(fontSize: 10)),
                                  Text(dayNum(d), style: const TextStyle(fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                        ],
                        rows: [
                          for (final person in _staff)
                            DataRow(cells: [
                              DataCell(SizedBox(
                                width: 110,
                                child: Text('${person['firstName'] ?? ''} ${person['lastName'] ?? ''}', overflow: TextOverflow.ellipsis),
                              )),
                              for (final d in days)
                                DataCell(
                                  _cell(person, d, lookup['${person['_id']}_${dateKey(d)}']),
                                  onTap: () => _pickShift(person, d),
                                ),
                            ]),
                        ],
                      ),
                    ),
                  ),
          ),
          TextButton(onPressed: widget.onBack, child: Text(widget.backLabel)),
        ],
      ),
    );
  }

  Widget _cell(Map person, DateTime date, Map? assignment) {
    if (leaveCovers(Map<String, dynamic>.from(person), date)) {
      return const Text('L', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w700));
    }
    final name = assignment?['shiftType'] is Map ? (assignment!['shiftType'] as Map)['name']?.toString() ?? '' : '';
    final code = assignment?['sourceCode']?.toString();
    if (name.isEmpty && (code == null || code.isEmpty)) {
      return const Text('·', style: TextStyle(color: Colors.black26));
    }
    final label = (code != null && code.isNotEmpty) ? code : _abbr(name);
    return Text(label, style: TextStyle(color: _color(name), fontWeight: FontWeight.w800, fontSize: 11));
  }

  String _abbr(String name) {
    switch (name) {
      case 'Morning':
        return 'M';
      case 'Afternoon':
        return 'A';
      case 'Night':
        return 'N';
      case 'SOD':
        return 'SOD';
      case 'Office':
        return 'OFC';
      default:
        return name.isEmpty ? '' : name[0];
    }
  }

  Color _color(String name) {
    switch (name) {
      case 'Morning':
        return AppColors.green;
      case 'Afternoon':
        return Colors.orange[800]!;
      case 'Night':
        return Colors.indigo;
      case 'Office':
        return AppColors.teal;
      default:
        return const Color(0xFF006B6B);
    }
  }
}

/// Shared export helper for sandbox schedules.
Future<void> exportSandboxSchedule(Map schedule, {required String format, String hospitalLabel = 'MedRoster'}) async {
  final model = buildRosterExportModel(
    schedule: schedule,
    hospital: {'name': hospitalLabel},
    ward: {'name': schedule['wardName'] ?? schedule['name'] ?? 'Roster'},
    staff: schedule['staff'] as List? ?? [],
    assignments: schedule['assignments'] as List? ?? [],
    rosterSetup: schedule['rosterSetup'] is Map ? Map<String, dynamic>.from(schedule['rosterSetup'] as Map) : null,
  );
  if (format == 'csv') {
    await shareRosterCsv(model);
  } else if (format == 'xlsx') {
    await shareRosterExcel(model);
  } else {
    await shareRosterPdf(model);
  }
}
