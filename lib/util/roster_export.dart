import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'dates.dart';
import 'roster_setup.dart';

const dayShort = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

const shiftCode = {
  'Morning': 'M',
  'Afternoon': 'A',
  'Night': 'N',
  'SOD': 'SOD',
  'Office': 'OFC',
};

const rankAbbr = {
  'Assistant Midwifery Principal': 'AMPS',
  'Principal Midwifery Officer': 'PMO',
  'Senior Midwifery Officer': 'SMO',
  'Midwifery Officer': 'MO',
  'Senior Staff Midwife': 'SSM',
  'Staff Midwife': 'SM',
  'Registered Midwife': 'RM',
  'Deputy Director of Nursing Services': 'DDNS',
  'Director of Nursing Services': 'DNS',
  'Principal Nursing Officer': 'PNO',
  'Senior Nursing Officer': 'SNO',
  'Nursing Officer': 'NO',
  'Senior Staff Nurse': 'SSN',
  'Staff Nurse': 'SN',
  'Enrolled Nurse': 'EN',
  'Nurse Assistant Clinical': 'NAC',
  'Nurse Assistant Preventive': 'NAP',
  'Senior Medical Officer': 'SMO',
  'Medical Officer': 'MO',
  'House Officer': 'HO',
  'Specialist': 'Spec',
  'Senior Specialist': 'SSpec',
  'Consultant': 'Cons',
  'Senior Consultant': 'SCons',
  'Physician Assistant': 'PA',
  'Senior Physician Assistant': 'SPA',
  'Community Health Nurse': 'CHN',
  'Community Health Nursing Officer': 'CHNO',
};

String getRankAbbr(String? rank) => rankAbbr[rank] ?? rank ?? '';

String getShiftCode(String shiftName, [List? legend]) {
  if (shiftName.isEmpty) return '';
  final preferred = preferredSourceCode(shiftName, legend);
  if (preferred.isNotEmpty) return preferred;
  return shiftCode[shiftName] ?? (shiftName.isNotEmpty ? shiftName[0].toUpperCase() : '');
}

String displayCodeForAssignment(Map assignment, [List? legend]) {
  final raw = (assignment['sourceCode'] ?? '').toString().trim();
  if (raw.isNotEmpty) return raw;
  final name = assignment['shiftType'] is Map
      ? (assignment['shiftType'] as Map)['name']?.toString() ?? ''
      : '';
  return getShiftCode(name, legend);
}

class RosterExportModel {
  final String title;
  final String hospitalName;
  final String fileBase;
  final List<DateTime> days;
  final List<String> dayHeaders;
  final List<bool> holidayFlags;
  final List<Map<String, dynamic>> staffRows;
  final List<Map<String, dynamic>> summaryRows;
  final List<Map<String, String>> legend;

  RosterExportModel({
    required this.title,
    required this.hospitalName,
    required this.fileBase,
    required this.days,
    required this.dayHeaders,
    required this.holidayFlags,
    required this.staffRows,
    required this.summaryRows,
    required this.legend,
  });
}

