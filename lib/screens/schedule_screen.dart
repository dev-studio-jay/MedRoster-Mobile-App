import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../state/hospital_store.dart';
import '../theme/app_theme.dart';
import '../util/dates.dart';
import '../util/roster_export.dart';
import '../util/rule_modes.dart';
import '../widgets/error_view.dart';
import '../widgets/rule_modes_panel.dart';
import '../widgets/rules_sheet.dart';

class ScheduleScreen extends StatefulWidget {
  final String scheduleId;
  const ScheduleScreen({super.key, required this.scheduleId});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _generating = false;
  bool _usePreferences = false;
  String? _error;
  String? _toast;
  Map<String, dynamic>? _validation;

  String? get _hid => HospitalStore.instance.hospitalId ?? ApiService.instance.hospitalId;
  bool get _canWrite => ApiService.instance.canWrite;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final hid = _hid;
    if (hid == null) return;
    setState(() {
      _loading = _data == null;
      _error = null;
    });
    try {
      final data = await ApiService.instance.get('/api/hospitals/$hid/schedules/${widget.scheduleId}');
      setState(() => _data = Map<String, dynamic>.from(data as Map));
      await _validate();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _validate() async {
    final hid = _hid;
    if (hid == null) return;
    try {
      final data = await ApiService.instance.post(
        '/api/hospitals/$hid/schedules/${widget.scheduleId}/validate',
        {},
      );
      if (mounted) setState(() => _validation = Map<String, dynamic>.from(data as Map));
    } catch (_) {
      // checker is best-effort
    }
  }

  List<Map<String, dynamic>> get _staff => ApiService.instance.asMaps(_data?['staff']);
  List<Map<String, dynamic>> get _assignments => ApiService.instance.asMaps(_data?['assignments']);
  Map<String, dynamic> get _schedule => Map<String, dynamic>.from(_data?['schedule'] as Map? ?? {});
  Map<String, dynamic> get _hospital => Map<String, dynamic>.from(_data?['hospital'] as Map? ?? {});
  List<Map<String, dynamic>> get _shiftTypes => ApiService.instance.asMaps(_hospital['shiftTypes']);

  String _shiftId(Map<String, dynamic> st) =>
      (st['id'] ?? st['_id'] ?? st['name'])?.toString() ?? '';

  Map<String, Map<String, dynamic>> get _assignmentLookup {
    final map = <String, Map<String, dynamic>>{};
    for (final a in _assignments) {
      map['${a['staffId']}_${dateKeyAny(a['date'])}'] = a;
    }
    return map;
  }

  Future<void> _assign({
    required Map<String, dynamic> staff,
    required DateTime date,
    required String? shiftTypeId,
  }) async {
    final hid = _hid;
    if (hid == null) return;
    try {
      final result = await ApiService.instance.post(
        '/api/hospitals/$hid/schedules/${widget.scheduleId}/assignments',
        {
          'staffId': staff['_id'],
          'date': date.toIso8601String(),
          'shiftTypeId': shiftTypeId,
        },
      );
      await _load();
      final warnings = (result is Map && result['warnings'] is List)
          ? (result['warnings'] as List).join('; ')
          : '';
      setState(() => _toast = warnings.isNotEmpty ? warnings : (shiftTypeId == null ? 'Shift cleared' : 'Shift assigned'));
    } on ApiException catch (e) {
      final errors = e.data?['errors'];
      setState(() => _toast = errors is List ? errors.join('; ') : e.message);
    }
  }

  Future<void> _generate() async {
    final hid = _hid;
    if (hid == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Auto-generate'),
        content: const Text('Auto-generate will replace existing assignments. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Generate')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _generating = true);
    try {
      final result = await ApiService.instance.post(
        '/api/hospitals/$hid/schedules/${widget.scheduleId}/generate',
        {'usePreferences': _usePreferences},
        timeout: const Duration(seconds: 90),
      );
      await _load();
      final created = (result as Map)['assignmentsCreated'];
      final considered = result['staffConsidered'];
      setState(() => _toast = 'Generated $created assignments across $considered staff');
    } on ApiException catch (e) {
      setState(() => _toast = e.message);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _pickShift(Map<String, dynamic> staff, DateTime date) async {
    if (!_canWrite) return;
    final existing = _assignmentLookup['${staff['_id']}_${dateKey(date)}'];
    final currentName = existing?['shiftType'] is Map
        ? (existing!['shiftType'] as Map)['name']?.toString()
        : null;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('${staff['firstName']} ${staff['lastName']}'),
                subtitle: Text('${weekdayShort(date)} ${dayNum(date)}'),
              ),
              for (final st in _shiftTypes)
                ListTile(
                  title: Text(st['name']?.toString() ?? ''),
                  subtitle: Text('${st['startTime'] ?? ''} – ${st['endTime'] ?? ''}'),
                  selected: currentName == st['name']?.toString(),
                  onTap: () {
                    Navigator.pop(ctx);
                    _assign(staff: staff, date: date, shiftTypeId: _shiftId(st));
                  },
                ),
              ListTile(
                title: const Text('Clear shift'),
                onTap: () {
                  Navigator.pop(ctx);
                  _assign(staff: staff, date: date, shiftTypeId: null);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openSettings() async {
    final settings = Map<String, dynamic>.from(_hospital['settings'] as Map? ?? {});
    final saved = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _SettingsDialog(settings: settings),
    );
    if (saved == null || _hid == null) return;
    try {
      await ApiService.instance.patch('/api/hospitals/$_hid', {'settings': saved});
      await _load();
      setState(() => _toast = 'Settings updated');
    } on ApiException catch (e) {
      setState(() => _toast = e.message);
    }
  }

  void _openRules() => showRulesSheet(context);

  Future<void> _export(String format) async {
    try {
      final wardId = _schedule['wardId']?.toString();
      final ward = wardId != null ? HospitalStore.instance.wardById(wardId) : null;
      final model = buildRosterExportModel(
        schedule: _schedule,
        hospital: _hospital,
        ward: ward,
        staff: _staff,
        assignments: _assignments,
        rosterSetup: _schedule['rosterSetup'] is Map
            ? Map<String, dynamic>.from(_schedule['rosterSetup'] as Map)
            : (ward?['rosterSetup'] is Map ? Map<String, dynamic>.from(ward!['rosterSetup'] as Map) : null),
      );
      if (format == 'csv') {
        await shareRosterCsv(model);
      } else if (format == 'xlsx') {
        await shareRosterExcel(model);
      } else {
        await shareRosterPdf(model);
      }
      if (mounted) setState(() => _toast = 'Shared $format export');
    } catch (e) {
      if (mounted) setState(() => _toast = 'Export failed: $e');
    }
  }

  void _openExport() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Export roster', style: TextStyle(fontWeight: FontWeight.w800))),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('PDF'),
              onTap: () {
                Navigator.pop(ctx);
                _export('pdf');
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('Excel (.xlsx)'),
              onTap: () {
                Navigator.pop(ctx);
                _export('xlsx');
              },
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('CSV'),
              onTap: () {
                Navigator.pop(ctx);
                _export('csv');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openIssues() {
    final groups = _groupIssues();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (_, controller) => SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(children: [
                  const Expanded(child: Text('Validation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                  TextButton(onPressed: () { Navigator.pop(ctx); _validate(); }, child: const Text('Re-check')),
                ]),
              ),
              if (groups.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No issues found. Roster looks good.', style: TextStyle(fontWeight: FontWeight.w600)),
                )
              else
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: groups.length,
                    itemBuilder: (_, i) {
                      final g = groups[i];
                      return ListTile(
                        leading: Icon(Icons.warning_amber_rounded, color: Colors.orange[800]),
                        title: Text(g.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        subtitle: g.detail == null ? null : Text(g.detail!, style: const TextStyle(fontSize: 12)),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _data == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorView(message: _error ?? 'Schedule not found', onRetry: _load),
      );
    }

    final days = buildCycle(_schedule['startDate'], _schedule['endDate']);
    final lookup = _assignmentLookup;
    final wardId = _schedule['wardId']?.toString();
    final groups = _groupIssues();

    return Scaffold(
      appBar: AppBar(
        title: Text(_schedule['name']?.toString() ?? 'Roster'),
        actions: [
          IconButton(icon: const Icon(Icons.ios_share_outlined), tooltip: 'Export', onPressed: _openExport),
          IconButton(icon: const Icon(Icons.rule), tooltip: 'Rules', onPressed: _openRules),
          if (_canWrite)
            IconButton(icon: const Icon(Icons.tune), tooltip: 'Settings', onPressed: _openSettings),
        ],
      ),
      body: Column(
        children: [
          if (_toast != null)
            MaterialBanner(
              content: Text(_toast!),
              actions: [TextButton(onPressed: () => setState(() => _toast = null), child: const Text('OK'))],
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              formatRange(_schedule['startDate'], _schedule['endDate']),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (_canWrite)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                Expanded(
                  child: CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Use preferences'),
                    value: _usePreferences,
                    onChanged: (v) => setState(() => _usePreferences = v ?? false),
                  ),
                ),
                FilledButton(
                  onPressed: _generating ? null : _generate,
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  child: Text(_generating ? 'Generating…' : 'Generate'),
                ),
              ]),
            ),
          if (groups.isNotEmpty)
            Material(
              color: Colors.orange.shade50,
              child: InkWell(
                onTap: _openIssues,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange[800], size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${groups.length} validation issue${groups.length == 1 ? '' : 's'} — tap to review',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.orange[900]),
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 20),
                  ]),
                ),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
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
                  rows: _staffDataRows(days, lookup),
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: () => context.go(wardId != null ? '/ward/$wardId' : '/'),
            child: const Text('Back to ward'),
          ),
        ],
      ),
    );
  }

  List<DataRow> _staffDataRows(List<DateTime> days, Map<String, Map<String, dynamic>> lookup) {
    final parts = partitionStaffForRoster(_staff, _schedule['startDate'], _schedule['endDate']);
    final rows = <DataRow>[];

    DataRow personRow(Map<String, dynamic> staff) {
      return DataRow(cells: [
        DataCell(SizedBox(
          width: 110,
          child: Text(
            '${staff['firstName'] ?? ''} ${staff['lastName'] ?? ''}',
            overflow: TextOverflow.ellipsis,
          ),
        )),
        for (final d in days)
          DataCell(
            _cell(staff, d, lookup['${staff['_id']}_${dateKey(d)}']),
            onTap: () => _pickShift(staff, d),
          ),
      ]);
    }

    DataRow spacerLabel(String label) {
      return DataRow(
        color: WidgetStatePropertyAll(AppColors.surface),
        cells: [
          DataCell(Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: AppColors.muted))),
          for (final _ in days) const DataCell(SizedBox.shrink()),
        ],
      );
    }

    for (final s in parts.regular) {
      rows.add(personRow(s));
    }
    if (parts.rotation.isNotEmpty) {
      rows.add(spacerLabel('ROTATION'));
      for (final s in parts.rotation) {
        rows.add(personRow(s));
      }
    }
    if (parts.leave.isNotEmpty) {
      rows.add(DataRow(
        cells: [
          const DataCell(SizedBox(height: 8)),
          for (final _ in days) const DataCell(SizedBox.shrink()),
        ],
      ));
      rows.add(spacerLabel('ON LEAVE'));
      for (final s in parts.leave) {
        rows.add(personRow(s));
      }
    }
    return rows;
  }

