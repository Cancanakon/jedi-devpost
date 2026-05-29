import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/security_event.dart';
import '../providers/security_providers.dart';
import '../theme/jedi_theme.dart';

/// Left sidebar showing the security health gauge, stats cards, and recent
/// event summary list.
class JediAnalyticsPane extends ConsumerWidget {
  const JediAnalyticsPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthScore = ref.watch(healthScoreProvider);
    final totalScans  = ref.watch(totalScansProvider);
    final threats     = ref.watch(threatsInterceptedProvider);
    final events      = ref.watch(securityEventsProvider).valueOrNull ?? [];
    final recent5     = events.take(5).toList();

    return Container(
      width: JediTheme.leftPaneWidth,
      decoration: const BoxDecoration(
        color: JediTheme.surface,
        border: Border(
          right: BorderSide(color: JediTheme.surfaceBorder, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(JediTheme.spaceM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A) Security Health Gauge
            _HealthGaugeCard(healthScore: healthScore),
            const SizedBox(height: JediTheme.spaceM),

            // B) Stats Cards
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'TOTAL\nSCANS',
                    sublabel: 'LAST 24H',
                    value: totalScans,
                    color: JediTheme.primary,
                    icon: Icons.radar,
                  ),
                ),
                const SizedBox(width: JediTheme.spaceS),
                Expanded(
                  child: _StatCard(
                    label: 'THREATS\nBLOCKED',
                    sublabel: 'LAST 24H',
                    value: threats,
                    color: JediTheme.critical,
                    icon: Icons.shield_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: JediTheme.spaceL),

            // C) Recent events summary
            const _SectionLabel(label: 'RECENT ACTIVITY'),
            const SizedBox(height: JediTheme.spaceS),
            ...recent5.map((e) => _RecentEventRow(event: e)),
            if (recent5.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: JediTheme.spaceM),
                child: Center(
                  child: Text(
                    'No events yet',
                    style: JediTheme.bodyStyle(
                      fontSize: 13,
                      color: JediTheme.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Health Gauge Card ────────────────────────────────────────────────────

class _HealthGaugeCard extends StatefulWidget {
  const _HealthGaugeCard({required this.healthScore});
  final double healthScore;

  @override
  State<_HealthGaugeCard> createState() => _HealthGaugeCardState();
}

class _HealthGaugeCardState extends State<_HealthGaugeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousScore = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(begin: 0, end: widget.healthScore).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
    _previousScore = widget.healthScore;
  }

  @override
  void didUpdateWidget(_HealthGaugeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.healthScore != widget.healthScore) {
      _animation = Tween<double>(
        begin: _previousScore,
        end: widget.healthScore,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _controller
        ..reset()
        ..forward();
      _previousScore = widget.healthScore;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ModernCard(
      child: Padding(
        padding: const EdgeInsets.all(JediTheme.spaceM),
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            final score = _animation.value;
            final color = JediTheme.healthColor(score);
            final pct   = (score * 100).round();
            final label = score >= 0.8
                ? 'PROTECTED'
                : score >= 0.5
                    ? 'ELEVATED RISK'
                    : 'CRITICAL RISK';

            return Column(
              children: [
                SizedBox(
                  height: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Gauge Background
                      PieChart(
                        PieChartData(
                          startDegreeOffset: 180,
                          sectionsSpace: 0,
                          centerSpaceRadius: 60,
                          sections: [
                            PieChartSectionData(
                              value: 100,
                              color: JediTheme.background,
                              radius: 12,
                              showTitle: false,
                            ),
                          ],
                        ),
                      ),
                      // Gauge Value
                      PieChart(
                        PieChartData(
                          startDegreeOffset: 180,
                          sectionsSpace: 0,
                          centerSpaceRadius: 60,
                          sections: [
                            PieChartSectionData(
                              value: (score * 100).clamp(0, 100),
                              color: color,
                              radius: 16,
                              showTitle: false,
                            ),
                            PieChartSectionData(
                              value: ((1 - score) * 100).clamp(0, 100),
                              color: Colors.transparent,
                              radius: 16,
                              showTitle: false,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$pct%',
                            style: JediTheme.monoStyle(
                              fontSize: 36,
                              color: JediTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withAlpha(25),
                              borderRadius: BorderRadius.circular(JediTheme.radiusS),
                            ),
                            child: Text(
                              label,
                              style: JediTheme.bodyStyle(
                                fontSize: 10,
                                color: color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  'SYSTEM HEALTH',
                  style: JediTheme.bodyStyle(
                    fontSize: 12,
                    color: JediTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.sublabel,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String sublabel;
  final int    value;
  final Color  color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _ModernCard(
      child: Padding(
        padding: const EdgeInsets.all(JediTheme.spaceM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(icon, color: color, size: 14),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: JediTheme.bodyStyle(
                      fontSize: 10,
                      color: JediTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: JediTheme.spaceS),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, animation) => SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.5),
                  end: Offset.zero,
                ).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Text(
                '$value',
                key: ValueKey(value),
                style: JediTheme.monoStyle(
                  fontSize: 28,
                  color: JediTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: JediTheme.bodyStyle(
                fontSize: 9,
                color: JediTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Recent Event Row ─────────────────────────────────────────────────────

class _RecentEventRow extends StatelessWidget {
  const _RecentEventRow({required this.event});

  final SecurityEvent event;

  @override
  Widget build(BuildContext context) {
    final color = JediTheme.threatLevelColor(event.threatLevel);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: JediTheme.spaceS),
          Expanded(
            child: Text(
              event.shortRepoName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: JediTheme.bodyStyle(
                fontSize: 13,
                color: JediTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: JediTheme.spaceXS),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${(event.riskScore * 100).toStringAsFixed(0)}%',
              style: JediTheme.monoStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Label ────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: JediTheme.bodyStyle(
          fontSize: 12,
          color: JediTheme.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── Modern Card ──────────────────────────────────────────────────────────

/// Reusable card matching the Light Tech theme (clean white, subtle shadow).
class _ModernCard extends StatelessWidget {
  const _ModernCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: JediTheme.surface,
        borderRadius: BorderRadius.circular(JediTheme.radiusL),
        border: Border.all(color: JediTheme.surfaceBorder, width: 1),
        boxShadow: JediTheme.cardShadow,
      ),
      child: child,
    );
  }
}