RosterExportModel buildRosterExportModel({
  required Map schedule,
  required Map hospital,
  Map? ward,
  required List staff,
  required List assignments,
  Map? rosterSetup,
}) {
  final setup = rosterSetup ?? schedule['rosterSetup'] ?? ward?['rosterSetup'];
  final legendEntries = setup is Map && setup['legend'] is List ? List.from(setup['legend'] as List) : <dynamic>[];

  final days = buildCycle(schedule['startDate'], schedule['endDate']);
  final holidaySet = <String>{
    for (final h in (schedule['holidays'] as List? ?? []))
      dateKeyAny(h is Map ? h['date'] ?? h : h),
  };

  final assignMap = <String, Map>{};
  for (final a in assignments) {
    if (a is! Map) continue;
    assignMap['${a['staffId']}_${dateKeyAny(a['date'])}'] = Map<String, dynamic>.from(a);
  }

  final start = parseDate(schedule['startDate']) ?? DateTime.now();
  final monthLabel = DateFormat('MMMM yyyy').format(start).toUpperCase();
  final wardLabel = (ward?['name'] ?? 'WARD').toString().toUpperCase();
  final title = '$wardLabel DUTY ROSTER, $monthLabel';
  final hospitalName = hospital['name']?.toString() ?? '';
  final fileBase = '${wardLabel.replaceAll(RegExp(r'\s+'), '_')}_Roster_${monthLabel.replaceAll(RegExp(r'\s+'), '_')}';

  final dayHeadersFixed = days.map((d) {
    final isH = holidaySet.contains(dateKey(d));
    final idx = d.weekday % 7; // Sun=0 with %7? Mon=1 → 1, Sun=7 → 0
    final short = dayShort[idx];
    return '$short ${d.day}${isH ? ' H' : ''}';
  }).toList();

  final usedCodes = <String>{};

  String cellFor(Map s, DateTime d) {
    final dk = dateKey(d);
    final isH = holidaySet.contains(dk);
    if (leaveCovers(Map<String, dynamic>.from(s), d)) {
      usedCodes.add('LV');
      return 'LV';
    }
    final a = assignMap['${s['_id']}_$dk'];
    if (isH && a == null) {
      usedCodes.add('H');
      return 'H';
    }
    if (a != null) {
      final code = displayCodeForAssignment(a, legendEntries);
      usedCodes.add(code);
      return code;
    }
    usedCodes.add('O');
    return 'O';
  }

  final staffMaps = staff.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  staffMaps.sort((a, b) {
    final na = '${a['lastName'] ?? ''} ${a['firstName'] ?? ''}';
    final nb = '${b['lastName'] ?? ''} ${b['firstName'] ?? ''}';
    return na.compareTo(nb);
  });

  final staffRows = <Map<String, dynamic>>[];
  for (var i = 0; i < staffMaps.length; i++) {
    final s = staffMaps[i];
    staffRows.add({
      'no': i + 1,
      'name': '${s['firstName'] ?? ''} ${s['lastName'] ?? ''}'.trim(),
      'rank': getRankAbbr(s['rank']?.toString() ?? s['category']?.toString()),
      'cells': days.map((d) => cellFor(s, d)).toList(),
      'isRotation': s['isRotation'] == true,
    });
  }

  final summaryRows = <Map<String, dynamic>>[];
  for (final shiftName in ['Morning', 'Afternoon', 'Night', 'SOD', 'Office']) {
    final code = getShiftCode(shiftName, legendEntries);
    var hasAny = false;
    final counts = days.map((d) {
      final dk = dateKey(d);
      var count = 0;
      for (final s in staffMaps) {
        final a = assignMap['${s['_id']}_$dk'];
        if (a != null && a['shiftType'] is Map && (a['shiftType'] as Map)['name'] == shiftName) {
          count++;
        }
      }
      if (count > 0) hasAny = true;
      return count > 0 ? count : '';
    }).toList();
    if (hasAny) summaryRows.add({'code': code, 'shiftName': shiftName, 'counts': counts});
  }

  final legend = <Map<String, String>>[];
  final setupLegend = legendEntries.whereType<Map>().where((e) {
    final m = e['meaning']?.toString() ?? '';
    return m.isNotEmpty && m != 'skip' && normalizeLabel(e['label'] ?? e['code']).isNotEmpty;
  });
  if (setupLegend.isNotEmpty) {
    for (final e in setupLegend) {
      legend.add({
        'code': (e['label'] ?? e['code']).toString().trim(),
        'meaning': e['meaning']?.toString() ?? '',
      });
    }
    for (final fb in [
      {'code': 'O', 'meaning': 'Off / rest day'},
      {'code': 'H', 'meaning': 'Public holiday'},
      {'code': 'LV', 'meaning': 'Approved leave'},
    ]) {
      if (!legend.any((r) => r['code']!.toUpperCase() == fb['code'])) {
        legend.add(Map<String, String>.from(fb));
      }
    }
  } else {
    legend.addAll([
      {'code': 'M', 'meaning': 'Morning cover shift'},
      {'code': 'A', 'meaning': 'Afternoon cover shift'},
      {'code': 'N', 'meaning': 'Night cover shift'},
      {'code': 'SOD', 'meaning': 'Special / SOD duty'},
      {'code': 'OFC', 'meaning': 'Clinic / OPD'},
      {'code': 'O', 'meaning': 'Off / rest day'},
      {'code': 'H', 'meaning': 'Public holiday'},
      {'code': 'LV', 'meaning': 'Approved leave'},
    ]);
  }

  return RosterExportModel(
    title: title,
    hospitalName: hospitalName,
    fileBase: fileBase,
    days: days,
    dayHeaders: dayHeadersFixed,
    holidayFlags: days.map((d) => holidaySet.contains(dateKey(d))).toList(),
    staffRows: staffRows,
    summaryRows: summaryRows,
    legend: legend,
  );
}

