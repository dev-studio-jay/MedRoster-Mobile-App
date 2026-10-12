// Port of frontend/src/lib/roster-setup.js — legend/role proposal + remap.

const legendMeaningOptions = [
  {'value': 'Morning', 'label': 'Morning', 'group': 'On duty'},
  {'value': 'Afternoon', 'label': 'Afternoon', 'group': 'On duty'},
  {'value': 'Night', 'label': 'Night', 'group': 'On duty'},
  {'value': 'SOD', 'label': 'SOD', 'group': 'On duty'},
  {'value': 'Office', 'label': 'Clinic / OPD', 'group': 'On duty'},
  {'value': 'Off', 'label': 'Off', 'group': 'Not on duty'},
  {'value': 'Holiday', 'label': 'Holiday', 'group': 'Not on duty'},
  {'value': 'Leave', 'label': 'Leave', 'group': 'Not on duty'},
];

const legendMeanings = [
  'Morning',
  'Afternoon',
  'Night',
  'SOD',
  'Office',
  'Off',
  'Holiday',
  'Leave',
];

const coverShifts = ['Morning', 'Afternoon', 'Night'];
const onDutyMeanings = ['Morning', 'Afternoon', 'Night', 'SOD', 'Office'];
const officeDayKeys = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const defaultOfficeDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

const knownLabelMeaning = {
  'M': 'Morning',
  'A': 'Afternoon',
  'N': 'Night',
  'O': 'Off',
  'H': 'Holiday',
  'L': 'Leave',
  'LV': 'Leave',
  'SOD': 'SOD',
  'OFC': 'Office',
  'OFFICE': 'Office',
  'XM': 'Morning',
  'XA': 'Afternoon',
  'XN': 'Night',
  'PM': 'Morning',
  'PA': 'Afternoon',
  'PN': 'Night',
  'OFF': 'Off',
  'P': '',
};

const genericSourceCodes = {'M', 'A', 'N', 'O', 'H', 'SOD', 'OFC', 'LV', 'OFFICE'};

String normalizeLabel(dynamic raw) =>
    (raw?.toString() ?? '').trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

List<String> defaultDutyOverlaps(String meaning) {
  if (!onDutyMeanings.contains(meaning)) return [];
  if (meaning == 'Afternoon') return ['Afternoon'];
  if (meaning == 'Night') return ['Night'];
  return ['Morning'];
}

List<String> normalizeDutyOverlaps(dynamic raw, String meaning) {
  if (meaning == 'Office') {
    var list = raw is List ? raw.map((v) => v.toString().trim()).toList() : <String>[];
    list = list.where(coverShifts.contains).toList();
    if (!list.contains('Morning')) list = ['Morning', ...list];
    return coverShifts.where(list.contains).toList();
  }
  return defaultDutyOverlaps(meaning);
}

List<String> normalizeOfficeDays(dynamic raw, String meaning) {
  if (meaning != 'Office') return [];
  var list = raw is List ? raw.map((v) => v.toString().trim()).toList() : <String>[];
  list = list.where(officeDayKeys.contains).toList();
  if (list.isEmpty) return List<String>.from(defaultOfficeDays);
  return officeDayKeys.where(list.contains).toList();
}

String kindFromMeaning(String meaning) {
  if (meaning == 'Office') return 'clinic';
  if (['Morning', 'Afternoon', 'Night', 'SOD'].contains(meaning)) return 'ward';
  if (['Off', 'Holiday', 'Leave'].contains(meaning)) return 'off';
  return '';
}

String displayMeaningLabel(String meaning) {
  if (meaning.isEmpty) return '';
  for (final o in legendMeaningOptions) {
    if (o['value'] == meaning) return o['label']!;
  }
  return meaning;
}

