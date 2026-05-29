import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/security_providers.dart';
import 'theme/jedi_theme.dart';
import 'widgets/jedi_analytics_pane.dart';
import 'widgets/jedi_error_screen.dart';
import 'widgets/jedi_header_bar.dart';
import 'widgets/jedi_loading_screen.dart';
import 'widgets/jedi_threat_feed.dart';

// ─── macOS / iOS Notes ────────────────────────────────────────────────────
// macOS: Add the following to macos/Runner/DebugProfile.entitlements and
//        macos/Runner/Release.entitlements to allow outbound network access:
//   <key>com.apple.security.network.client</key>
//   <true/>
// iOS:   Info.plist already allows network by default.  If using App Transport
//         Security exceptions, add them under NSAppTransportSecurity as needed.

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // google-services.json (Android) ve GoogleService-Info.plist (iOS) 
    // olduğu için options vermemize gerek yok. Native olarak başlatılacak.
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization error or already initialized: $e');
  }

  runApp(
    // ProviderScope is required at the root for Riverpod to work.
    const ProviderScope(
      child: JediApp(),
    ),
  );
}

/// Root application widget.
class JediApp extends StatelessWidget {
  const JediApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JEDI Command Center',
      debugShowCheckedModeBanner: false,
      theme: JediTheme.themeData,
      home: const JediDashboardPage(),
    );
  }
}

/// Main dashboard page — manages the responsive layout.
class JediDashboardPage extends ConsumerWidget {
  const JediDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(securityEventsProvider);

    return Scaffold(
      backgroundColor: JediTheme.background,
      body: eventsAsync.when(
        loading: () => const JediLoadingScreen(),
        error: (error, _) => JediErrorScreen(error: error),
        data: (_) => const _JediLayout(),
      ),
    );
  }
}

/// Responsive layout: desktop = side-by-side, mobile = stacked.
class _JediLayout extends StatelessWidget {
  const _JediLayout();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // ── Fixed Header ─────────────────────────────────────────────────
          const JediHeaderBar(),

          // ── Main Content ─────────────────────────────────────────────────
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop =
                    constraints.maxWidth >= JediTheme.mobileBreakpoint;

                if (isDesktop) {
                  return const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left analytics pane (fixed 280 px)
                      JediAnalyticsPane(),
                      // Right threat feed (remaining width)
                      Expanded(child: JediThreatFeed()),
                    ],
                  );
                }

                // Mobile: stacked
                return const Column(
                  children: [
                    JediAnalyticsPane(),
                    Expanded(child: JediThreatFeed()),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