String _escapeCsv(Object? value) {
  final s = value?.toString() ?? '';
  if (RegExp(r'[",\n\r]').hasMatch(s)) return '"${s.replaceAll('"', '""')}"';
  return s;
}

List<List<dynamic>> _buildAoa(RosterExportModel model) {
  final header = ['NO', 'NAME', 'RANK', ...model.dayHeaders];
  final rows = <List<dynamic>>[header];
  var rotationBanner = false;
  for (final row in model.staffRows) {
    if (row['isRotation'] == true && !rotationBanner) {
      rows.add(['', 'ROTATION', '', ...model.dayHeaders.map((_) => '')]);
      rotationBanner = true;
    }
    rows.add([row['no'], row['name'], row['rank'], ...(row['cells'] as List)]);
  }
  for (final sum in model.summaryRows) {
    rows.add(['', sum['code'], '', ...(sum['counts'] as List)]);
  }
  rows.add([]);
  rows.add(['LEGEND', 'Meaning']);
  for (final item in model.legend) {
    rows.add([item['code'], item['meaning']]);
  }
  return rows;
}

Future<void> shareRosterCsv(RosterExportModel model) async {
  final aoa = _buildAoa(model);
  final text = [
    _escapeCsv(model.title),
    if (model.hospitalName.isNotEmpty) _escapeCsv(model.hospitalName),
    '',
    ...aoa.map((r) => r.map(_escapeCsv).join(',')),
  ].join('\r\n');
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/${model.fileBase}.csv');
  await file.writeAsString(text);
  await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: model.title));
}

Future<void> shareRosterExcel(RosterExportModel model) async {
  final excel = Excel.createExcel();
  final sheet = excel['Duty Roster'];
  excel.delete('Sheet1');
  sheet.appendRow([TextCellValue(model.title)]);
  if (model.hospitalName.isNotEmpty) sheet.appendRow([TextCellValue(model.hospitalName)]);
  sheet.appendRow([]);
  for (final row in _buildAoa(model)) {
    sheet.appendRow(row.map((c) => TextCellValue(c?.toString() ?? '')).toList());
  }
  final bytes = excel.encode();
  if (bytes == null) throw Exception('Could not build Excel file');
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/${model.fileBase}.xlsx');
  await file.writeAsBytes(bytes);
  await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: model.title));
}

Future<void> shareRosterPdf(RosterExportModel model) async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(16),
      build: (ctx) => [
        pw.Center(
          child: pw.Text(model.title, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ),
        if (model.hospitalName.isNotEmpty)
          pw.Center(child: pw.Text(model.hospitalName, style: const pw.TextStyle(fontSize: 8))),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: ['NO', 'NAME', 'RANK', ...model.dayHeaders],
          data: [
            for (final row in model.staffRows)
              [row['no'], row['name'], row['rank'], ...(row['cells'] as List)],
          ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
          cellStyle: const pw.TextStyle(fontSize: 7),
          cellAlignments: {0: pw.Alignment.center, 2: pw.Alignment.center},
        ),
        pw.SizedBox(height: 10),
        pw.Text('LEGEND', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
        for (final item in model.legend)
          pw.Text('${item['code']}: ${item['meaning']}', style: const pw.TextStyle(fontSize: 8)),
      ],
    ),
  );
  final bytes = await doc.save();
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/${model.fileBase}.pdf');
  await file.writeAsBytes(Uint8List.fromList(bytes));
  await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: model.title));
}