String codePlainHint(String label) {
  final u = normalizeLabel(label);
  if (u == 'P' || u == 'OFC' || u == 'OFFICE') return 'Polyclinic X-ray · Clinic / OPD (8–2)';
  if (u == 'XM') return 'General X-ray · Morning';
  if (u == 'XA') return 'General X-ray · Afternoon';
  if (u == 'XN') return 'General X-ray · Night';
  if (u == 'PM') return 'Polyclinic · Morning';
  if (u == 'PA') return 'Polyclinic · Afternoon';
  if (u == 'PN') return 'Polyclinic · Night';
  if (u == 'M') return 'Morning (ward cover)';
  if (u == 'A') return 'Afternoon (ward cover)';
  if (u == 'N') return 'Night (ward cover)';
  return '';
}

bool looksLikeOfficeCode(String label, String unit) {
  if (label == 'P' || label == 'OFC' || label == 'OFFICE') return true;
  if (RegExp(r'polyclinic|antenatal', caseSensitive: false).hasMatch(unit) &&
      !RegExp(r'^X[MAN]$', caseSensitive: false).hasMatch(label)) {
    return true;
  }
  if (RegExp(r'office hours|office duty', caseSensitive: false).hasMatch(unit)) return true;
  return false;
}

String codeLetter(String meaning) {
  switch (meaning) {
    case 'Morning':
      return 'M';
    case 'Afternoon':
      return 'A';
    case 'Night':
      return 'N';
    case 'Off':
      return 'O';
    case 'Holiday':
      return 'H';
    case 'SOD':
      return 'SOD';
    case 'Office':
      return 'OFC';
    case 'Leave':
      return 'LV';
    default:
      return '';
  }
}

String preferredSourceCode(String meaning, [List? legend]) {
  final entries = (legend ?? [])
      .whereType<Map>()
      .where((e) => e['meaning'] == meaning && normalizeLabel(e['label'] ?? e['code']).isNotEmpty)
      .toList();
  if (entries.isEmpty) return codeLetter(meaning);
  final custom = entries.cast<Map>().where((e) => !genericSourceCodes.contains(normalizeLabel(e['label'] ?? e['code'])));
  final pick = custom.isNotEmpty ? custom.first : entries.first;
  return (pick['label'] ?? pick['code'] ?? '').toString().trim();
}

String unitFromLabel(String label) {
  final u = normalizeLabel(label);
  if (u.isEmpty) return '';
  if (u == 'P' || (u.startsWith('P') && u.length <= 3)) return 'Polyclinic X-ray';
  if (u.startsWith('X') && u.length >= 2) return 'General X-ray';
  return '';
}

String confidenceFor(String label, String meaning, bool fromSaved) {
  if (fromSaved) return 'high';
  if (meaning.isEmpty) return 'low';
  final known = knownLabelMeaning[normalizeLabel(label)];
  if (known != null && known == meaning) return 'high';
  return 'medium';
}

