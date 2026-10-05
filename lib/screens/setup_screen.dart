import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../state/hospital_store.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _deptCtrl = TextEditingController();
  final _wardCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _deptCtrl.dispose();
    _wardCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final hid = HospitalStore.instance.hospitalId;
    final deptName = _deptCtrl.text.trim();
    final wardName = _wardCtrl.text.trim();
    if (hid == null || deptName.isEmpty) {
      setState(() => _error = 'Add a department name');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final dept = await ApiService.instance.post('/api/hospitals/$hid/departments', {'name': deptName});
      final deptId = (dept is List && dept.isNotEmpty)
          ? (dept.first as Map)['_id']
          : (dept as Map)['_id'];
      if (wardName.isNotEmpty && deptId != null) {
        await ApiService.instance.post('/api/hospitals/$hid/wards', {
          'departmentId': deptId,
          'name': wardName,
        });
      }
      await HospitalStore.instance.load();
      if (!mounted) return;
      final first = HospitalStore.instance.displayWards.isNotEmpty
          ? HospitalStore.instance.displayWards.first
          : (HospitalStore.instance.wards.isNotEmpty ? HospitalStore.instance.wards.first : null);
      if (first != null) {
        context.go('/ward/${first['_id']}');
      } else {
        context.go('/wards');
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Set up this hospital', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Add a department group and the first ward. You can add more later.'),
        const SizedBox(height: 24),
        TextField(controller: _deptCtrl, decoration: const InputDecoration(labelText: 'Department (e.g. Maternity)')),
        const SizedBox(height: 12),
        TextField(controller: _wardCtrl, decoration: const InputDecoration(labelText: 'Ward / unit (e.g. lying-in)')),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Saving…' : 'Continue'),
        ),
      ],
    );
  }
}
