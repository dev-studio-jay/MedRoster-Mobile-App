import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../state/hospital_store.dart';
import '../theme/app_theme.dart';
import '../util/ghana_data.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int _step = 1;
  late Set<String> _selected;
  List<Map<String, String>> _editable = [];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    const base = ['Accident & Emergency', 'Outpatient Department', 'Pharmacy', 'Maternity'];
    _selected = {
      for (final t in departmentTemplates)
        if (base.contains(t.name)) t.name,
    };
  }

  void _toggle(String name) {
    setState(() {
      if (_selected.contains(name)) {
        _selected.remove(name);
      } else {
        _selected.add(name);
      }
    });
  }

  void _goToReview() {
    setState(() {
      _editable = departmentTemplates
          .where((t) => _selected.contains(t.name))
          .map((t) => {'name': t.name, 'description': t.description})
          .toList();
      _step = 2;
      _error = null;
    });
  }

  void _addCustom() {
    setState(() => _editable.add({'name': '', 'description': ''}));
  }

  Future<void> _save() async {
    final hid = HospitalStore.instance.hospitalId;
    if (hid == null) return;
    final valid = _editable
        .map((d) => {
              'name': (d['name'] ?? '').trim(),
              'description': (d['description'] ?? '').trim(),
            })
        .where((d) => (d['name'] ?? '').isNotEmpty)
        .toList();
    if (valid.isEmpty) {
      setState(() => _error = 'Add at least one department');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApiService.instance.post('/api/hospitals/$hid/departments', {'departments': valid});
      await HospitalStore.instance.load();
      if (!mounted) return;
      context.go('/wards');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Step $_step of 2',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: AppColors.teal,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _step == 1 ? 'Pick department groups' : 'Review and customise',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          _step == 1
              ? 'Select the broad departments at your facility. You will add wards inside each group next.'
              : 'Rename anything to match your hospital, edit descriptions, or add custom groups.',
          style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 20),
        if (_step == 1) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in departmentTemplates)
                _TemplateChip(
                  name: t.name,
                  description: t.description,
                  selected: _selected.contains(t.name),
                  onTap: () => _toggle(t.name),
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _selected.isEmpty ? null : _goToReview,
            child: Text('Continue with ${_selected.length}'),
          ),
        ] else ...[
          for (var i = 0; i < _editable.length; i++)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  TextFormField(
                    initialValue: _editable[i]['name'],
                    decoration: const InputDecoration(labelText: 'Department name'),
                    onChanged: (v) => _editable[i]['name'] = v,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: _editable[i]['description'],
                    decoration: const InputDecoration(labelText: 'Description'),
                    onChanged: (v) => _editable[i]['description'] = v,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() => _editable.removeAt(i)),
                      child: const Text('Remove'),
                    ),
                  ),
                ]),
              ),
            ),
          OutlinedButton.icon(
            onPressed: _addCustom,
            icon: const Icon(Icons.add),
            label: const Text('Add custom department'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : () => setState(() => _step = 1),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Saving…' : 'Save departments'),
              ),
            ),
          ]),
        ],
      ],
    );
  }
}

class _TemplateChip extends StatelessWidget {
  final String name;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _TemplateChip({
    required this.name,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: (MediaQuery.sizeOf(context).width - 56) / 2,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.teal.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.teal : AppColors.border, width: selected ? 1.5 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              size: 18,
              color: selected ? AppColors.teal : AppColors.muted,
            ),
          ]),
          const SizedBox(height: 4),
          Text(description, style: TextStyle(fontSize: 11, color: AppColors.muted, height: 1.3)),
        ]),
      ),
    );
  }
}