/// Propose legend + role guesses from an extract preview.
Map<String, dynamic> buildSetupProposal(Map<String, dynamic>? preview, [Map<String, dynamic>? savedSetup]) {
  final savedLegend = (savedSetup?['legend'] is List) ? List.from(savedSetup!['legend'] as List) : <dynamic>[];
  final savedByLabel = <String, Map>{
    for (final e in savedLegend.whereType<Map>()) normalizeLabel(e['label'] ?? e['code']): Map<String, dynamic>.from(e),
  };

  final labelCounts = <String, int>{};
  for (final s in (preview?['staff'] as List? ?? [])) {
    if (s is! Map) continue;
    for (final c in (s['cells'] as List? ?? [])) {
      if (c is! Map) continue;
      final label = normalizeLabel(c['text'] ?? c['code']);
      if (label.isEmpty) continue;
      labelCounts[label] = (labelCounts[label] ?? 0) + 1;
    }
  }

  final fileLegend = (preview?['legend'] is List) ? List.from(preview!['legend'] as List) : <dynamic>[];
  final fileByLabel = <String, Map>{
    for (final e in fileLegend.whereType<Map>()) normalizeLabel(e['label'] ?? e['code']): Map<String, dynamic>.from(e),
  };

  final sorted = labelCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final codes = sorted.map((entry) {
    final label = entry.key;
    final count = entry.value;
    final saved = savedByLabel[label];
    final fromFile = fileByLabel[label];
    var meaning = (saved?['meaning'] ?? fromFile?['meaning'] ?? knownLabelMeaning[label] ?? '').toString();
    var unit = (saved?['unit'] ?? fromFile?['unit'] ?? unitFromLabel(label)).toString();
    if (meaning.isNotEmpty && !legendMeanings.contains(meaning)) {
      if (unit.isEmpty) unit = meaning;
      meaning = knownLabelMeaning[label] ?? '';
    }
    if (saved == null && looksLikeOfficeCode(label, unit) && (meaning.isEmpty || !legendMeanings.contains(meaning))) {
      meaning = 'Office';
    }
    if (unit.isEmpty) unit = unitFromLabel(label);
    final dutyOverlaps = onDutyMeanings.contains(meaning) ? normalizeDutyOverlaps(saved?['dutyOverlaps'], meaning) : <String>[];
    final officeDays = meaning == 'Office' ? normalizeOfficeDays(saved?['officeDays'], meaning) : <String>[];
    final outsideMorning = meaning == 'Office' ? (saved?['outsideMorning'] == true) : false;
    final confidence = confidenceFor(label, meaning, saved != null);
    final compound = ['P', 'XM', 'XA', 'XN', 'PM', 'PA', 'PN'].contains(label);
    final needsConfirm = confidence != 'high' ||
        meaning.isEmpty ||
        (saved == null && (looksLikeOfficeCode(label, unit) || compound));
    return {
      'label': label,
      'count': count,
      'meaning': meaning,
      'unit': unit,
      'codeHint': codePlainHint(label),
      'legendNote': saved?['legendNote']?.toString() ?? '',
      'dutyKind': kindFromMeaning(meaning).isNotEmpty ? kindFromMeaning(meaning) : (saved?['dutyKind'] ?? ''),
      'dutyOverlaps': dutyOverlaps,
      'officeDays': officeDays,
      'outsideMorning': outsideMorning,
      'confidence': confidence,
      'needsConfirm': needsConfirm,
      'fromSaved': saved != null,
    };
  }).toList();

  final legendDraft = codes
      .map((c) => {
            'label': c['label'],
            'meaning': c['meaning'],
            'unit': c['unit'],
            'codeHint': c['codeHint'],
            'legendNote': c['legendNote'],
            'dutyKind': c['dutyKind'],
            'dutyOverlaps': c['dutyOverlaps'],
            'officeDays': c['officeDays'],
            'outsideMorning': c['outsideMorning'],
            'confidence': c['confidence'],
            'needsConfirm': c['needsConfirm'],
          })
      .toList();

  final staffList = preview?['staff'] as List? ?? [];
  final roleGuesses = <Map<String, dynamic>>[];
  for (var i = 0; i < staffList.length; i++) {
    final s = staffList[i];
    if (s is! Map) continue;
    final key = (s['key'] ?? s['no'] ?? s['_id'] ?? 'row-$i').toString();
    final name = '${s['firstName'] ?? ''} ${s['lastName'] ?? ''}'.trim();
    final cells = s['cells'] as List? ?? [];
    final leaveLikely = (s['leaveType'] != null && s['leaveType'].toString().isNotEmpty) ||
        (cells.isNotEmpty &&
            cells.every((c) =>
                c is Map && ['L', 'LV', 'Leave'].contains((c['code'] ?? c['text'] ?? '').toString())));
    roleGuesses.add({
      'key': key,
      'name': name.isNotEmpty ? name : (s['fullName']?.toString() ?? key),
      'rank': (s['rankFull'] ?? s['rank'] ?? '').toString(),
      'guessedRole': (s['wardRole'] ?? 'regular').toString(),
      'leaveType': s['leaveType']?.toString() ?? '',
      'leaveLikely': leaveLikely,
    });
  }

  final unknownCodes = codes.where((c) => c['needsConfirm'] == true).toList();
  final blanks = <Map<String, dynamic>>[];
  if (unknownCodes.isNotEmpty) {
    blanks.add({
      'type': 'legend',
      'message': '${unknownCodes.length} code${unknownCodes.length == 1 ? '' : 's'} need confirmation',
      'labels': unknownCodes.map((c) => c['label']).toList(),
    });
  }
  final hasIncharge = roleGuesses.any((r) => r['guessedRole'] == 'incharge');
  if ((savedSetup?['inchargeStaffKey'] == null || savedSetup!['inchargeStaffKey'].toString().isEmpty) && !hasIncharge) {
    blanks.add({'type': 'incharge', 'message': 'No ward in-charge marked — pick one if you can (tip only)'});
  }

  return {
    'codes': codes,
    'legendDraft': legendDraft,
    'roleGuesses': roleGuesses,
    'blanks': blanks,
    'savedSetup': savedSetup,
    'needsFullSetup': savedSetup?['confirmedAt'] == null || unknownCodes.isNotEmpty,
  };
}

