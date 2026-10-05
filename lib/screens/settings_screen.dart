import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../state/hospital_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _editing = false;
  bool _busy = false;
  String? _error;
  String? _success;
  late final TextEditingController _codeCtrl;

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController(text: HospitalStore.instance.hospital?['joinCode']?.toString() ?? '');
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final hid = HospitalStore.instance.hospitalId;
    if (hid == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      final data = await ApiService.instance.patch('/api/hospitals/$hid/join-code', {
        'newCode': _codeCtrl.text.trim(),
      });
      final code = (data as Map)['joinCode']?.toString() ?? _codeCtrl.text.trim();
      setState(() {
        _success = 'Saved as $code';
        _editing = false;
      });
      await HospitalStore.instance.load();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = HospitalStore.instance.hospital?['joinCode']?.toString() ?? '— — —';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(
                  child: Text('Hospital join code', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                if (!_editing)
                  TextButton(
                    onPressed: () {
                      _codeCtrl.text = HospitalStore.instance.hospital?['joinCode']?.toString() ?? '';
                      setState(() => _editing = true);
                    },
                    child: const Text('Edit'),
                  ),
              ]),
              const Text('Staff use this code to join and view schedules.'),
              const SizedBox(height: 12),
              if (!_editing)
                Text(code, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 4))
              else ...[
                TextField(
                  controller: _codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Join code'),
                ),
                if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
                Row(children: [
                  TextButton(onPressed: () => setState(() => _editing = false), child: const Text('Cancel')),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                    child: Text(_busy ? 'Saving…' : 'Save code'),
                  ),
                ]),
              ],
              if (_success != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_success!, style: const TextStyle(color: Colors.green)),
                ),
              const SizedBox(height: 8),
              const Text(
                'Share this code with staff so they can join via Join hospital and view schedules (read-only).',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}
