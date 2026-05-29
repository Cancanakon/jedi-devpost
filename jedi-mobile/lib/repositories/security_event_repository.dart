import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/security_event.dart';

/// Repository that encapsulates all Firestore access for the `security_events`
/// collection.
///
/// The repository layer keeps Firestore details out of the UI and provider
/// code, making the data source easy to swap or mock in tests.
class SecurityEventRepository {
  SecurityEventRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Firestore collection reference.
  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('security_events');

  // ─── Public API ───────────────────────────────────────────────────────────

  /// Returns a live [Stream] of the 50 most recent security events, ordered
  /// by [timestamp] descending.
  ///
  /// Uses [onErrorResumeNext]-style error handling: any Firestore error is
  /// logged and an empty list is emitted so the UI never crashes.
  Stream<List<SecurityEvent>> watchSecurityEvents() {
    return _collection
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map<List<SecurityEvent>>((snapshot) {
          return snapshot.docs
              .map((doc) {
                try {
                  return SecurityEvent.fromFirestore(doc);
                } catch (e, st) {
                  debugPrint('[SecurityEventRepository] parse error: $e\n$st');
                  return null;
                }
              })
              .whereType<SecurityEvent>()
              .toList();
        })
        .handleError((Object error, StackTrace stackTrace) {
          debugPrint(
            '[SecurityEventRepository] stream error: $error\n$stackTrace',
          );
          // Return empty list on error — stream continues
          return <SecurityEvent>[];
        });
  }
}
