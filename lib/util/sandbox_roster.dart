import 'dates.dart';
import 'roster_setup.dart';
import 'rule_modes.dart';

const defaultShiftTypes = [
  {'name': 'Morning', 'color': 'morning', 'startTime': '08:00', 'endTime': '14:00'},
  {'name': 'Afternoon', 'color': 'afternoon', 'startTime': '14:00', 'endTime': '20:00'},
  {'name': 'Night', 'color': 'night', 'startTime': '20:00', 'endTime': '08:00'},
  {'name': 'SOD', 'color': 'sod', 'startTime': '08:00', 'endTime': '20:00'},
  {'name': 'Office', 'color': 'office', 'startTime': '08:00', 'endTime': '14:00'},
];

const _codeToShift = {
  'M': 'Morning',
  'A': 'Afternoon',
  'N': 'Night',
  'SOD': 'SOD',
  'OFC': 'Office',
  'OFFICE': 'Office',
  'P': 'Office',
  'XM': 'Morning',
  'XA': 'Afternoon',
  'XN': 'Night',
  'PM': 'Morning',
  'PA': 'Afternoon',
  'PN': 'Night',
};

const onDutyNames = ['Morning', 'Afternoon', 'Night', 'SOD', 'Office'];
const coverNames = ['Morning', 'Afternoon', 'Night'];

List<Map<String, dynamic>> sandboxShiftTypes() {
  return defaultShiftTypes.map((st) {
    final id = (st['name'] as String).toLowerCase();
    return {...st, 'id': id, '_id': id};
  }).toList();
}

String classifyStaffType(String? rank) {
  if (rank == null || rank.isEmpty) return 'regular';
  final r = rank.toLowerCase();
  if (r.contains('principal') || r.contains('matron') || r.contains('director') || r.contains('chief')) {
    return 'pno';
  }
  if (r.contains('senior') ||
      r.contains('specialist') ||
      r.contains('consultant') ||
      r == 'nursing officer' ||
      r == 'midwifery officer' ||
      r == 'medical officer') {
    return 'senior';
  }
  return 'regular';
}

bool isSupervisory(Map staff) {
  final type = staff['staffType']?.toString() ?? classifyStaffType(staff['rank']?.toString());
  final role = staff['wardRole']?.toString();
  return type == 'senior' ||
      type == 'pno' ||
      role == 'incharge' ||
      role == 'assistant' ||
      role == 'shift_incharge';
}

Map<String, dynamic>? shiftTypeFromCode(List<Map<String, dynamic>> shiftTypes, String? code) {
  final raw = (code ?? '').trim();
  if (raw.isEmpty) return null;
  for (final st in shiftTypes) {
    if (st['name'] == raw || st['name'].toString().toLowerCase() == raw.toLowerCase()) return st;
  }
  final mapped = _codeToShift[raw.toUpperCase()];
  if (mapped == null) return null;
  for (final st in shiftTypes) {
    if (st['name'] == mapped) return st;
  }
  return null;
}

/// Map imported preview rows into calendar assignments.
List<Map<String, dynamic>> mapPreviewToAssignments(
  List staffRows, [
  List<Map<String, dynamic>>? shiftTypes,
]) {
  final types = shiftTypes ?? sandboxShiftTypes();
  final assignments = <Map<String, dynamic>>[];
  for (final row in staffRows) {
    if (row is! Map) continue;
    final staffId = row['_id'];
    if (staffId == null) continue;
    final fromAssignments = row['assignments'] is List ? List.from(row['assignments'] as List) : <dynamic>[];
    final fromCells = (row['cells'] as List? ?? [])
        .whereType<Map>()
        .where((c) {
          final meaning = c['meaning']?.toString() ?? '';
          final code = (c['code'] ?? '').toString().toUpperCase();
          return onDutyNames.contains(meaning) || _codeToShift.containsKey(code) || onDutyNames.contains(c['code']);
        })
        .map((c) => {
              'date': c['date'],
              'code': c['code'],
              'meaning': c['meaning'],
              'unit': c['unit'],
              'sod': c['sod'],
              'dutyOverlaps': c['dutyOverlaps'],
              'officeDays': c['officeDays'],
              'outsideMorning': c['outsideMorning'],
            })
        .toList();
    final list = fromAssignments.isNotEmpty ? fromAssignments : fromCells;
    for (final a in list) {
      if (a is! Map || a['date'] == null) continue;
      Map<String, dynamic>? byMeaning;
      if (onDutyNames.contains(a['meaning'])) {
        for (final st in types) {
          if (st['name'] == a['meaning']) {
            byMeaning = st;
            break;
          }
        }
      }
      final shift = a['sod'] == true
          ? shiftTypeFromCode(types, 'SOD')
          : (byMeaning ?? shiftTypeFromCode(types, a['code']?.toString()));
      if (shift == null) continue;
      final dk = dateKeyAny(a['date']);
      final dutyOverlaps = (a['dutyOverlaps'] is List && (a['dutyOverlaps'] as List).isNotEmpty)
          ? List<String>.from((a['dutyOverlaps'] as List).map((e) => e.toString()))
          : [
              shift['name'] == 'Afternoon'
                  ? 'Afternoon'
                  : shift['name'] == 'Night'
                      ? 'Night'
                      : 'Morning'
            ];
      final sourceCode = (a['code'] ?? '').toString().trim();
      assignments.add({
        '_id': 'a_${staffId}_$dk',
        'staffId': staffId,
        'date': '${dk}T00:00:00.000Z',
        if (sourceCode.isNotEmpty) 'sourceCode': sourceCode,
        'unit': a['unit'] ?? '',
        'dutyOverlaps': dutyOverlaps,
        'officeDays': a['officeDays'] ?? [],
        'outsideMorning': a['outsideMorning'] == true,
        'shiftType': {
          'name': shift['name'],
          'color': shift['color'],
          'startTime': shift['startTime'],
          'endTime': shift['endTime'],
          'dutyOverlaps': dutyOverlaps,
          'outsideMorning': a['outsideMorning'] == true,
        },
      });
    }
  }
  return assignments;
}

