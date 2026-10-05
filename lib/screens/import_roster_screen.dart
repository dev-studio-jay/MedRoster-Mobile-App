import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../state/hospital_store.dart';

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
  Map<String, dynamic>? _preview;
  Map<String, dynamic>? _result;
  bool _leaveStayOff = true;
  bool _offAndHolidayStayOff = true;
  bool _keepGridAsIs = true;

  String? get _hid => HospitalStore.instance.hospitalId ?? ApiService.instance.hospitalId;

  Map<String, dynamic>? get _ward => HospitalStore.instance.wardById(widget.wardId);

  int get _selectedCount {
    return _previewStaff.where((s) => s['selected'] != false).length;
  }

  List<Map<String, dynamic>> get _previewStaff =>
      ApiService.instance.asMaps(_preview?['staff']);

  @override
  void initState() {
    super.initState();
    if (HospitalStore.instance.hospital == null) {
      HospitalStore.instance.load();
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
      setState(() {
        _preview = data;
        _step = 'review';
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
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
        data = Map<String, dynamic>.from(
          await ApiService.instance.post(
            '/api/hospitals/$hid/staff/import-roster',
            {
              'staff': selected,
              'days': _preview!['days'] ?? [],
              'title': _preview!['title'],
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

  @override
  Widget build(BuildContext context) {
    final wardName = _ward?['name']?.toString() ?? 'this ward';
    return Scaffold(
      appBar: AppBar(title: Text(_step == 'done' ? 'Imported' : 'Import roster')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_hint, style: TextStyle(color: Colors.grey[700])),
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
          ],
          if (_step == 'upload') ...[
            if (_fileName != null) Text(_fileName!, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_path == 'csv')
              OutlinedButton(onPressed: _pickCsv, child: const Text('Choose CSV'))
            else ...[
              OutlinedButton(onPressed: _pickRosterFile, child: const Text('Choose file')),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: _pickPhoto, child: const Text('Choose photo')),
            ],
          ],
          if (_step == 'review' && _preview != null) ...[
            const Text('Tick who to keep. Nothing is saved yet.'),
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
                ),
                subtitle: Text(_previewStaff[i]['rank']?.toString() ?? ''),
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Morning senior cover is always checked on the calendar.'),
            ),
          ],
          if (_step == 'done' && _result != null)
            Text(
              '${_result!['imported'] ?? _selectedCount} people on $wardName.',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
                          _step = 'upload';
                          _preview = null;
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
      case 'review':
        return 'Tick who to keep. Nothing is saved yet.';
      case 'rules':
        return 'How should we read the file? Core roster rules stay on.';
      case 'done':
        return 'People are on this ward. Open the roster when you want to edit shifts.';
      default:
        return '';
    }
  }

  Widget _choice({required String title, required String subtitle, required VoidCallback onTap}) {
    return Card(
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        onTap: onTap,
      ),
    );
  }
}
