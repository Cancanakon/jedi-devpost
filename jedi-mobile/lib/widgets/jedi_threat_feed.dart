import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/security_event.dart';
import '../providers/security_providers.dart';
import '../theme/jedi_theme.dart';
import 'security_event_card.dart';

/// The primary live threat intelligence feed panel, now with filtering.
class JediThreatFeed extends ConsumerStatefulWidget {
  const JediThreatFeed({super.key});

  @override
  ConsumerState<JediThreatFeed> createState() => _JediThreatFeedState();
}

class _JediThreatFeedState extends ConsumerState<JediThreatFeed>
    with SingleTickerProviderStateMixin {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<SecurityEvent> _displayedEvents = [];

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _mergeEvents(List<SecurityEvent> newEvents) {
    // Collect genuinely new events
    final displayedIds = {for (final e in _displayedEvents) e.id};
    final toInsert = newEvents.where((e) => !displayedIds.contains(e.id)).toList();

    for (final event in toInsert) {
      _displayedEvents.insert(0, event);
      _listKey.currentState?.insertItem(
        0,
        duration: const Duration(milliseconds: 400),
      );
    }

    // Remove stale/filtered-out events
    final newIds = {for (final e in newEvents) e.id};
    for (int i = _displayedEvents.length - 1; i >= 0; i--) {
      if (!newIds.contains(_displayedEvents[i].id)) {
        final removed = _displayedEvents.removeAt(i);
        _listKey.currentState?.removeItem(
          i,
          (context, animation) => _buildCard(removed, animation, flash: false),
          duration: const Duration(milliseconds: 300),
        );
      }
    }
  }

  Widget _buildCard(
    SecurityEvent event,
    Animation<double> animation, {
    bool flash = true,
  }) {
    return SizeTransition(
      sizeFactor: animation,
      child: FadeTransition(
        opacity: animation,
        child: Padding(
          padding: const EdgeInsets.only(bottom: JediTheme.spaceM),
          child: SecurityEventCard(
            event: event,
            flashOnBuild: flash && event.threatLevel.toLowerCase() == 'critical',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch the FILTERED provider instead of the raw stream
    final eventsAsync = ref.watch(filteredSecurityEventsProvider);

    eventsAsync.whenData((events) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mergeEvents(events);
      });
    });

    return Padding(
      padding: const EdgeInsets.all(JediTheme.spaceM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header & Count ───────────────────────────────────────────────
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'LIVE THREAT FEED',
                        style: JediTheme.bodyStyle(
                          fontSize: 18,
                          color: JediTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: JediTheme.spaceS),
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: JediTheme.critical,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: JediTheme.critical.withAlpha(120),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Real-time Firestore stream',
                    style: JediTheme.bodyStyle(
                      fontSize: 11,
                      color: JediTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: JediTheme.surface,
                  borderRadius: BorderRadius.circular(JediTheme.radiusS),
                  border: Border.all(color: JediTheme.surfaceBorder),
                  boxShadow: JediTheme.cardShadow,
                ),
                child: Text(
                  '${_displayedEvents.length} EVENTS',
                  style: JediTheme.monoStyle(
                    fontSize: 12,
                    color: JediTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: JediTheme.spaceM),

          // ── Filters Row ──────────────────────────────────────────────────
          const Row(
            children: [
              _ThreatFilterGroup(),
              Spacer(),
              _DateFilterDropdown(),
            ],
          ),
          const SizedBox(height: JediTheme.spaceM),

          // ── Animated List ────────────────────────────────────────────────
          Expanded(
            child: _displayedEvents.isEmpty
                ? const _EmptyFeedState()
                : AnimatedList(
                    key: _listKey,
                    initialItemCount: _displayedEvents.length,
                    itemBuilder: (context, index, animation) {
                      if (index >= _displayedEvents.length) {
                        return const SizedBox.shrink();
                      }
                      return _buildCard(_displayedEvents[index], animation);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Filter UI Components ─────────────────────────────────────────────────

class _ThreatFilterGroup extends ConsumerWidget {
  const _ThreatFilterGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentFilter = ref.watch(threatFilterProvider);
    const options = ['All', 'Safe', 'Risk', 'Critical'];

    return Wrap(
      spacing: 8,
      children: options.map((option) {
        final isSelected = currentFilter == option;
        Color activeColor = JediTheme.primary;
        if (option == 'Safe') activeColor = JediTheme.safe;
        if (option == 'Risk') activeColor = JediTheme.medium;
        if (option == 'Critical') activeColor = JediTheme.critical;

        return ChoiceChip(
          label: Text(
            option,
            style: JediTheme.bodyStyle(
              fontSize: 12,
              color: isSelected ? Colors.white : JediTheme.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          selected: isSelected,
          onSelected: (_) => ref.read(threatFilterProvider.notifier).state = option,
          selectedColor: activeColor,
          backgroundColor: JediTheme.surface,
          side: BorderSide(
            color: isSelected ? activeColor : JediTheme.surfaceBorder,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        );
      }).toList(),
    );
  }
}

class _DateFilterDropdown extends ConsumerWidget {
  const _DateFilterDropdown();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentDate = ref.watch(dateFilterProvider);
    const options = ['All Time', 'Last 24H', 'Last 1H'];

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: JediTheme.surface,
        borderRadius: BorderRadius.circular(JediTheme.radiusS),
        border: Border.all(color: JediTheme.surfaceBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentDate,
          icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: JediTheme.textSecondary),
          isDense: true,
          alignment: Alignment.centerRight,
          items: options.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                style: JediTheme.bodyStyle(
                  fontSize: 12,
                  color: JediTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
          onChanged: (newValue) {
            if (newValue != null) {
              ref.read(dateFilterProvider.notifier).state = newValue;
            }
          },
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────

class _EmptyFeedState extends StatelessWidget {
  const _EmptyFeedState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: JediTheme.safe.withAlpha(15),
              shape: BoxShape.circle,
              border: Border.all(
                color: JediTheme.safe.withAlpha(40),
                width: 1,
              ),
            ),
            child: const Icon(Icons.filter_list_off, color: JediTheme.safe, size: 32),
          ),
          const SizedBox(height: JediTheme.spaceL),
          Text(
            'NO EVENTS FOUND',
            style: JediTheme.bodyStyle(
              fontSize: 16,
              color: JediTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: JediTheme.spaceS),
          Text(
            'No threats match the current filters.',
            style: JediTheme.bodyStyle(
              fontSize: 13,
              color: JediTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
