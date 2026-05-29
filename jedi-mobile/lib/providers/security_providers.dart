import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/security_event.dart';
import '../repositories/security_event_repository.dart';

// ─── Repository Provider ──────────────────────────────────────────────────

/// Singleton repository instance.
final securityEventRepositoryProvider = Provider<SecurityEventRepository>(
  (ref) => SecurityEventRepository(),
);

// ─── Primary Stream Provider ──────────────────────────────────────────────

/// Live stream of the 50 most recent [SecurityEvent]s from Firestore.
///
/// Firestore fields consumed: all fields via [SecurityEvent.fromFirestore].
final securityEventsProvider =
    StreamProvider<List<SecurityEvent>>((ref) {
  final repo = ref.watch(securityEventRepositoryProvider);
  return repo.watchSecurityEvents();
});

// ─── Derived Analytic Providers ───────────────────────────────────────────

/// Helper: returns only events from the last 24 hours.
List<SecurityEvent> _last24h(List<SecurityEvent> events) {
  final cutoff = DateTime.now().subtract(const Duration(hours: 24));
  return events.where((e) => e.timestamp.isAfter(cutoff)).toList();
}

/// Total number of scans recorded in the last 24 hours.
///
/// Uses: [SecurityEvent.timestamp].
final totalScansProvider = Provider<int>((ref) {
  final events = ref.watch(securityEventsProvider).valueOrNull ?? [];
  return _last24h(events).length;
});

/// Number of events where JEDI actively intercepted (blocked) a push/MR
/// in the last 24 hours.
///
/// Uses: [SecurityEvent.timestamp], [SecurityEvent.statusCode].
final threatsInterceptedProvider = Provider<int>((ref) {
  final events = ref.watch(securityEventsProvider).valueOrNull ?? [];
  return _last24h(events).where((e) => e.statusCode == 'intercepted').length;
});

/// Security health score in the range [0.0, 1.0].
///
/// Formula: `1.0 - (intercepted / max(total, 1))` where both counts are
/// limited to the last 24-hour window.
///
/// Uses: [SecurityEvent.timestamp], [SecurityEvent.statusCode].
final healthScoreProvider = Provider<double>((ref) {
  final events = ref.watch(securityEventsProvider).valueOrNull ?? [];
  final recent = _last24h(events);
  final total = recent.length;
  final intercepted =
      recent.where((e) => e.statusCode == 'intercepted').length;
  return 1.0 - (intercepted / (total > 0 ? total : 1));
});

// ─── Filter Providers ─────────────────────────────────────────────────────

/// Filter for threat level.
/// Options: 'All', 'Safe' (low), 'Risk' (medium/critical), 'Critical'.
final threatFilterProvider = StateProvider<String>((ref) => 'All');

/// Filter for timestamp.
/// Options: 'All Time', 'Last 1H', 'Last 24H'.
final dateFilterProvider = StateProvider<String>((ref) => 'All Time');

/// Filtered list of security events based on [threatFilterProvider] and [dateFilterProvider].
final filteredSecurityEventsProvider = Provider<AsyncValue<List<SecurityEvent>>>((ref) {
  final eventsAsync = ref.watch(securityEventsProvider);
  final threatFilter = ref.watch(threatFilterProvider);
  final dateFilter = ref.watch(dateFilterProvider);

  return eventsAsync.whenData((events) {
    return events.where((e) {
      // 1. Threat Filter
      final threat = e.threatLevel.toLowerCase();
      if (threatFilter == 'Safe' && threat != 'low') return false;
      if (threatFilter == 'Risk' && threat == 'low') return false;
      if (threatFilter == 'Critical' && threat != 'critical') return false;

      // 2. Date Filter
      final now = DateTime.now();
      if (dateFilter == 'Last 1H' && e.timestamp.isBefore(now.subtract(const Duration(hours: 1)))) {
        return false;
      }
      if (dateFilter == 'Last 24H' && e.timestamp.isBefore(now.subtract(const Duration(hours: 24)))) {
        return false;
      }

      return true;
    }).toList();
  });
});