Map<String, dynamic> applyRosterSetup(Map<String, dynamic> preview, Map<String, dynamic> setup) {
  final legend = (setup['legend'] is List) ? List.from(setup['legend'] as List) : <dynamic>[];
  final byLabel = <String, Map>{
    for (final e in legend.whereType<Map>()) normalizeLabel(e['label'] ?? e['code']): Map<String, dynamic>.from(e),
  };

  final staffIn = preview['staff'] as List? ?? [];
  final staff = <Map<String, dynamic>>[];
  for (var i = 0; i < staffIn.length; i++) {
    final s = Map<String, dynamic>.from(staffIn[i] as Map);
    final key = (s['key'] ?? s['no'] ?? s['_id'] ?? 'row-$i').toString();
    var wardRole = (s['wardRole'] ?? 'regular').toString();
    final inchargeKey = setup['inchargeStaffKey']?.toString() ?? '';
    final assistantKey = setup['assistantStaffKey']?.toString() ?? '';
    if (inchargeKey.isNotEmpty && inchargeKey == key) {
      wardRole = 'incharge';
    } else if (assistantKey.isNotEmpty && assistantKey == key) {
      wardRole = 'assistant';
    } else if (inchargeKey.isNotEmpty || assistantKey.isNotEmpty) {
      if (wardRole == 'incharge' || wardRole == 'assistant') wardRole = 'regular';
    }

    final leaveByKey = setup['leaveByKey'] is Map ? Map<String, dynamic>.from(setup['leaveByKey'] as Map) : <String, dynamic>{};
    final leaveOverride = leaveByKey[key] is Map ? Map<String, dynamic>.from(leaveByKey[key] as Map) : null;
    final leaveType = (leaveOverride?['leaveType'] ?? s['leaveType'] ?? '').toString();
    final onLeave = leaveOverride?['onLeave'] == true || leaveType.isNotEmpty;

    final cells = <Map<String, dynamic>>[];
    final assignments = <Map<String, dynamic>>[];
    for (final cellRaw in (s['cells'] as List? ?? [])) {
      if (cellRaw is! Map) continue;
      final cell = Map<String, dynamic>.from(cellRaw);
      final label = normalizeLabel(cell['text'] ?? cell['code']);
      final entry = byLabel[label];
      var meaning = (entry?['meaning'] ?? knownLabelMeaning[label] ?? '').toString();
      final unit = (entry?['unit'] ?? cell['unit'] ?? unitFromLabel(label)).toString();
      final dutyOverlaps = onDutyMeanings.contains(meaning) ? normalizeDutyOverlaps(entry?['dutyOverlaps'], meaning) : <String>[];
      final officeDays = meaning == 'Office' ? normalizeOfficeDays(entry?['officeDays'], meaning) : <String>[];
      final outsideMorning = meaning == 'Office' ? (entry?['outsideMorning'] == true) : false;
      final sourceLabel = label.isNotEmpty ? label : normalizeLabel(cell['code']);
      var resolvedMeaning = meaning;
      var code = sourceLabel.isNotEmpty ? sourceLabel : (codeLetter(meaning).isNotEmpty ? codeLetter(meaning) : (cell['code']?.toString() ?? ''));
      if (onLeave && (meaning.isEmpty || meaning == 'Leave')) {
        resolvedMeaning = 'Leave';
        code = sourceLabel.isNotEmpty ? sourceLabel : 'LV';
      } else if (code.isEmpty && meaning.isNotEmpty) {
        code = codeLetter(meaning);
      }
      final sod = resolvedMeaning == 'SOD' || cell['sod'] == true;
      final next = {
        'date': cell['date'],
        'text': cell['text'] ?? (sourceLabel.isNotEmpty ? sourceLabel : code),
        'code': code,
        'sod': sod,
        'unit': unit,
        'meaning': resolvedMeaning,
        'dutyOverlaps': dutyOverlaps,
        'officeDays': officeDays,
        'outsideMorning': outsideMorning,
      };
      cells.add(next);
      if (onDutyMeanings.contains(resolvedMeaning)) {
        assignments.add({
          'date': cell['date'],
          'code': code,
          'meaning': resolvedMeaning,
          'unit': unit,
          'sod': sod,
          'dutyOverlaps': dutyOverlaps,
          'officeDays': officeDays,
          'outsideMorning': outsideMorning,
        });
      }
    }

    String leaveNote = s['leaveNote']?.toString() ?? '';
    if (leaveType.isNotEmpty) {
      final t = leaveType.trim();
      leaveNote = RegExp(r'leave$', caseSensitive: false).hasMatch(t)
          ? '${t[0].toUpperCase()}${t.substring(1)}'
          : '${t[0].toUpperCase()}${t.substring(1)} leave';
    }

    staff.add({
      ...s,
      'key': key,
      'wardRole': wardRole,
      'leaveType': leaveType,
      'leaveNote': leaveNote,
      'cells': cells,
      'assignments': assignments,
      'selected': s['selected'] != false,
    });
  }

  return {
    ...preview,
    'staff': staff,
    'legend': legend.whereType<Map>().map((e) {
      final meaning = e['meaning']?.toString() ?? '';
      return {
        'label': e['label'],
        'meaning': meaning,
        'unit': e['unit'] ?? '',
        'legendNote': (e['legendNote'] ?? '').toString().trim(),
        'dutyKind': e['dutyKind'] ?? kindFromMeaning(meaning),
        'dutyOverlaps': onDutyMeanings.contains(meaning) ? normalizeDutyOverlaps(e['dutyOverlaps'], meaning) : [],
        'officeDays': meaning == 'Office' ? normalizeOfficeDays(e['officeDays'], meaning) : [],
        'outsideMorning': meaning == 'Office' && e['outsideMorning'] == true,
      };
    }).toList(),
    'setupApplied': true,
  };
}

