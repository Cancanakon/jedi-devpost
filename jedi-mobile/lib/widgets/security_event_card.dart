import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/security_event.dart';
import '../theme/jedi_theme.dart';

/// Card widget representing a single [SecurityEvent] in the live threat feed.
class SecurityEventCard extends StatefulWidget {
  const SecurityEventCard({
    super.key,
    required this.event,
    this.flashOnBuild = false,
  });

  final SecurityEvent event;
  final bool flashOnBuild;

  @override
  State<SecurityEventCard> createState() => _SecurityEventCardState();
}

class _SecurityEventCardState extends State<SecurityEventCard> {
  bool _hovered = false;
  bool _flashing = false;

  @override
  void initState() {
    super.initState();
    if (widget.flashOnBuild &&
        widget.event.threatLevel.toLowerCase() == 'critical') {
      _startFlash();
    }
  }

  void _startFlash() {
    setState(() => _flashing = true);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _flashing = false);
    });
  }

  String _formatTime(DateTime dt) {
    final now  = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return DateFormat('HH:mm:ss').format(dt);
    } else if (diff.inDays == 1) {
      return 'Dün ${DateFormat('HH:mm').format(dt)}';
    } else {
      return DateFormat('dd MMM HH:mm').format(dt);
    }
  }

  _BadgeConfig _badgeConfig(String statusCode) {
    switch (statusCode) {
      case 'intercepted':
        return const _BadgeConfig('BLOCKED', JediTheme.critical, Icons.block);
      case 'approved':
        return const _BadgeConfig('APPROVED', JediTheme.safe, Icons.check_circle_outline);
      case 'push_analysed':
        return const _BadgeConfig('SCANNED', JediTheme.primary, Icons.search);
      default:
        return _BadgeConfig(statusCode.toUpperCase(), JediTheme.textSecondary, Icons.info_outline);
    }
  }

  Future<void> _openMr(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final badge = _badgeConfig(widget.event.statusCode);
    final threatColor = JediTheme.threatLevelColor(widget.event.threatLevel);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: JediTheme.spaceM),
        transform: _hovered
            ? (Matrix4.diagonal3Values(1.005, 1.005, 1.0))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: _flashing
              ? JediTheme.critical.withAlpha(20)
              : JediTheme.surface,
          borderRadius: BorderRadius.circular(JediTheme.radiusL),
          border: Border.all(
            color: _flashing 
                ? JediTheme.critical.withAlpha(50) 
                : _hovered ? JediTheme.primary.withAlpha(50) : JediTheme.surfaceBorder,
            width: 1,
          ),
          boxShadow: _hovered ? JediTheme.hoverShadow : JediTheme.cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(JediTheme.spaceL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Row 1: Badge + Timestamp ────────────────────────────
              Row(
                children: [
                  _ActionBadge(config: badge),
                  const Spacer(),
                  Text(
                    _formatTime(widget.event.timestamp),
                    style: JediTheme.monoStyle(
                      fontSize: 12,
                      color: JediTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: JediTheme.spaceM),

              // ── Row 2: Repo + Author ────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.event.repoName,
                      style: JediTheme.bodyStyle(
                        fontSize: 16,
                        color: JediTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: JediTheme.spaceS),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: JediTheme.background,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: JediTheme.surfaceBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_outline, size: 12, color: JediTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          widget.event.author,
                          style: JediTheme.bodyStyle(
                            fontSize: 12,
                            color: JediTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: JediTheme.spaceM),

              // ── AI Reasoning ────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: JediTheme.primary.withAlpha(10),
                  borderRadius: BorderRadius.circular(JediTheme.radiusS),
                  border: Border.all(color: JediTheme.primary.withAlpha(30)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome, size: 16, color: JediTheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.event.aiReasoning,
                        style: JediTheme.bodyStyle(
                          fontSize: 13,
                          color: JediTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Diff Snippet (if non-empty) ─────────────────────────
              if (widget.event.diffSnippet.isNotEmpty) ...[
                const SizedBox(height: JediTheme.spaceS),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: JediTheme.background,
                    borderRadius: BorderRadius.circular(JediTheme.radiusS),
                    border: Border.all(color: JediTheme.surfaceBorder),
                  ),
                  child: Text(
                    widget.event.diffSnippet,
                    style: JediTheme.monoStyle(
                      fontSize: 11,
                      color: JediTheme.textSecondary,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],

              const SizedBox(height: JediTheme.spaceL),

              // ── Footer: Threat Info & MR Button ─────────────────────
              Row(
                children: [
                  _ThreatBadge(threatLevel: widget.event.threatLevel),
                  const SizedBox(width: JediTheme.spaceM),
                  Text(
                    'Risk Score:',
                    style: JediTheme.bodyStyle(
                      fontSize: 12,
                      color: JediTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(widget.event.riskScore * 100).toStringAsFixed(0)}%',
                    style: JediTheme.monoStyle(
                      fontSize: 14,
                      color: threatColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (widget.event.mrUrl != null)
                    _MrButton(
                      hovered: _hovered,
                      onTap: () => _openMr(widget.event.mrUrl!),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Helper Widgets ───────────────────────────────────────────────────────

class _BadgeConfig {
  const _BadgeConfig(this.label, this.color, this.icon);
  final String   label;
  final Color    color;
  final IconData icon;
}

class _ActionBadge extends StatelessWidget {
  const _ActionBadge({required this.config});
  final _BadgeConfig config;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config.color.withAlpha(20),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: 12, color: config.color),
          const SizedBox(width: 6),
          Text(
            config.label,
            style: JediTheme.bodyStyle(
              fontSize: 11,
              color: config.color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreatBadge extends StatelessWidget {
  const _ThreatBadge({required this.threatLevel});
  final String threatLevel;

  @override
  Widget build(BuildContext context) {
    final color = JediTheme.threatLevelColor(threatLevel);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          threatLevel.toUpperCase(),
          style: JediTheme.bodyStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _MrButton extends StatefulWidget {
  const _MrButton({required this.hovered, required this.onTap});
  final bool hovered;
  final VoidCallback onTap;

  @override
  State<_MrButton> createState() => _MrButtonState();
}

class _MrButtonState extends State<_MrButton> {
  bool _buttonHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _buttonHovered = true),
      onExit:  (_) => setState(() => _buttonHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _buttonHovered ? JediTheme.primary : JediTheme.surface,
            borderRadius: BorderRadius.circular(JediTheme.radiusS),
            border: Border.all(
              color: _buttonHovered ? JediTheme.primary : JediTheme.surfaceBorder,
            ),
            boxShadow: _buttonHovered
                ? [BoxShadow(color: JediTheme.primary.withAlpha(50), blurRadius: 8, offset: const Offset(0, 2))]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'View MR',
                style: JediTheme.bodyStyle(
                  fontSize: 12,
                  color: _buttonHovered ? Colors.white : JediTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: _buttonHovered ? Colors.white : JediTheme.textPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