  Widget _cell(Map<String, dynamic> staff, DateTime date, Map<String, dynamic>? assignment) {
    if (leaveCovers(staff, date)) {
      return const Text('L', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w700));
    }
    final name = assignment?['shiftType'] is Map
        ? (assignment!['shiftType'] as Map)['name']?.toString() ?? ''
        : '';
    if (name.isEmpty) return const Text('·', style: TextStyle(color: Colors.black26));
    return Text(_abbr(name), style: TextStyle(color: _shiftColor(name), fontWeight: FontWeight.w800));
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

  Color _shiftColor(String name) {
    switch (name) {
      case 'Morning':
        return AppColors.green;
      case 'Afternoon':
        return Colors.orange[800]!;
      case 'Night':
        return Colors.indigo;
      case 'Office':
        return AppColors.teal;
      case 'SOD':
        return const Color(0xFF006B6B);
      default:
        return Colors.purple;
    }
  }

  List<_IssueGroup> _groupIssues() {
    final errors = ApiService.instance.asMaps(_validation?['errors']);
    final warnings = ApiService.instance.asMaps(_validation?['warnings']);
    final groups = <String, _IssueGroup>{};
    for (final item in [...errors, ...warnings]) {
      final type = item['type']?.toString() ?? '';
      if (type == 'leave_conflict') {
        final key = 'leave:${item['staffId'] ?? item['staffName']}';
        final g = groups.putIfAbsent(key, () => _IssueGroup(title: item['staffName']?.toString() ?? 'Someone', count: 0));
        g.count += 1;
        g.title = '${item['staffName'] ?? 'Someone'} — ${g.count} shift${g.count == 1 ? '' : 's'} while on leave';
      } else if (type == 'supervisory_coverage') {
        final g = groups.putIfAbsent('coverage', () => _IssueGroup(title: 'Days with no senior / in-charge on Morning', count: 0, dates: []));
        g.count += 1;
        if (item['date'] != null) g.dates.add(item['date'].toString());
        g.title = '${g.count} day${g.count == 1 ? '' : 's'} with no senior / in-charge on Morning';
        g.detail = g.dates.map((d) {
          final dt = parseDate(d);
          return dt == null ? d : '${weekdayShort(dt)} ${dayNum(dt)}';
        }).join(', ');
      } else {
        final key = '$type:${item['staffId'] ?? item['message']}';
        groups.putIfAbsent(
          key,
          () => _IssueGroup(title: item['message']?.toString() ?? item['staffName']?.toString() ?? type, count: 1),
        );
      }
    }
    return groups.values.toList();
  }
}

