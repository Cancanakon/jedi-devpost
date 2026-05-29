import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/security_providers.dart';
import '../theme/jedi_theme.dart';

/// Error screen displayed if the main Firestore stream fails completely.
class JediErrorScreen extends ConsumerWidget {
  const JediErrorScreen({super.key, required this.error});
  
  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: JediTheme.background,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(JediTheme.spaceXL),
          decoration: BoxDecoration(
            color: JediTheme.surface,
            borderRadius: BorderRadius.circular(JediTheme.radiusL),
            border: Border.all(color: JediTheme.critical.withAlpha(50), width: 1),
            boxShadow: JediTheme.cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: JediTheme.critical.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: JediTheme.critical,
                  size: 32,
                ),
              ),
              const SizedBox(height: JediTheme.spaceL),
              Text(
                'CONNECTION FAILED',
                style: JediTheme.bodyStyle(
                  fontSize: 18,
                  color: JediTheme.critical,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: JediTheme.spaceM),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: JediTheme.monoStyle(
                  fontSize: 12,
                  color: JediTheme.textSecondary,
                ),
              ),
              const SizedBox(height: JediTheme.spaceXL),
              _RetryButton(
                onTap: () {
                  // Invalidate the provider to force a fresh stream connection
                  ref.invalidate(securityEventsProvider);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RetryButton extends StatefulWidget {
  const _RetryButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_RetryButton> createState() => _RetryButtonState();
}

class _RetryButtonState extends State<_RetryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: JediTheme.spaceL,
            vertical: JediTheme.spaceM,
          ),
          decoration: BoxDecoration(
            color: _hovered ? JediTheme.critical : JediTheme.surface,
            borderRadius: BorderRadius.circular(JediTheme.radiusS),
            border: Border.all(
              color: _hovered ? JediTheme.critical : JediTheme.critical.withAlpha(50),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.refresh_rounded,
                size: 18,
                color: _hovered ? Colors.white : JediTheme.critical,
              ),
              const SizedBox(width: JediTheme.spaceS),
              Text(
                'RETRY CONNECTION',
                style: JediTheme.bodyStyle(
                  fontSize: 13,
                  color: _hovered ? Colors.white : JediTheme.critical,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