bool _canAssignCover(Map staff, DateTime day, Map shift, List holidays) {
  if ((staff['employmentStatus'] ?? 'Active') == 'On Leave') return false;
  if (leaveCovers(Map<String, dynamic>.from(staff), day)) return false;
  final role = staff['wardRole']?.toString() ?? 'regular';
  final name = shift['name']?.toString() ?? '';
  // In-charge / assistant: weekday mornings only, no nights
  if (role == 'incharge' || role == 'assistant') {
    if (name == 'Night') return false;
    if (name == 'Afternoon') return false;
    if (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) return false;
  }
  return true;
}

bool _dayHasCover(List assignments, String dk, String shiftName) {
  return assignments.any((a) {
    if (a is! Map) return false;
    if (dateKeyAny(a['date']) != dk) return false;
    final st = a['shiftType'];
    return st is Map && st['name'] == shiftName;
  });
}

Set<String> _staffTakenOnDay(List assignments, String dk) {
  return {
    for (final a in assignments)
      if (a is Map && dateKeyAny(a['date']) == dk) a['staffId'].toString(),
  };
}

({List<Map<String, dynamic>> slots, int fillableCount}) scanGeneratableSlots({
  required List staff,
  required dynamic startDate,
  required dynamic endDate,
  List<Map<String, dynamic>>? shiftTypes,
  List existing = const [],
  List holidays = const [],
}) {
  final types = shiftTypes ?? sandboxShiftTypes();
  final shifts = <Map<String, dynamic>>[];
  for (final name in coverNames) {
    for (final st in types) {
      if (st['name'] == name) {
        shifts.add(st);
        break;
      }
    }
  }
  final days = buildCycle(startDate, endDate);
  if (staff.isEmpty || shifts.isEmpty || days.isEmpty) {
    return (slots: <Map<String, dynamic>>[], fillableCount: 0);
  }
  final pool = staff.whereType<Map>().where((s) => (s['employmentStatus'] ?? 'Active') != 'On Leave').toList();
  final slots = <Map<String, dynamic>>[];
  for (final day in days) {
    final dk = dateKey(day);
    final taken = _staffTakenOnDay(existing, dk);
    for (final shift in shifts) {
      if (_dayHasCover(existing, dk, shift['name'].toString())) continue;
      final candidates = pool
          .where((s) => !taken.contains(s['_id'].toString()) && _canAssignCover(s, day, shift, holidays))
          .toList();
      if (candidates.isEmpty) continue;
      slots.add({'date': dk, 'shift': shift, 'candidates': candidates});
    }
  }
  return (slots: slots, fillableCount: slots.length);
}

int countGeneratableSlots({
  required List staff,
  required dynamic startDate,
  required dynamic endDate,
  List existing = const [],
  List holidays = const [],
}) {
  return scanGeneratableSlots(
    staff: staff,
    startDate: startDate,
    endDate: endDate,
    existing: existing,
    holidays: holidays,
  ).fillableCount;
}

