import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_view.dart';

class SchedulesScreen extends StatefulWidget {
  const SchedulesScreen({super.key});

  @override
  State<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends State<SchedulesScreen> {
  List<Map<String, dynamic>> _schedules = [];
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _wards = [];
  String? _hospitalId;
  bool _loading = true;
  String? _error;

  final _dateFmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final hospitals = await ApiService.instance.get('/api/hospitals') as List;
      if (hospitals.isEmpty) throw Exception('No hospital found');
      _hospitalId = hospitals.first['_id'] as String;
      final results = await Future.wait([
        ApiService.instance.get('/api/hospitals/$_hospitalId/schedules'),
        ApiService.instance.get('/api/hospitals/$_hospitalId/departments'),
        ApiService.instance.get('/api/hospitals/$_hospitalId/wards'),
      ]);
      setState(() {
        _schedules = (results[0] as List).cast<Map<String, dynamic>>();
        _departments = (results[1] as List).cast<Map<String, dynamic>>();
        _wards = (results[2] as List).cast<Map<String, dynamic>>();
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _deptName(String? id) => id == null ? '' : (_departments.firstWhere((d) => d['_id'] == id, orElse: () => {})['name'] ?? '');
  String _wardName(String? id) => id == null ? '' : (_wards.firstWhere((w) => w['_id'] == id, orElse: () => {})['name'] ?? '');

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try { return _dateFmt.format(DateTime.parse(iso)); } catch (_) { return iso; }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'published': return Colors.green;
      case 'draft': return Colors.orange;
      default: return Colors.grey;
    }
  }

  Future<void> _showCreateDialog() async {
    final nameCtrl = TextEditingController();
    String? deptId = _departments.isNotEmpty ? _departments.first['_id'] as String : null;
    String? wardId;
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 27));

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('New Schedule'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Schedule Name'), autofocus: true),
              const SizedBox(height: 10),
              if (_departments.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: deptId,
                  decoration: const InputDecoration(labelText: 'Department'),
                  items: _departments.map((d) => DropdownMenuItem(value: d['_id'] as String, child: Text(d['name'] as String))).toList(),
                  onChanged: (v) => setS(() { deptId = v; wardId = null; }),
                ),
              const SizedBox(height: 10),
              if (_wards.isNotEmpty)
                DropdownButtonFormField<String?>(
                  initialValue: wardId,
                  decoration: const InputDecoration(labelText: 'Ward (optional)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('No specific ward')),
                    ..._wards
                        .where((w) => deptId == null || w['departmentId'] == deptId)
                        .map((w) => DropdownMenuItem(value: w['_id'] as String, child: Text(w['name'] as String))),
                  ],
                  onChanged: (v) => setS(() => wardId = v),
                ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Start Date'),
                subtitle: Text(DateFormat('dd MMM yyyy').format(startDate)),
                trailing: const Icon(Icons.calendar_today, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: startDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setS(() => startDate = picked);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('End Date'),
                subtitle: Text(DateFormat('dd MMM yyyy').format(endDate)),
                trailing: const Icon(Icons.calendar_today, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: endDate,
                    firstDate: startDate,
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setS(() => endDate = picked);
                },
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (result == true && nameCtrl.text.isNotEmpty && _hospitalId != null) {
      try {
        await ApiService.instance.post('/api/hospitals/$_hospitalId/schedules', {
          'name': nameCtrl.text.trim(),
          if (deptId != null) 'departmentId': deptId,
          if (wardId != null) 'wardId': wardId,
          'startDate': startDate.toIso8601String().split('T').first,
          'endDate': endDate.toIso8601String().split('T').first,
          'status': 'draft',
        });
        _load();
      } on ApiException catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _delete(String schedId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Schedule'),
        content: Text('Delete "$name"? All assignments will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red, minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && _hospitalId != null) {
      try {
        await ApiService.instance.delete('/api/hospitals/$_hospitalId/schedules/$schedId');
        _load();
      } on ApiException catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Schedules')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Schedule'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _schedules.isEmpty
                  ? EmptyState(icon: Icons.calendar_month_outlined, message: 'No schedules yet.\nTap + to create one.', onAction: _showCreateDialog, actionLabel: 'New Schedule')
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                        itemCount: _schedules.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final s = _schedules[i];
                          final status = s['status'] as String? ?? 'draft';
                          final dept = _deptName(s['departmentId'] as String?);
                          final ward = _wardName(s['wardId'] as String?);
                          final subtitle = [dept, ward].where((e) => e.isNotEmpty).join(' · ');
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: _statusColor(status).withValues(alpha: 0.15),
                                child: Icon(Icons.calendar_month, color: _statusColor(status), size: 20),
                              ),
                              title: Text(s['name'] ?? 'Schedule', style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                if (subtitle.isNotEmpty) Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                Text('${_formatDate(s['startDate'])} — ${_formatDate(s['endDate'])}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _statusColor(status).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, color: _statusColor(status), fontWeight: FontWeight.bold)),
                                ),
                              ]),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _delete(s['_id'] as String, s['name'] as String? ?? ''),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
