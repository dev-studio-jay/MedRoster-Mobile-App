import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const _guestKey = 'medroster_guest_schedule';
const _exportKey = 'medroster_guest_exports';
const maxGuestExports = 10;

Future<Map<String, dynamic>?> getGuestSchedule() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_guestKey);
  if (raw == null || raw.isEmpty) return null;
  try {
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  } catch (_) {
    return null;
  }
}

Future<void> saveGuestSchedule(Map<String, dynamic> data) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _guestKey,
    jsonEncode({
      ...data,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    }),
  );
}

Future<void> clearGuestSchedule() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_guestKey);
}

Future<int> getGuestExportsRemaining() async {
  final prefs = await SharedPreferences.getInstance();
  final used = prefs.getInt(_exportKey) ?? 0;
  return (maxGuestExports - used).clamp(0, maxGuestExports);
}

Future<bool> consumeGuestExport() async {
  final prefs = await SharedPreferences.getInstance();
  final used = prefs.getInt(_exportKey) ?? 0;
  if (used >= maxGuestExports) return false;
  await prefs.setInt(_exportKey, used + 1);
  return true;
}

/// Pull guest data for migration after register, then clear local copy.
Future<Map<String, dynamic>?> takeGuestDataForMigration() async {
  final data = await getGuestSchedule();
  await clearGuestSchedule();
  return data;
}

Map<String, dynamic> defaultMonthSchedule({String wardName = 'My Ward'}) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  final end = DateTime(now.year, now.month + 1, 0);
  final name = _monthYear(start);
  return {
    'startDate': _ymd(start),
    'endDate': _ymd(end),
    'name': name,
    'wardName': wardName,
    'staff': <Map<String, dynamic>>[],
    'assignments': <Map<String, dynamic>>[],
    'holidays': <Map<String, dynamic>>[],
  };
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _monthYear(DateTime d) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${months[d.month - 1]} ${d.year}';
}
