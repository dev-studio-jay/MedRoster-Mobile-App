import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../services/api_service.dart';
import '../state/hospital_store.dart';
import '../theme/app_theme.dart';
import '../util/roster_setup.dart';

class ImportRosterScreen extends StatefulWidget {
  final String wardId;
  const ImportRosterScreen({super.key, required this.wardId});

  @override
  State<ImportRosterScreen> createState() => _ImportRosterScreenState();
}

class _ImportRosterScreenState extends State<ImportRosterScreen> {
  String _step = 'chooser';
  String? _path;
  String? _fileName;
  Uint8List? _bytes;
  String? _csvText;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _rawPreview;
  Map<String, dynamic>? _preview;
  Map<String, dynamic>? _result;
  Map<String, dynamic>? _setupDraft;
  bool _leaveStayOff = true;
  bool _offAndHolidayStayOff = true;
  bool _keepGridAsIs = true;

  String? get _hid => HospitalStore.instance.hospitalId ?? ApiService.instance.hospitalId;
  Map<String, dynamic>? get _ward => HospitalStore.instance.wardById(widget.wardId);

  int get _selectedCount => _previewStaff.where((s) => s['selected'] != false).length;

  List<Map<String, dynamic>> get _previewStaff => ApiService.instance.asMaps(_preview?['staff']);

  List<Map<String, dynamic>> get _legendRows =>
      (_setupDraft?['legend'] as List?)?.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() ?? [];

  @override
  void initState() {
    super.initState();
    if (HospitalStore.instance.hospital == null) {
      HospitalStore.instance.load();
    }
  }

  Future<void> _downloadTemplate() async {
    final hid = _hid;
    if (hid == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bytes = await ApiService.instance.getBytes('/api/hospitals/$hid/staff/template/download');
      await SharePlus.instance.share(
        ShareParams(files: [
          XFile.fromData(Uint8List.fromList(bytes), mimeType: 'text/csv', name: 'medroster-staff-template.csv'),
        ]),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not download template');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    setState(() {
      _fileName = file.name;
      _bytes = file.bytes;
      _csvText = file.bytes != null ? utf8.decode(file.bytes!) : null;
      _error = null;
    });
  }

