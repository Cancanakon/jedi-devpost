import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/jedi_theme.dart';

/// Top-level header bar for the JEDI Command Center.
class JediHeaderBar extends StatefulWidget {
  const JediHeaderBar({super.key});

  @override
  State<JediHeaderBar> createState() => _JediHeaderBarState();
}

class _JediHeaderBarState extends State<JediHeaderBar>
    with SingleTickerProviderStateMixin {
  late Timer _clockTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  String _timeString = '';

  @override
  void initState() {
    super.initState();
    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(_updateTime);
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _updateTime() {
    final now = DateTime.now();
    _timeString =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: JediTheme.headerHeight,
      decoration: BoxDecoration(
        color: JediTheme.surface,
        border: const Border(
          bottom: BorderSide(color: JediTheme.surfaceBorder, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: JediTheme.spaceL,
        ),
        child: Row(
          children: [
            // ── Logo + Title ─────────────────────────────────────────
            const Expanded(child: _LogoSection()),

            // ── Agent Online Status ──────────────────────────────────
            _AgentStatus(pulseAnimation: _pulseAnimation),

            const SizedBox(width: JediTheme.spaceL),

            // ── Live Clock ───────────────────────────────────────────
            Container(
              height: 36,
              width: 1,
              color: JediTheme.surfaceBorder,
            ),
            const SizedBox(width: JediTheme.spaceL),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _timeString,
                  style: JediTheme.monoStyle(
                    fontSize: 16,
                    color: JediTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'LOCAL TIME',
                  style: JediTheme.bodyStyle(
                    fontSize: 10,
                    color: JediTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────

class _LogoSection extends StatelessWidget {
  const _LogoSection();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Clean Tech Icon
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: JediTheme.primary,
            borderRadius: BorderRadius.circular(JediTheme.radiusM),
            boxShadow: [
              BoxShadow(
                color: JediTheme.primary.withAlpha(50),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.shield_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: JediTheme.spaceM),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'JEDI',
                style: JediTheme.bodyStyle(
                  fontSize: 18,
                  color: JediTheme.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'Just-in-time Execution & Defense Interface',
                style: JediTheme.bodyStyle(
                  fontSize: 11,
                  color: JediTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AgentStatus extends StatelessWidget {
  const _AgentStatus({required this.pulseAnimation});

  final Animation<double> pulseAnimation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: JediTheme.spaceM,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: JediTheme.safeDim,
        borderRadius: BorderRadius.circular(30), // Pill shape
        border: Border.all(
          color: JediTheme.safe.withAlpha(40),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: pulseAnimation,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: JediTheme.safe,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: JediTheme.spaceS),
          Text(
            'AGENT ONLINE',
            style: JediTheme.bodyStyle(
              fontSize: 12,
              color: JediTheme.safe,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
