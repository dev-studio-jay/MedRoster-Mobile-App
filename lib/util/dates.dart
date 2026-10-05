import 'package:intl/intl.dart';

final _day = DateFormat('yyyy-MM-dd');
final _short = DateFormat('d MMM');
final _shortYear = DateFormat('d MMM y');
final _weekdayShort = DateFormat('E');
final _monthYear = DateFormat('MMMM y');

String dateKey(DateTime date) => _day.format(DateTime(date.year, date.month, date.day));

String dateKeyAny(dynamic value) {
  if (value == null) return '';
  if (value is DateTime) return dateKey(value);
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) return value.toString().split('T').first;
  return dateKey(parsed.toLocal());
}

DateTime? parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return DateTime(value.year, value.month, value.day);
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) return null;
  final local = parsed.toLocal();
  return DateTime(local.year, local.month, local.day);
}

({String startDate, String endDate, String label}) currentMonthRange() {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  final end = DateTime(now.year, now.month + 1, 0);
  return (
    startDate: dateKey(start),
    endDate: dateKey(end),
    label: _monthYear.format(start),
  );
}

String formatRange(dynamic start, dynamic end) {
  final s = parseDate(start);
  final e = parseDate(end);
  if (s == null || e == null) return '';
  return '${_short.format(s)} – ${_shortYear.format(e)}';
}

String weekdayShort(DateTime date) => _weekdayShort.format(date);

String dayNum(DateTime date) => date.day.toString();

List<DateTime> buildCycle(dynamic startDate, dynamic endDate) {
  final start = parseDate(startDate);
  final end = parseDate(endDate);
  if (start == null || end == null) return [];
  final days = <DateTime>[];
  var cur = start;
  while (!cur.isAfter(end)) {
    days.add(cur);
    cur = cur.add(const Duration(days: 1));
  }
  return days;
}

bool leaveCovers(Map<String, dynamic> staff, DateTime date) {
  final records = staff['leaveRecords'];
  if (records is! List) return false;
  final check = DateTime(date.year, date.month, date.day);
  for (final raw in records) {
    if (raw is! Map) continue;
    final rec = Map<String, dynamic>.from(raw);
    if (rec['status'] != null && rec['status'] != 'Approved') continue;
    final start = parseDate(rec['startDate']);
    final end = parseDate(rec['endDate']);
    if (start == null || end == null) continue;
    if (!check.isBefore(start) && !check.isAfter(end)) return true;
  }
  return false;
}
