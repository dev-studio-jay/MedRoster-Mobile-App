import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _hospital;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final uid = AuthService.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not authenticated');

      await ApiService.instance.loadProfile();
      if (!ApiService.instance.hasHospital) {
        setState(() => _hospital = null);
        return;
      }

      final data = await ApiService.instance.get('/api/hospitals');
      final list = (data as List);
      if (list.isNotEmpty) {
        setState(() => _hospital = list.first as Map<String, dynamic>);
      } else {
        setState(() => _hospital = null);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    ApiService.instance.clearProfile();
    await AuthService.instance.signOut();
    if (mounted) context.go('/auth/login');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('MedRoster'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Sign out', onPressed: _signOut),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildBody(theme),
    );
  }

  Widget _buildError() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, size: 48, color: Colors.red),
      const SizedBox(height: 12),
      Text(_error!, textAlign: TextAlign.center),
      const SizedBox(height: 16),
      FilledButton.icon(icon: const Icon(Icons.refresh), label: const Text('Retry'), onPressed: _load),
    ]),
  );

  Widget _buildBody(ThemeData theme) {
    final h = _hospital;
    if (h == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            ApiService.individualAppMessage,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HospitalCard(hospital: h),
          const SizedBox(height: 20),
          Text('Quick Access', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              _QuickCard(icon: Icons.account_tree, label: 'Departments', color: Colors.blue, onTap: () => context.go('/departments')),
              _QuickCard(icon: Icons.people, label: 'Staff', color: Colors.green, onTap: () => context.go('/staff')),
              _QuickCard(icon: Icons.calendar_month, label: 'Schedules', color: Colors.orange, onTap: () => context.go('/schedules')),
            ],
          ),
        ],
      ),
    );
  }
}

class _HospitalCard extends StatelessWidget {
  final Map<String, dynamic> hospital;
  const _HospitalCard({required this.hospital});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 1),
            child: const Icon(Icons.local_hospital, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(hospital['name'] ?? 'Hospital', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            if (hospital['type'] != null)
              Text(hospital['type'], style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7))),
            if (hospital['region'] != null)
              Text(hospital['region'], style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7))),
          ])),
        ]),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}
