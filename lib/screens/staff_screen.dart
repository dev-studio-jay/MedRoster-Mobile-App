import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_view.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  List<Map<String, dynamic>> _staff = [];
  List<Map<String, dynamic>> _departments = [];
  String? _hospitalId;
  bool _loading = true;
  String? _error;
  String _search = '';
  bool _canWrite = false;
  bool _hasHospital = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      await ApiService.instance.loadProfile();
      _canWrite = ApiService.instance.canWrite;
      _hasHospital = ApiService.instance.hasHospital;
      if (!_hasHospital) {
        setState(() {
          _staff = [];
          _departments = [];
        });
        return;
      }
      final hospitals = await ApiService.instance.get('/api/hospitals') as List;
      if (hospitals.isEmpty) {
        _hasHospital = false;
        setState(() {
          _staff = [];
          _departments = [];
        });
        return;
      }
      _hospitalId = hospitals.first['_id'] as String;
      final results = await Future.wait([
        ApiService.instance.get('/api/hospitals/$_hospitalId/staff'),
        ApiService.instance.get('/api/hospitals/$_hospitalId/departments'),
      ]);
      setState(() {
        _staff = (results[0] as List).cast<Map<String, dynamic>>();
        _departments = (results[1] as List).cast<Map<String, dynamic>>();
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _staff;
    final q = _search.toLowerCase();
    return _staff.where((s) {
      final name = '${s['firstName']} ${s['lastName']}'.toLowerCase();
      return name.contains(q) || (s['rank'] as String? ?? '').toLowerCase().contains(q);
    }).toList();
  }

  String _deptName(String? id) {
    if (id == null) return '';
    return _departments.firstWhere((d) => d['_id'] == id, orElse: () => {})['name'] ?? '';
  }

  Color _rankColor(String? rank) {
    if (rank == null) return Colors.grey;
    if (rank.toLowerCase().contains('consultant') || rank.toLowerCase().contains('specialist')) return Colors.purple;
    if (rank.toLowerCase().contains('medical officer') || rank.toLowerCase().contains('doctor')) return Colors.blue;
    if (rank.toLowerCase().contains('nurse') || rank.toLowerCase().contains('midwife')) return Colors.green;
    return Colors.orange;
  }

  Future<void> _showAddDialog() async {
    final firstCtrl = TextEditingController();
    final lastCtrl = TextEditingController();
    String rank = 'Staff Nurse';
    String? deptId = _departments.isNotEmpty ? _departments.first['_id'] as String : null;

    const ranks = [
      'Consultant', 'Specialist', 'Medical Officer', 'House Officer',
      'Senior Nursing Officer', 'Nursing Officer', 'Staff Nurse', 'Enrolled Nurse',
      'Midwife', 'Senior Midwife', 'Medical Assistant', 'Community Health Officer',
    ];

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Add Staff'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: firstCtrl, decoration: const InputDecoration(labelText: 'First Name'), autofocus: true),
              const SizedBox(height: 10),
              TextField(controller: lastCtrl, decoration: const InputDecoration(labelText: 'Last Name')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: rank,
                decoration: const InputDecoration(labelText: 'Rank'),
                items: ranks.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (v) => setS(() => rank = v!),
              ),
              if (_departments.isNotEmpty) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: deptId,
                  decoration: const InputDecoration(labelText: 'Department'),
                  items: _departments.map((d) => DropdownMenuItem(value: d['_id'] as String, child: Text(d['name'] as String))).toList(),
                  onChanged: (v) => setS(() => deptId = v),
                ),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result == true && firstCtrl.text.isNotEmpty && lastCtrl.text.isNotEmpty && _hospitalId != null) {
      try {
        await ApiService.instance.post('/api/hospitals/$_hospitalId/staff', {
          'firstName': firstCtrl.text.trim(),
          'lastName': lastCtrl.text.trim(),
          'rank': rank,
          if (deptId != null) 'departmentId': deptId,
        });
        _load();
      } on ApiException catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _delete(String staffId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Staff'),
        content: Text('Remove "$name" from the roster?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red, minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm == true && _hospitalId != null) {
      try {
        await ApiService.instance.delete('/api/hospitals/$_hospitalId/staff/$staffId');
        _load();
      } on ApiException catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search staff…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: (_canWrite && _hasHospital)
          ? FloatingActionButton.extended(
              onPressed: _showAddDialog,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Staff'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : !_hasHospital
                  ? const EmptyState(icon: Icons.local_hospital_outlined, message: ApiService.individualAppMessage)
                  : filtered.isEmpty
                  ? EmptyState(
                      icon: Icons.people_outline,
                      message: _search.isEmpty
                          ? (_canWrite ? 'No staff yet.\nTap + to add.' : 'No staff yet.')
                          : 'No results for "$_search"',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final s = filtered[i];
                          final name = '${s['firstName']} ${s['lastName']}';
                          final rank = s['rank'] as String? ?? '';
                          final dept = _deptName(s['departmentId'] as String?);
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              leading: CircleAvatar(
                                backgroundColor: _rankColor(rank).withValues(alpha: 0.15),
                                child: Text(
                                  (s['firstName'] as String? ?? '?').substring(0, 1).toUpperCase(),
                                  style: TextStyle(color: _rankColor(rank), fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(dept.isNotEmpty ? '$rank · $dept' : rank, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                              trailing: _canWrite
                                  ? IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () => _delete(s['_id'] as String, name),
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
