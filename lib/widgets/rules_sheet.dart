import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

const ruleGroups = [
  (
    title: 'Hard rules',
    items: [
      'Staff on approved leave cannot be assigned.',
      'No-night and maternity night flags block night duty (Labour Act §55 for protected workers).',
      'In-charge and assistant: weekday mornings only; off on weekends and marked holidays.',
      'Only-morning, only-afternoon, and weekday-only switches are hard personal restrictions.',
    ],
  ),
  (
    title: 'Ghana guidelines (Flexible or Hardened)',
    items: [
      'Prefer at least one senior or in-charge on Morning, Afternoon, and Night.',
      'SOD counts toward day-side senior presence.',
      'Labour Act guideline: ~40h/week; hospital target defaults to 48h for Ghana practice.',
      'Labour Act §41: aim for ≥12h rest between shifts.',
      'Labour Act §42: aim for 48h contiguous rest in a 7-day window.',
      'At setup (or in settings) choose Flexible (warn only) or Hardened (enforce) for each guideline.',
    ],
  ),
  (
    title: 'Shifts',
    items: [
      'Morning is 8:00 AM to 2:00 PM.',
      'Afternoon is 2:00 PM to 8:00 PM.',
      'Night is 8:00 PM to 8:00 AM.',
      'SOD (Supervisor on Duty) is 8:00 AM to 8:00 PM.',
    ],
  ),
  (
    title: 'Leave, rest, preferences',
    items: [
      'Study leave means no weekend shifts.',
      'Marked cycle holidays add to regular staff off-day targets.',
      'Regular staff target ~12 off days in a 30/31-day cycle, plus marked holidays.',
      'Night shifts are capped at 3 by default; a fourth night is a caution warning.',
      'Preferred off days and preferred shifts are soft sort keys only.',
    ],
  ),
];

Future<void> showRulesSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) => SafeArea(
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text('Rules', style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              'Hard personal restrictions vs Ghana guidelines you can set Flexible or Hardened at setup.',
              style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w500, fontSize: 13),
            ),
            const SizedBox(height: 16),
            for (final group in ruleGroups) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(height: 8),
                    for (final item in group.items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('·  ', style: TextStyle(fontWeight: FontWeight.w800)),
                            Expanded(
                              child: Text(
                                item,
                                style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.muted, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
