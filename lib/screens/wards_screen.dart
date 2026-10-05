import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../state/hospital_store.dart';
import '../util/org_units.dart';
import '../widgets/error_view.dart';

class WardsScreen extends StatefulWidget {
  const WardsScreen({super.key});

  @override
  State<WardsScreen> createState() => _WardsScreenState();
}

class _WardsScreenState extends State<WardsScreen> {
  String? _error;
  bool _busy = false;
  final _deptCtrl = TextEditingController();
  final _wardDrafts = <String, TextEditingController>{};

  String? get _hid => HospitalStore.instance.hospitalId;
  bool get _canWrite => ApiService.instance.canWrite;

  @override
  void dispose() {
    _deptCtrl.dispose();
    for (final c in _wardDrafts.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _wardCtrl(String deptId) {
    return _wardDrafts.putIfAbsent(deptId, TextEditingController.new);
  }

  Future<void> _addDepartment() async {
    final name = _deptCtrl.text.trim();
    if (name.isEmpty || _hid == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApiService.instance.post('/api/hospitals/$_hid/departments', {'name': name});
      _deptCtrl.clear();
      await HospitalStore.instance.load();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addWard(String departmentId) async {
    final name = _wardCtrl(departmentId).text.trim();
    if (name.isEmpty || _hid == null) return;
    try {
      await ApiService.instance.post('/api/hospitals/$_hid/wards', {
        'departmentId': departmentId,
        'name': name,
      });
      _wardCtrl(departmentId).clear();
      await HospitalStore.instance.load();
      if (mounted) setState(() {});
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _deleteDepartment(Map<String, dynamic> dept) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete department'),
        content: Text('Delete ${dept['name']}? Staff in this department must be moved first.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || _hid == null) return;
    try {
      await ApiService.instance.delete('/api/hospitals/$_hid/departments/${dept['_id']}');
      await HospitalStore.instance.load();
      if (mounted) setState(() {});
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _deleteWard(Map<String, dynamic> ward) async {
    if (_hid == null) return;
    try {
      await ApiService.instance.delete('/api/hospitals/$_hid/wards/${ward['_id']}');
      await HospitalStore.instance.load();
      if (mounted) setState(() {});
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = HospitalStore.instance;
    if (store.error != null && store.departments.isEmpty) {
      return ErrorView(message: store.error!, onRetry: store.load);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Add / edit wards', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Departments group the work. Wards and units are where the roster happens.'),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        if (_canWrite) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _deptCtrl,
            decoration: const InputDecoration(labelText: 'New department group'),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: _busy ? null : _addDepartment,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              child: const Text('Add department'),
            ),
          ),
        ],
        const SizedBox(height: 16),
        for (final dept in store.departments)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(dept['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                  if (_canWrite)
                    IconButton(onPressed: () => _deleteDepartment(dept), icon: const Icon(Icons.delete_outline)),
                ]),
                for (final ward in getDisplayWardsForDepartment(dept, store.wards))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(ward['name']?.toString() ?? ''),
                    trailing: _canWrite
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => _deleteWard(ward),
                          )
                        : null,
                  ),
                if (_canWrite)
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _wardCtrl(dept['_id'].toString()),
                        decoration: const InputDecoration(hintText: 'Ward / unit name'),
                      ),
                    ),
                    IconButton(onPressed: () => _addWard(dept['_id'].toString()), icon: const Icon(Icons.add)),
                  ]),
              ]),
            ),
          ),
      ],
    );
  }
}