class _IssueGroup {
  String title;
  int count;
  String? detail;
  List<String> dates;
  _IssueGroup({required this.title, required this.count, List<String>? dates}) : dates = dates ?? [];
}

class _SettingsDialog extends StatefulWidget {
  final Map<String, dynamic> settings;
  const _SettingsDialog({required this.settings});

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late int _days;
  late int _nights;
  late int _seniors;
  late int _hours;
  late Map<String, String> _ruleModes;

  @override
  void initState() {
    super.initState();
    _days = (widget.settings['maxConsecutiveDays'] as num?)?.toInt() ?? 6;
    _nights = (widget.settings['maxConsecutiveNights'] as num?)?.toInt() ?? 3;
    _seniors = (widget.settings['minSeniorStaffPerShift'] as num?)?.toInt() ??
        (widget.settings['minSeniorStaffPerDay'] as num?)?.toInt() ??
        1;
    if (_seniors < 0) _seniors = 0;
    _hours = (widget.settings['maxHoursPerWeek'] as num?)?.toInt() ?? 48;
    _ruleModes = normalizeRuleModes(widget.settings['ruleModes']);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Schedule settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Caps and hours. Leave and personal restrictions stay hard.'),
            _numField('Max consecutive days', _days, 1, 14, (v) => _days = v),
            _numField('Max consecutive nights', _nights, 1, 7, (v) => _nights = v),
            _numField('Min seniors per shift', _seniors, 0, 20, (v) => _seniors = v),
            _numField('Max hours per week', _hours, 20, 80, (v) => _hours = v),
            const SizedBox(height: 12),
            RuleModesPanel(
              modes: _ruleModes,
              onChanged: (m) => setState(() => _ruleModes = m),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, {
            'maxConsecutiveDays': _days,
            'maxConsecutiveNights': _nights,
            'minSeniorStaffPerDay': _seniors,
            'minSeniorStaffPerShift': _seniors,
            'maxHoursPerWeek': _hours,
            'ruleModes': normalizeRuleModes(_ruleModes),
            'validationRules': {
              'enforceLeaveConflicts': true,
              'enforceRoleShiftRestrictions': true,
              'enforceSupervisoryCoverage': true,
              'warnConsecutiveShifts': true,
            },
          }),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _numField(String label, int value, int min, int max, void Function(int) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        Expanded(child: Text(label)),
        SizedBox(
          width: 72,
          child: TextFormField(
            initialValue: value.toString(),
            keyboardType: TextInputType.number,
            onChanged: (v) {
              final n = int.tryParse(v);
              if (n != null) onChanged(n.clamp(min, max));
            },
          ),
        ),
      ]),
    );
  }
}