  Future<void> _pickRosterFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    setState(() {
      _fileName = file.name;
      _bytes = file.bytes;
      _error = null;
    });
  }

  Future<void> _pickPhoto() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    setState(() {
      _fileName = image.name;
      _bytes = bytes;
      _error = null;
    });
  }

  void _initSetupFromPreview(Map<String, dynamic> data) {
    final saved = _ward?['rosterSetup'] is Map ? Map<String, dynamic>.from(_ward!['rosterSetup'] as Map) : null;
    final proposal = buildSetupProposal(data, saved);
    final legend = (proposal['legendDraft'] as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    String incharge = saved?['inchargeStaffKey']?.toString() ?? '';
    String assistant = saved?['assistantStaffKey']?.toString() ?? '';
    final roles = (proposal['roleGuesses'] as List).whereType<Map>();
    if (incharge.isEmpty) {
      final guess = roles.cast<Map>().where((r) => r['guessedRole'] == 'incharge');
      if (guess.isNotEmpty) incharge = guess.first['key']?.toString() ?? '';
    }
    setState(() {
      _rawPreview = data;
      _setupDraft = {
        'legend': legend,
        'inchargeStaffKey': incharge,
        'assistantStaffKey': assistant,
        'leaveByKey': <String, dynamic>{},
        'units': <String, dynamic>{},
      };
      _preview = data;
      _step = data['source'] == 'roster' && legend.isNotEmpty ? 'setup' : 'review';
    });
  }

  void _applySetupAndReview() {
    if (_rawPreview == null || _setupDraft == null) return;
    final payload = buildRosterSetupPayload(_setupDraft!);
    final remapped = applyRosterSetup(_rawPreview!, {
      ...payload,
      'leaveByKey': _setupDraft!['leaveByKey'] ?? {},
    });
    setState(() {
      _preview = remapped;
      _setupDraft = {..._setupDraft!, ...payload};
      _step = 'review';
      _error = null;
    });
  }

  Future<void> _readFile() async {
    final hid = _hid;
    if (hid == null) return;
    if (_path == 'csv' && (_csvText == null || _csvText!.isEmpty)) {
      setState(() => _error = 'Choose a file first');
      return;
    }
    if (_path != 'csv' && (_bytes == null || _bytes!.isEmpty)) {
      setState(() => _error = 'Choose a file first');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      Map<String, dynamic> data;
      if (_path == 'csv') {
        data = Map<String, dynamic>.from(
          await ApiService.instance.post('/api/hospitals/$hid/staff/parse-csv', {'csvText': _csvText}) as Map,
        );
      } else {
        data = Map<String, dynamic>.from(
          await ApiService.instance.post(
            '/api/hospitals/$hid/staff/extract',
            {
              'fileBase64': base64Encode(_bytes!),
              'fileName': _fileName ?? 'roster',
            },
            timeout: const Duration(seconds: 120),
          ) as Map,
        );
      }
      final staff = ApiService.instance.asMaps(data['staff']).asMap().entries.map((e) {
        final s = Map<String, dynamic>.from(e.value);
        s['key'] = s['key'] ?? s['no'] ?? 'row-${e.key}';
        final errors = s['errors'];
        s['selected'] = s['selected'] != false && !(errors is List && errors.isNotEmpty);
        return s;
      }).toList();
      data['staff'] = staff;
      _initSetupFromPreview(data);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not read that file');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirm() async {
    final hid = _hid;
    final ward = _ward;
    if (hid == null || ward == null || _preview == null) return;
    final selected = ApiService.instance.asMaps(_preview!['staff']).where((s) => s['selected'] != false).toList();
    if (selected.isEmpty) {
      setState(() => _error = 'Select at least one staff row');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      Map<String, dynamic> data;
      if (_preview!['source'] == 'roster') {
        final rosterSetup = _setupDraft != null ? buildRosterSetupPayload(_setupDraft!) : null;
        data = Map<String, dynamic>.from(
          await ApiService.instance.post(
            '/api/hospitals/$hid/staff/import-roster',
            {
              'staff': selected,
              'days': _preview!['days'] ?? [],
              'title': _preview!['title'],
              'legend': _preview!['legend'] ?? rosterSetup?['legend'],
              'rosterSetup': rosterSetup,
              'defaultDepartmentId': ward['departmentId'],
              'defaultWardId': ward['_id'],
              'createSchedule': _keepGridAsIs,
              'rules': {
                'leaveStayOff': _leaveStayOff,
                'offAndHolidayStayOff': _offAndHolidayStayOff,
                'keepGridAsIs': _keepGridAsIs,
              },
            },
            timeout: const Duration(seconds: 90),
          ) as Map,
        );
      } else {
        data = Map<String, dynamic>.from(
          await ApiService.instance.post('/api/hospitals/$hid/staff/import', {
            'staff': selected,
            'defaultDepartmentId': ward['departmentId'],
            'defaultWardId': ward['_id'],
          }) as Map,
        );
      }
      await HospitalStore.instance.load();
      setState(() {
        _result = data;
        _step = 'done';
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _patchLegend(String label, Map<String, dynamic> patch) {
    setState(() {
      final list = _legendRows.map((e) {
        if (e['label'] == label) return {...e, ...patch};
        return e;
      }).toList();
      _setupDraft = {...?_setupDraft, 'legend': list};
    });
  }

  @override
  Widget build(BuildContext context) {
    final wardName = _ward?['name']?.toString() ?? 'this ward';
    return Scaffold(
      appBar: AppBar(title: Text(_step == 'done' ? 'Imported' : 'Import roster')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_hint, style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          if (_step == 'chooser') ...[
            _choice(
              title: 'CSV spreadsheet',
              subtitle: 'Start from a staff list.',
              onTap: () => setState(() {
                _path = 'csv';
                _step = 'upload';
                _error = null;
              }),
            ),
            _choice(
              title: 'Duty roster file or photo',
              subtitle: 'Word, Excel, PDF, or a photo of the grid.',
              onTap: () => setState(() {
                _path = 'roster';
                _step = 'upload';
                _error = null;
              }),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loading ? null : _downloadTemplate,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Download CSV template'),
            ),
          ],
          if (_step == 'upload') ...[
            if (_fileName != null) Text(_fileName!, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (_path == 'csv')
              OutlinedButton(onPressed: _pickCsv, child: const Text('Choose CSV'))
            else ...[
              OutlinedButton(onPressed: _pickRosterFile, child: const Text('Choose file')),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: _pickPhoto, child: const Text('Choose photo')),
            ],
          ],
          if (_step == 'setup') ..._buildSetupStep(),
          if (_step == 'review' && _preview != null) ...[
            const Text('Tick who to keep. Nothing is saved yet.', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            for (var i = 0; i < _previewStaff.length; i++)
              CheckboxListTile(
                value: _previewStaff[i]['selected'] != false,
                onChanged: (v) {
                  setState(() {
                    final list = List<Map<String, dynamic>>.from(_previewStaff);
                    list[i] = {...list[i], 'selected': v != false};
                    _preview!['staff'] = list;
                  });
                },
                title: Text(
                  '${_previewStaff[i]['firstName'] ?? ''} ${_previewStaff[i]['lastName'] ?? _previewStaff[i]['fullName'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  [
                    _previewStaff[i]['rank']?.toString() ?? '',
                    if ((_previewStaff[i]['wardRole'] ?? '') != 'regular') _previewStaff[i]['wardRole'],
                  ].where((e) => e != null && e.toString().isNotEmpty).join(' · '),
                ),
              ),
          ],
          if (_step == 'rules') ...[
            SwitchListTile(
              title: const Text('People on leave stay off'),
              subtitle: const Text('Do not put them on shifts for those days.'),
              value: _leaveStayOff,
              onChanged: (v) => setState(() => _leaveStayOff = v),
            ),
            SwitchListTile(
              title: const Text('Off and holiday stay off'),
              subtitle: const Text('O and H cells are not shifts.'),
              value: _offAndHolidayStayOff,
              onChanged: (v) => setState(() => _offAndHolidayStayOff = v),
            ),
            SwitchListTile(
              title: const Text('Keep the uploaded grid'),
              subtitle: const Text('Do not auto-generate over what we just read.'),
              value: _keepGridAsIs,
              onChanged: (v) => setState(() => _keepGridAsIs = v),
            ),
          ],
          if (_step == 'done' && _result != null)
            Text(
              '${_result!['imported'] ?? _selectedCount} staff on $wardName.',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 20),
          if (_step == 'done') ...[
            if (_result?['scheduleId'] != null)
              FilledButton(
                onPressed: () => context.go('/schedule/${_result!['scheduleId']}'),
                child: const Text('Open roster'),
              ),
            TextButton(
              onPressed: () => context.go('/ward/${widget.wardId}'),
              child: const Text('Stay on this ward'),
            ),
          ] else
            Row(children: [
              if (_step != 'chooser')
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _error = null;
                        if (_step == 'rules') {
                          _step = 'review';
                        } else if (_step == 'review') {
                          _step = (_rawPreview?['source'] == 'roster' && _legendRows.isNotEmpty) ? 'setup' : 'upload';
                          if (_step == 'upload') {
                            _preview = null;
                            _rawPreview = null;
                            _setupDraft = null;
                          }
                        } else if (_step == 'setup') {
                          _step = 'upload';
                          _preview = null;
                          _rawPreview = null;
                          _setupDraft = null;
                        } else {
                          _step = 'chooser';
                          _fileName = null;
                          _bytes = null;
                          _csvText = null;
                        }
                      });
                    },
                    child: const Text('Back'),
                  ),
                ),
              if (_step != 'chooser') const SizedBox(width: 8),
              Expanded(child: _primaryButton(wardName)),
            ]),
        ],
      ),
    );
  }

  List<Widget> _buildSetupStep() {
    final staffOptions = _previewStaff;
    return [
      if (_setupDraft != null) ...[
        const Text('Confirm legend codes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 4),
        Text('Map each code from the file to a MedRoster meaning.', style: TextStyle(color: AppColors.muted, fontSize: 13)),
        const SizedBox(height: 12),
        for (final e in _legendRows)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(e['label']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(width: 8),
                  if (e['needsConfirm'] == true)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Check', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  const Spacer(),
                  Text('×${e['count'] ?? ''}', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                ]),
                if ((e['codeHint'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(e['codeHint'].toString(), style: TextStyle(fontSize: 11, color: AppColors.muted)),
                  ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: legendMeanings.contains(e['meaning']) ? e['meaning'] as String : null,
                  decoration: const InputDecoration(labelText: 'Meaning', isDense: true),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('— skip / unknown —')),
                    ...legendMeaningOptions.map(
                      (o) => DropdownMenuItem(value: o['value'], child: Text(o['label']!)),
                    ),
                  ],
                  onChanged: (v) => _patchLegend(e['label'].toString(), {
                    'meaning': v ?? '',
                    'dutyKind': kindFromMeaning(v ?? ''),
                    'dutyOverlaps': v != null ? normalizeDutyOverlaps(e['dutyOverlaps'], v) : [],
                    'officeDays': v == 'Office' ? normalizeOfficeDays(e['officeDays'], v!) : [],
                    'needsConfirm': false,
                  }),
                ),
              ]),
            ),
          ),
        const SizedBox(height: 12),
        const Text('Ward roles', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: (_setupDraft!['inchargeStaffKey']?.toString().isNotEmpty ?? false)
              ? _setupDraft!['inchargeStaffKey'].toString()
              : null,
          decoration: const InputDecoration(labelText: 'Ward in-charge (optional)'),
          items: [
            const DropdownMenuItem(value: null, child: Text('None')),
            ...staffOptions.map(
              (s) => DropdownMenuItem(
                value: s['key']?.toString(),
                child: Text('${s['firstName'] ?? ''} ${s['lastName'] ?? s['fullName'] ?? ''}'),
              ),
            ),
          ],
          onChanged: (v) => setState(() => _setupDraft = {..._setupDraft!, 'inchargeStaffKey': v ?? ''}),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: (_setupDraft!['assistantStaffKey']?.toString().isNotEmpty ?? false)
              ? _setupDraft!['assistantStaffKey'].toString()
              : null,
          decoration: const InputDecoration(labelText: 'Assistant in-charge (optional)'),
          items: [
            const DropdownMenuItem(value: null, child: Text('None')),
            ...staffOptions.map(
              (s) => DropdownMenuItem(
                value: s['key']?.toString(),
                child: Text('${s['firstName'] ?? ''} ${s['lastName'] ?? s['fullName'] ?? ''}'),
              ),
            ),
          ],
          onChanged: (v) => setState(() => _setupDraft = {..._setupDraft!, 'assistantStaffKey': v ?? ''}),
        ),
      ],
    ];
  }

  Widget _primaryButton(String wardName) {
    if (_step == 'chooser') {
      return OutlinedButton(onPressed: () => context.pop(), child: const Text('Close'));
    }
    if (_step == 'upload') {
      return FilledButton(
        onPressed: _loading ? null : _readFile,
        child: Text(_loading ? 'Reading…' : 'Read file'),
      );
    }
    if (_step == 'setup') {
      return FilledButton(
        onPressed: _loading ? null : _applySetupAndReview,
        child: const Text('Apply legend'),
      );
    }
    if (_step == 'review') {
      return FilledButton(
        onPressed: _loading || _selectedCount == 0
            ? null
            : () {
                if (_preview?['source'] == 'roster') {
                  setState(() => _step = 'rules');
                } else {
                  _confirm();
                }
              },
        child: Text(_preview?['source'] == 'roster' ? 'Continue with $_selectedCount' : 'Confirm $_selectedCount staff'),
      );
    }
    if (_step == 'rules') {
      return FilledButton(
        onPressed: _loading || _selectedCount == 0 ? null : _confirm,
        child: Text(_loading ? 'Saving…' : 'Save to $wardName'),
      );
    }
    return const SizedBox.shrink();
  }

  String get _hint {
    switch (_step) {
      case 'chooser':
        return 'Start from a spreadsheet, or upload a duty roster you already have.';
      case 'upload':
        return _path == 'csv'
            ? 'Upload your CSV.'
            : 'Upload a Word, Excel, PDF, or photo of the roster.';
      case 'setup':
        return 'Confirm how codes in the file map to shifts, then continue.';
      case 'review':
        return 'Tick who to keep. Nothing is saved yet.';
      case 'rules':
        return 'How should we read the file? Core roster rules stay on.';
      case 'done':
        return 'Staff are on this ward. Open the roster when you want to edit shifts.';
      default:
        return '';
    }
  }

  Widget _choice({required String title, required String subtitle, required VoidCallback onTap}) {
    return Card(
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
