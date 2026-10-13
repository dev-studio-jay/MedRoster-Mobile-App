// Flexible vs Hardened modes for on-ground Ghana guidelines.

const ruleModeKeys = [
  'seniorCoverage',
  'consecutiveNights',
  'consecutiveDays',
  'weeklyHours',
  'dailyRest',
  'weeklyRest',
  'offDayTarget',
];

class RuleModeDef {
  final String key;
  final String label;
  final String hint;
  const RuleModeDef({required this.key, required this.label, required this.hint});
}

const ruleModeDefs = [
  RuleModeDef(
    key: 'seniorCoverage',
    label: 'Senior / in-charge on Morning, Afternoon, Night',
    hint: 'Prefer at least one senior or in-charge on each coverage shift.',
  ),
  RuleModeDef(
    key: 'consecutiveNights',
    label: 'Max nights in a row',
    hint: 'Default cap is 3; wards often stretch this by agreement.',
  ),
  RuleModeDef(
    key: 'consecutiveDays',
    label: 'Max days in a row',
    hint: 'Default cap is 6 consecutive duty days.',
  ),
  RuleModeDef(
    key: 'weeklyHours',
    label: 'Weekly hours target',
    hint: 'Hospital target (default 48h); Labour Act guideline is ~40h.',
  ),
  RuleModeDef(
    key: 'dailyRest',
    label: 'Rest between shifts (≥12h)',
    hint: 'Labour Act §41 — aim for 12 hours between duties.',
  ),
  RuleModeDef(
    key: 'weeklyRest',
    label: 'Weekly contiguous rest (~48h)',
    hint: 'Labour Act §42 — aim for 48 hours off in a 7-day window.',
  ),
  RuleModeDef(
    key: 'offDayTarget',
    label: 'Off-day target for the cycle',
    hint: 'Regular staff ~12 offs / month plus marked holidays.',
  ),
];

Map<String, String> getDefaultRuleModes() => {
      for (final k in ruleModeKeys) k: 'flexible',
    };

Map<String, String> normalizeRuleModes(dynamic raw) {
  final out = getDefaultRuleModes();
  if (raw is! Map) return out;
  for (final key in ruleModeKeys) {
    final v = raw[key]?.toString();
    if (v == 'hard' || v == 'flexible') out[key] = v!;
  }
  return out;
}

String resolveRuleMode(Map? settingsOrSchedule, String key) {
  final modes = normalizeRuleModes(settingsOrSchedule?['ruleModes']);
  return modes[key] == 'hard' ? 'hard' : 'flexible';
}

bool isRuleHard(Map? settingsOrSchedule, String key) =>
    resolveRuleMode(settingsOrSchedule, key) == 'hard';

String severityForRule(Map? settingsOrSchedule, String key) =>
    isRuleHard(settingsOrSchedule, key) ? 'error' : 'warning';
