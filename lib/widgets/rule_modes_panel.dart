import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../util/rule_modes.dart';

/// Flexible vs Hardened switches for on-ground Ghana guidelines.
class RuleModesPanel extends StatelessWidget {
  final Map<String, String> modes;
  final ValueChanged<Map<String, String>> onChanged;
  final String? title;
  final String? subtitle;

  const RuleModesPanel({
    super.key,
    required this.modes,
    required this.onChanged,
    this.title = 'How strict should these be?',
    this.subtitle =
        'Leave and personal restrictions always stay hard. These on-ground guidelines can be Flexible (warn only) or Hardened (block generate / show as errors).',
  });

  @override
  Widget build(BuildContext context) {
    final resolved = normalizeRuleModes(modes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null && title!.isNotEmpty) ...[
          Text(title!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w500, height: 1.35)),
          ],
          const SizedBox(height: 12),
        ],
        for (final def in ruleModeDefs) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(def.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 2),
                Text(def.hint, style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.3)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _ModeChip(
                      label: 'Flexible',
                      selected: resolved[def.key] != 'hard',
                      hardStyle: false,
                      onTap: () => onChanged({...resolved, def.key: 'flexible'}),
                    ),
                    const SizedBox(width: 8),
                    _ModeChip(
                      label: 'Hardened',
                      selected: resolved[def.key] == 'hard',
                      hardStyle: true,
                      onTap: () => onChanged({...resolved, def.key: 'hard'}),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool hardStyle;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.selected,
    required this.hardStyle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = !selected
        ? Colors.white
        : (hardStyle ? const Color(0xFFE85D4C) : AppColors.deep);
    final fg = selected ? Colors.white : AppColors.muted;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? bg : AppColors.border),
          ),
          child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: fg)),
        ),
      ),
    );
  }
}
