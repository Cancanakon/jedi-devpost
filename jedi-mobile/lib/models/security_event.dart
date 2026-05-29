import 'package:cloud_firestore/cloud_firestore.dart';

/// Immutable model representing a single `security_events` Firestore document.
///
/// Firestore fields used:
/// - `timestamp`    → [timestamp]
/// - `repo_name`    → [repoName]
/// - `author`       → [author]
/// - `diff_snippet` → [diffSnippet]
/// - `risk_score`   → [riskScore]
/// - `threat_level` → [threatLevel]
/// - `ai_reasoning` → [aiReasoning]
/// - `action`       → [action]
/// - `status_code`  → [statusCode]
/// - `mr_url`       → [mrUrl]  (nullable)
/// - `mr_iid`       → [mrIid]  (nullable)
class SecurityEvent {
  const SecurityEvent({
    required this.id,
    required this.timestamp,
    required this.repoName,
    required this.author,
    required this.diffSnippet,
    required this.riskScore,
    required this.threatLevel,
    required this.aiReasoning,
    required this.action,
    required this.statusCode,
    this.mrUrl,
    this.mrIid,
  });

  /// Firestore document ID.
  final String id;

  /// Firestore server timestamp — when the event was recorded.
  final DateTime timestamp;

  /// Full repository path, e.g. `"gokesatcan1-group/gokesatcan1-project"`.
  final String repoName;

  /// GitLab username of the commit author.
  final String author;

  /// First 100 characters of the raw diff.
  final String diffSnippet;

  /// AI-generated risk score in the range [0.0, 1.0].
  /// Threshold for automatic intervention: >= 0.75
  final double riskScore;

  /// Coarse threat categorisation: `"low"` | `"medium"` | `"critical"`.
  final String threatLevel;

  /// Gemini's full technical explanation for the risk assessment.
  final String aiReasoning;

  /// AI decision: `"approve"` | `"reject"`.
  final String action;

  /// Pipeline result: `"approved"` | `"intercepted"` | `"push_analysed"`.
  final String statusCode;

  /// GitLab MR URL — only present for Merge Request events.
  final String? mrUrl;

  /// GitLab MR number — only present for Merge Request events.
  final int? mrIid;

  // ─── Factory: Firestore ──────────────────────────────────────────────────

  /// Safely deserialises a Firestore [DocumentSnapshot] into a [SecurityEvent].
  ///
  /// Uses defensive field access with fallback defaults so that a missing or
  /// malformed field never crashes the application.
  factory SecurityEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Firestore Timestamp → Dart DateTime (safe fallback to epoch)
    DateTime ts;
    final rawTs = data['timestamp'];
    if (rawTs is Timestamp) {
      ts = rawTs.toDate();
    } else {
      ts = DateTime.fromMillisecondsSinceEpoch(0);
    }

    return SecurityEvent(
      id: doc.id,
      timestamp: ts,
      repoName:    data['repo_name']    as String? ?? '',
      author:      data['author']       as String? ?? '',
      diffSnippet: data['diff_snippet'] as String? ?? '',
      riskScore:   (data['risk_score']  as num?)?.toDouble() ?? 0.0,
      threatLevel: data['threat_level'] as String? ?? 'low',
      aiReasoning: data['ai_reasoning'] as String? ?? '',
      action:      data['action']       as String? ?? '',
      statusCode:  data['status_code']  as String? ?? '',
      mrUrl:       data['mr_url']       as String?,
      mrIid:       (data['mr_iid']      as num?)?.toInt(),
    );
  }

  // ─── Convenience Helpers ─────────────────────────────────────────────────

  /// Whether this event represents an active JEDI interception.
  bool get isIntercepted => statusCode == 'intercepted';

  /// Whether this event was automatically approved by the AI.
  bool get isApproved => statusCode == 'approved';

  /// Whether this event was a direct push (no MR context).
  bool get isPushAnalysed => statusCode == 'push_analysed';

  /// Whether the risk score or threat level triggered automatic intervention.
  bool get isAutoIntervention =>
      riskScore >= 0.75 || threatLevel.toLowerCase() == 'critical';

  /// Short repository name (without the namespace prefix).
  String get shortRepoName {
    final parts = repoName.split('/');
    return parts.isNotEmpty ? parts.last : repoName;
  }
}