List<Map<String, dynamic>> generateSandboxAssignments({
  required List staff,
  required dynamic startDate,
  required dynamic endDate,
  List<Map<String, dynamic>>? shiftTypes,
  List existing = const [],
  List holidays = const [],
  Map? rosterSetup,
  bool replace = false,
  Map? settings,
  Map? ruleModes,
}) {
  final types = shiftTypes ?? sandboxShiftTypes();
  final base = replace
      ? <Map<String, dynamic>>[]
      : existing.whereType<Map>().map((a) => Map<String, dynamic>.from(a)).toList();
  final scanned = scanGeneratableSlots(
    staff: staff,
    startDate: startDate,
    endDate: endDate,
    shiftTypes: types,
    existing: base,
    holidays: holidays,
  );
  if (scanned.slots.isEmpty) return base;

  final resolved = <String, dynamic>{
    ...(settings is Map ? Map<String, dynamic>.from(settings) : <String, dynamic>{}),
    'ruleModes': normalizeRuleModes(ruleModes ?? settings?['ruleModes']),
    'maxConsecutiveDays': settings?['maxConsecutiveDays'] ?? 6,
    'maxConsecutiveNights': settings?['maxConsecutiveNights'] ?? 3,
  };
  final maxConsecutive = (resolved['maxConsecutiveDays'] as num?)?.toInt() ?? 6;
  final maxNights = (resolved['maxConsecutiveNights'] as num?)?.toInt() ?? 3;
  final hardenDays = isRuleHard(resolved, 'consecutiveDays');
  final hardenNights = isRuleHard(resolved, 'consecutiveNights');

  final legend = rosterSetup is Map && rosterSetup['legend'] is List ? List.from(rosterSetup['legend'] as List) : <dynamic>[];
  final next = [...base];
  final counts = <String, int>{for (final s in staff.whereType<Map>()) s['_id'].toString(): 0};
  final consecutiveTracker = <String, int>{for (final s in staff.whereType<Map>()) s['_id'].toString(): 0};
  final consecutiveNightTracker = <String, int>{for (final s in staff.whereType<Map>()) s['_id'].toString(): 0};
  final lastWorkedDate = <String, DateTime>{};
  for (final a in next) {
    final id = a['staffId'].toString();
    counts[id] = (counts[id] ?? 0) + 1;
  }
  final seniors = staff.whereType<Map>().where(isSupervisory).toList();

  final byDay = <String, List<Map<String, dynamic>>>{};
  for (final slot in scanned.slots) {
    final dk = slot['date'].toString();
    byDay.putIfAbsent(dk, () => []).add(slot);
  }
  final sortedDays = byDay.keys.toList()..sort();

  for (final dk in sortedDays) {
    final daySlots = byDay[dk]!;
    final day = parseDate(dk)!;
    for (final entry in [...lastWorkedDate.entries]) {
      final diff = day.difference(entry.value).inDays;
      if (diff > 1) {
        consecutiveTracker[entry.key] = 0;
        consecutiveNightTracker[entry.key] = 0;
      }
    }

    final taken = _staffTakenOnDay(next, dk);
    final ordered = [...daySlots]..sort((a, b) {
        final an = (a['shift'] as Map)['name'];
        final bn = (b['shift'] as Map)['name'];
        if (an == 'Morning' && bn != 'Morning') return -1;
        if (bn == 'Morning' && an != 'Morning') return 1;
        return 0;
      });

    for (final slot in ordered) {
      final shift = Map<String, dynamic>.from(slot['shift'] as Map);
      if (_dayHasCover(next, dk, shift['name'].toString())) continue;
      final isNight = shift['name'] == 'Night';
      var candidates = (slot['candidates'] as List)
          .whereType<Map>()
          .where((s) => !taken.contains(s['_id'].toString()))
          .where((s) => _canAssignCover(s, day, shift, holidays))
          .toList();
      if (hardenDays) {
        candidates = candidates.where((s) => (consecutiveTracker[s['_id'].toString()] ?? 0) < maxConsecutive).toList();
      }
      if (hardenNights && isNight) {
        candidates = candidates.where((s) => (consecutiveNightTracker[s['_id'].toString()] ?? 0) < maxNights).toList();
      }
      if (candidates.isEmpty) continue;
      candidates.sort((a, b) {
        final soft = !hardenDays
            ? (consecutiveTracker[a['_id'].toString()] ?? 0).compareTo(consecutiveTracker[b['_id'].toString()] ?? 0)
            : 0;
        if (soft != 0) return soft;
        return (counts[a['_id'].toString()] ?? 0).compareTo(counts[b['_id'].toString()] ?? 0);
      });
      var pick = candidates.first;
      if (seniors.isNotEmpty) {
        final seniorPick = candidates.where((s) => seniors.any((x) => x['_id'].toString() == s['_id'].toString()));
        if (seniorPick.isNotEmpty) pick = seniorPick.first;
      }
      final sid = pick['_id'].toString();
      final sourceCode = preferredSourceCode(shift['name'].toString(), legend);
      next.add({
        '_id': 'a_${sid}_${dk}_${shift['name']}',
        'staffId': sid,
        'date': '${dk}T00:00:00.000Z',
        if (sourceCode.isNotEmpty) 'sourceCode': sourceCode,
        'dutyOverlaps': [shift['name']],
        'shiftType': {
          'name': shift['name'],
          'color': shift['color'],
          'startTime': shift['startTime'],
          'endTime': shift['endTime'],
          'dutyOverlaps': [shift['name']],
        },
      });
      taken.add(sid);
      counts[sid] = (counts[sid] ?? 0) + 1;
      consecutiveTracker[sid] = (consecutiveTracker[sid] ?? 0) + 1;
      if (isNight) {
        consecutiveNightTracker[sid] = (consecutiveNightTracker[sid] ?? 0) + 1;
      } else {
        consecutiveNightTracker[sid] = 0;
      }
      lastWorkedDate[sid] = day;
    }
  }
  return next;
}
