import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/api_service.dart';
import '../state/hospital_store.dart';
import '../widgets/error_view.dart';
import 'staff_form_screen.dart';

/// Router-friendly wrapper that loads hospital context for staff create/edit.
class StaffFormRoute extends StatefulWidget {
  final String wardId;
  final String? staffId;

  const StaffFormRoute({super.key, required this.wardId, this.staffId});

  @override
  State<StaffFormRoute> createState() => _StaffFormRouteState();
}

class _StaffFormRouteState extends State<StaffFormRoute> {
  Map<String, dynamic>? _staff;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final store = HospitalStore.instance;
      if (store.hospital == null) await store.load();
      final hid = store.hospitalId ?? ApiService.instance.hospitalId;
      if (hid == null) {
        setState(() => _error = 'No hospital loaded');
        return;
      }
      Map<String, dynamic>? staff;
      if (widget.staffId != null && widget.staffId!.isNotEmpty) {
        final data = await ApiService.instance.get('/api/hospitals/$hid/staff/${widget.staffId}');
        staff = Map<String, dynamic>.from(data as Map);
      }
      if (!mounted) return;
      setState(() {
        _staff = staff;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null && _staff == null && widget.staffId != null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorView(message: _error!, onRetry: _load),
      );
    }

    final store = HospitalStore.instance;
    final hid = store.hospitalId ?? ApiService.instance.hospitalId;
    final ward = store.wardById(widget.wardId);
    if (hid == null || ward == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          message: 'Ward not found',
          onRetry: () => context.go('/'),
        ),
      );
    }

    return StaffFormScreen(
      hospitalId: hid,
      departments: store.departments,
      wards: store.wards,
      staff: _staff,
      defaultDepartmentId: ward['departmentId']?.toString(),
      defaultWardId: widget.wardId,
    );
  }
}