Map<String, dynamic> buildRosterSetupPayload(Map<String, dynamic> setup) {
  final legend = (setup['legend'] is List) ? List.from(setup['legend'] as List) : <dynamic>[];
  return {
    'legend': legend.whereType<Map>().map((e) {
      final meaning = (e['meaning'] ?? '').toString().trim();
      return {
        'label': (e['label'] ?? '').toString().trim(),
        'meaning': meaning,
        'unit': (e['unit'] ?? '').toString().trim(),
        'legendNote': (e['legendNote'] ?? '').toString().trim(),
        'dutyKind': (e['dutyKind'] ?? kindFromMeaning(meaning)).toString().trim(),
        'dutyOverlaps': onDutyMeanings.contains(meaning) ? normalizeDutyOverlaps(e['dutyOverlaps'], meaning) : [],
        'officeDays': meaning == 'Office' ? normalizeOfficeDays(e['officeDays'], meaning) : [],
        'outsideMorning': meaning == 'Office' && e['outsideMorning'] == true,
      };
    }).toList(),
    'inchargeStaffKey': setup['inchargeStaffKey'] ?? '',
    'assistantStaffKey': setup['assistantStaffKey'] ?? '',
    'units': setup['units'] ?? {},
    'leaveByKey': setup['leaveByKey'] ?? {},
    'confirmedAt': DateTime.now().toUtc().toIso8601String(),
  };
}
