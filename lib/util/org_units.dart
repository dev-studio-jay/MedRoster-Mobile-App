String normalizeOrgName(dynamic value) {
  return value.toString().trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

class CollapsedOrg {
  final List<Map<String, dynamic>> departments;
  final List<Map<String, dynamic>> wards;
  CollapsedOrg(this.departments, this.wards);
}

CollapsedOrg collapseOrgUnits(
  List<Map<String, dynamic>> departments,
  List<Map<String, dynamic>> wards,
) {
  final byName = <String, Map<String, dynamic>>{};
  for (final department in departments) {
    final key = normalizeOrgName(department['name']);
    if (key.isEmpty) continue;
    final existing = byName[key];
    if (existing == null) {
      byName[key] = {
        ...department,
        '_aliasIds': [department['_id'].toString()],
      };
      continue;
    }
    (existing['_aliasIds'] as List).add(department['_id'].toString());
  }

  final collapsedDepartments = byName.values.toList();
  final departmentIdMap = <String, String>{};
  for (final department in collapsedDepartments) {
    for (final id in department['_aliasIds'] as List) {
      departmentIdMap[id.toString()] = department['_id'].toString();
    }
  }

  final remappedWards = wards
      .map((ward) => {
            ...ward,
            'departmentId': departmentIdMap[ward['departmentId']?.toString()] ?? ward['departmentId'],
          })
      .toList();

  final seenWards = <String>{};
  final collapsedWards = <Map<String, dynamic>>[];
  for (final ward in remappedWards) {
    final key = '${ward['departmentId']}::${normalizeOrgName(ward['name'])}';
    if (seenWards.contains(key)) continue;
    seenWards.add(key);
    collapsedWards.add(ward);
  }

  return CollapsedOrg(collapsedDepartments, collapsedWards);
}

List<Map<String, dynamic>> getDisplayWardsForDepartment(
  Map<String, dynamic> department,
  List<Map<String, dynamic>> wards,
) {
  final departmentWards = wards
      .where((ward) => ward['departmentId']?.toString() == department['_id']?.toString())
      .toList();
  final realWards = departmentWards
      .where((ward) => normalizeOrgName(ward['name']) != normalizeOrgName(department['name']))
      .toList();
  return realWards.isNotEmpty ? realWards : departmentWards;
}

List<Map<String, dynamic>> getDisplayWards(
  List<Map<String, dynamic>> departments,
  List<Map<String, dynamic>> wards,
) {
  return wards.where((ward) {
    Map<String, dynamic>? department;
    for (final d in departments) {
      if (d['_id']?.toString() == ward['departmentId']?.toString()) {
        department = d;
        break;
      }
    }
    final dept = department;
    if (dept == null) return true;
    final departmentWards = wards
        .where((w) => w['departmentId']?.toString() == dept['_id']?.toString())
        .toList();
    final hasRealWards = departmentWards.any(
      (w) => normalizeOrgName(w['name']) != normalizeOrgName(dept['name']),
    );
    return !hasRealWards || normalizeOrgName(ward['name']) != normalizeOrgName(dept['name']);
  }).toList();
}
