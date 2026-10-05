import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../util/org_units.dart';

class HospitalStore extends ChangeNotifier {
  HospitalStore._();
  static final instance = HospitalStore._();

  Map<String, dynamic>? hospital;
  bool loading = false;
  String? error;

  List<Map<String, dynamic>> get departments =>
      ApiService.instance.asMaps(hospital?['departments']);

  List<Map<String, dynamic>> get wards =>
      ApiService.instance.asMaps(hospital?['wards']);

  List<Map<String, dynamic>> get displayWards =>
      getDisplayWards(departments, wards);

  String? get hospitalId => hospital?['_id'] as String? ?? ApiService.instance.hospitalId;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await ApiService.instance.loadProfile();
      if (!ApiService.instance.hasHospital) {
        hospital = null;
        return;
      }
      final data = await ApiService.instance.get('/api/hospitals/${ApiService.instance.hospitalId}');
      final raw = Map<String, dynamic>.from(data as Map);
      final collapsed = collapseOrgUnits(
        ApiService.instance.asMaps(raw['departments']),
        ApiService.instance.asMaps(raw['wards']),
      );
      hospital = {
        ...raw,
        'departments': collapsed.departments,
        'wards': collapsed.wards,
      };
    } on ApiException catch (e) {
      error = e.message;
      hospital = null;
    } catch (e) {
      error = e.toString();
      hospital = null;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void clear() {
    hospital = null;
    error = null;
    loading = false;
    notifyListeners();
  }

  Map<String, dynamic>? wardById(String? id) {
    if (id == null) return null;
    for (final w in wards) {
      if (w['_id']?.toString() == id) return w;
    }
    return null;
  }

  Map<String, dynamic>? departmentById(String? id) {
    if (id == null) return null;
    for (final d in departments) {
      if (d['_id']?.toString() == id) return d;
    }
    return null;
  }
}
