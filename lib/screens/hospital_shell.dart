import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../state/hospital_store.dart';
import '../util/org_units.dart';
import '../widgets/error_view.dart';

class HospitalShell extends StatefulWidget {
  final Widget child;
  const HospitalShell({super.key, required this.child});

  @override
  State<HospitalShell> createState() => _HospitalShellState();
}

class _HospitalShellState extends State<HospitalShell> {
  final _store = HospitalStore.instance;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStore);
    if (_store.hospital == null && !_store.loading) {
      _store.load().then((_) => _maybeRedirect());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRedirect());
    }
  }

  @override
  void dispose() {
    _store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) {
      setState(() {});
      _maybeRedirect();
    }
  }

  void _maybeRedirect() {
    if (!mounted || _store.loading) return;
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc != '/') return;
    if (!ApiService.instance.hasHospital) return;
    if (_store.departments.isEmpty && ApiService.instance.canWrite) {
      context.go('/setup');
      return;
    }
    final list = _store.displayWards.isNotEmpty ? _store.displayWards : _store.wards;
    if (list.isNotEmpty) {
      context.go('/ward/${list.first['_id']}');
    } else {
      context.go('/wards');
    }
  }

  Future<void> _signOut() async {
    _store.clear();
    ApiService.instance.clearProfile();
    await AuthService.instance.signOut();
    if (mounted) context.go('/auth/login');
  }

  @override
  Widget build(BuildContext context) {
    if (_store.loading && _store.hospital == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_store.error != null && _store.hospital == null && ApiService.instance.hasHospital) {
      return Scaffold(body: ErrorView(message: _store.error!, onRetry: _store.load));
    }
    if (!ApiService.instance.hasHospital) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('MedRoster'),
          actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _signOut)],
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(ApiService.individualAppMessage, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final loc = GoRouterState.of(context).matchedLocation;
    final hideDrawer = loc.startsWith('/setup');

    return Scaffold(
      appBar: AppBar(
        title: Text(_store.hospital?['name']?.toString() ?? 'MedRoster'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Sign out', onPressed: _signOut),
        ],
      ),
      drawer: hideDrawer ? null : _WardDrawer(location: loc),
      body: widget.child,
    );
  }
}

class _WardDrawer extends StatelessWidget {
  final String location;
  const _WardDrawer({required this.location});

  @override
  Widget build(BuildContext context) {
    final store = HospitalStore.instance;
    final canWrite = ApiService.instance.canWrite;
    final isAdmin = ApiService.instance.isAdmin;
    final theme = Theme.of(context);
    final h = store.hospital ?? {};

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(h['name']?.toString() ?? 'Hospital', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  [h['type'], h['region']].where((e) => e != null && e.toString().isNotEmpty).join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ]),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('WARDS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: Colors.grey)),
            ),
            if (store.departments.isEmpty)
              const ListTile(dense: true, title: Text('No wards yet')),
            for (final dept in store.departments) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                child: Text(
                  dept['name']?.toString() ?? 'Department',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54),
                ),
              ),
              for (final ward in getDisplayWardsForDepartment(dept, store.wards))
                ListTile(
                  dense: true,
                  selected: location == '/ward/${ward['_id']}',
                  title: Text(ward['name']?.toString() ?? 'Ward'),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/ward/${ward['_id']}');
                  },
                ),
            ],
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('HOSPITAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: Colors.grey)),
            ),
            if (canWrite)
              ListTile(
                leading: const Icon(Icons.account_tree_outlined),
                selected: location == '/wards',
                title: const Text('Add / edit wards'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/wards');
                },
              ),
            if (isAdmin)
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                selected: location == '/settings',
                title: const Text('Settings'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/settings');
                },
              ),
          ],
        ),
      ),
    );
  }
}
