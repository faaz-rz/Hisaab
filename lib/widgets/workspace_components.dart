import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';

class PageHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  const PageHeading({required this.title, required this.subtitle, super.key});
  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 5),
          Text(subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary)),
        ],
      );
}

class MetricGrid extends StatelessWidget {
  final List<Widget> children;
  final int maxColumns;
  const MetricGrid({super.key, required this.children, this.maxColumns = 4});
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final columns =
            (constraints.maxWidth / 230).floor().clamp(1, maxColumns);
        final width = (constraints.maxWidth - 16 * (columns - 1)) / columns;
        return Wrap(spacing: 16, runSpacing: 16, children: [
          for (final child in children) SizedBox(width: width, child: child)
        ]);
      });
}

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? caption;
  final bool prominent;
  const MetricCard(
      {super.key,
      required this.label,
      required this.value,
      required this.icon,
      required this.color,
      this.caption,
      this.prominent = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: prominent ? AppColors.primary : AppColors.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: prominent ? AppColors.primary : AppColors.divider)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: prominent
                            ? Colors.white70
                            : AppColors.textSecondary))),
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: prominent
                        ? Colors.white.withValues(alpha: .1)
                        : color.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon,
                    size: 18,
                    color: prominent ? AppColors.accentLight : color)),
          ]),
          const SizedBox(height: 18),
          FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.8,
                      color: prominent ? Colors.white : AppColors.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()]))),
          if (caption != null) ...[
            const SizedBox(height: 8),
            Text(caption!,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color:
                        prominent ? Colors.white70 : AppColors.textSecondary)),
          ],
        ]),
      );
}

class SectionHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  const SectionHeading(this.title, {super.key, this.subtitle, this.action});
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!,
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textSecondary))
          ],
        ])),
        if (action != null) action!,
      ]);
}

/// Stacks summary actions on narrow screens without hiding an existing action.
class AdaptiveSummaryRow extends StatelessWidget {
  final Widget summary;
  final Widget actions;
  const AdaptiveSummaryRow(
      {super.key, required this.summary, required this.actions});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 540
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [summary, const SizedBox(height: 16), actions])
          : Row(children: [
              Expanded(child: summary),
              const SizedBox(width: 20),
              actions
            ]));
}
