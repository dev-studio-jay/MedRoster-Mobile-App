import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../util/roster_setup.dart';
import '../util/sandbox_roster.dart';

/// Import for guest / individual sandbox — returns merged staff + assignments + rosterSetup.
class SandboxImportScreen extends StatefulWidget {
  final String mode; // 'guest' | 'individual'
  final Map<String, dynamic>? existingSetup;

  const SandboxImportScreen({super.key, required this.mode, this.existingSetup});

  @override
  State<SandboxImportScreen> createState() => _SandboxImportScreenState();
}

class _SandboxImportScreenState extends State<SandboxImportScreen> {
  String _step = 'chooser';
  String? _path;
  String? _fileName;
  Uint8List? _bytes;
  String? _csvText;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _rawPreview;
  Map<String, dynamic>? _preview;
  Map<String, dynamic>? _setupDraft;

  String get _base => widget.mode == 'guest' ? '/api/guest/staff' : '/api/me/staff';

  List<Map<String, dynamic>> get _previewStaff => ApiService.instance.asMaps(_preview?['staff']);
  List<Map<String, dynamic>> get _legendRows =>
      (_setupDraft?['legend'] as List?)?.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() ?? [];

  Future<void> _pickCsv() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['csv'], withData: true);
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

  void _initSetup(Map<String, dynamic> data) {
    final proposal = buildSetupProposal(data, widget.existingSetup);
    final legend = (proposal['legendDraft'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    setState(() {
      _rawPreview = data;
      _setupDraft = {
        'legend': legend,
        'inchargeStaffKey': widget.existingSetup?['inchargeStaffKey'] ?? '',
        'assistantStaffKey': widget.existingSetup?['assistantStaffKey'] ?? '',
        'leaveByKey': <String, dynamic>{},
      };
      _preview = data;
      _step = data['source'] == 'roster' && legend.isNotEmpty ? 'setup' : 'review';
    });
  }

  Future<void> _readFile() async {
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
          await ApiService.instance.post('$_base/import', {'csvText': _csvText}) as Map,
        );
      } else {
        data = Map<String, dynamic>.from(
          await ApiService.instance.post(
            '$_base/extract',
            {'fileBase64': base64Encode(_bytes!), 'fileName': _fileName ?? 'roster'},
            timeout: const Duration(seconds: 120),
          ) as Map,
        );
      }
      final staff = ApiService.instance.asMaps(data['staff']).asMap().entries.map((e) {
        final s = Map<String, dynamic>.from(e.value);
        s['key'] = s['key'] ?? s['no'] ?? 'row-${e.key}';
        s['_id'] = s['_id'] ?? '${widget.mode}_${s['key']}';
        final errors = s['errors'];
        s['selected'] = s['selected'] != false && !(errors is List && errors.isNotEmpty);
        return s;
      }).toList();
      data['staff'] = staff;
      if (_path == 'csv') data['source'] = 'csv';
      _initSetup(data);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      setState(() {
        _error = msg.contains('timeout') || msg.contains('timed out')
            ? 'Reading timed out. Try a smaller file or a clearer photo on Wi‑Fi.'
            : 'Could not read that file. Use CSV, Word, Excel, PDF, or a clear photo.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applySetup() {
    if (_rawPreview == null || _setupDraft == null) return;
    final payload = buildRosterSetupPayload(_setupDraft!);
    final remapped = applyRosterSetup(_rawPreview!, {...payload, 'leaveByKey': _setupDraft!['leaveByKey'] ?? {}});
    setState(() {
      _preview = remapped;
      _setupDraft = {..._setupDraft!, ...payload};
      _step = 'review';
    });
  }

  void _finish() {
    final selected = _previewStaff.where((s) => s['selected'] != false).map((s) {
      final m = Map<String, dynamic>.from(s);
      m['_id'] = m['_id'] ?? '${widget.mode}_${m['key']}';
      return m;
    }).toList();
    if (selected.isEmpty) {
      setState(() => _error = 'Select at least one staff row');
      return;
    }
    final rosterSetup = _setupDraft != null ? buildRosterSetupPayload(_setupDraft!) : null;
    final assignments = mapPreviewToAssignments(selected);
    context.pop({
      'staff': selected,
      'assignments': assignments,
      'rosterSetup': rosterSetup,
      'days': _preview?['days'],
      'title': _preview?['title'],
    });
  }

  void _patchLegend(String label, Map<String, dynamic> patch) {
    setState(() {
      final list = _legendRows.map((e) => e['label'] == label ? {...e, ...patch} : e).toList();
      _setupDraft = {...?_setupDraft, 'legend': list};
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import roster')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_hint, style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          if (_step == 'chooser') ...[
            _choice('CSV spreadsheet', 'Start from a staff list.', () => setState(() {
                  _path = 'csv';
                  _step = 'upload';
                })),
            _choice('Duty roster file or photo', 'Word, Excel, PDF, or photo.', () => setState(() {
                  _path = 'roster';
                  _step = 'upload';
                })),
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
          if (_step == 'setup') ...[
            const Text('Confirm legend codes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 8),
            for (final e in _legendRows)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e['label']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: legendMeanings.contains(e['meaning']) ? e['meaning'] as String : null,
                      decoration: const InputDecoration(labelText: 'Meaning', isDense: true),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('— skip —')),
                        ...legendMeaningOptions.map((o) => DropdownMenuItem(value: o['value'], child: Text(o['label']!))),
                      ],
                      onChanged: (v) => _patchLegend(e['label'].toString(), {
                        'meaning': v ?? '',
                        'dutyKind': kindFromMeaning(v ?? ''),
                        'needsConfirm': false,
                      }),
                    ),
                  ]),
                ),
              ),
          ],
          if (_step == 'review') ...[
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
                title: Text('${_previewStaff[i]['firstName'] ?? ''} ${_previewStaff[i]['lastName'] ?? _previewStaff[i]['fullName'] ?? ''}'),
                subtitle: Text(_previewStaff[i]['rank']?.toString() ?? ''),
              ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 20),
          Row(children: [
            if (_step != 'chooser')
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _error = null;
                    if (_step == 'review') {
                      _step = (_rawPreview?['source'] == 'roster' && _legendRows.isNotEmpty) ? 'setup' : 'upload';
                    } else if (_step == 'setup') {
                      _step = 'upload';
                    } else {
                      _step = 'chooser';
                    }
                  }),
                  child: const Text('Back'),
                ),
              ),
            if (_step != 'chooser') const SizedBox(width: 8),
            Expanded(child: _primary()),
          ]),
        ],
      ),
    );
  }

  Widget _primary() {
    if (_step == 'chooser') return OutlinedButton(onPressed: () => context.pop(), child: const Text('Close'));
    if (_step == 'upload') {
      return FilledButton(onPressed: _loading ? null : _readFile, child: Text(_loading ? 'Reading…' : 'Read file'));
    }
    if (_step == 'setup') return FilledButton(onPressed: _applySetup, child: const Text('Apply legend'));
    return FilledButton(onPressed: _finish, child: Text('Import ${_previewStaff.where((s) => s['selected'] != false).length}'));
  }

  String get _hint {
    switch (_step) {
      case 'chooser':
        return 'Import staff or a duty roster into this sandbox schedule.';
      case 'upload':
        return 'Choose a file to read.';
      case 'setup':
        return 'Map file codes to shifts.';
      case 'review':
        return 'Tick who to keep.';
      default:
        return '';
    }
  }

  Widget _choice(String title, String subtitle, VoidCallback onTap) {
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
