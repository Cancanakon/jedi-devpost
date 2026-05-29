import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/jedi_theme.dart';

/// Loading state for the JEDI Command Center.
/// Displays a typewriter terminal effect followed by shimmer skeleton cards.
class JediLoadingScreen extends StatefulWidget {
  const JediLoadingScreen({super.key});

  @override
  State<JediLoadingScreen> createState() => _JediLoadingScreenState();
}

class _JediLoadingScreenState extends State<JediLoadingScreen>
    with SingleTickerProviderStateMixin {
  final String _targetText = 'INITIALIZING JEDI CORE SYSTEM...';
  String _displayText = '';
  int _charIndex = 0;
  Timer? _typeTimer;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _startTypewriter();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _startTypewriter() {
    _typeTimer = Timer.periodic(const Duration(milliseconds: 55), (timer) {
      if (!mounted) return;
      if (_charIndex < _targetText.length) {
        setState(() {
          _displayText += _targetText[_charIndex];
          _charIndex++;
        });
      } else {
        // Pause briefly, then restart the typewriter for a loop effect
        timer.cancel();
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _displayText = '';
              _charIndex = 0;
            });
            _startTypewriter();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JediTheme.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(JediTheme.spaceXL),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Typewriter Text ─────────────────────────────────────────
                SizedBox(
                  height: 30,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _displayText,
                        style: JediTheme.monoStyle(
                          fontSize: 16,
                          color: JediTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      FadeTransition(
                        opacity: _pulseAnimation,
                        child: Container(
                          width: 10,
                          height: 18,
                          color: JediTheme.primary,
                          margin: const EdgeInsets.only(left: 4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: JediTheme.spaceXXL),

                // ── Shimmer Skeleton Cards ──────────────────────────────────
                ...List.generate(3, (index) => Padding(
                  padding: const EdgeInsets.only(bottom: JediTheme.spaceM),
                  child: Shimmer.fromColors(
                    baseColor: JediTheme.surfaceBorder.withAlpha(100),
                    highlightColor: JediTheme.surface,
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: JediTheme.surface,
                        borderRadius: BorderRadius.circular(JediTheme.radiusL),
                        border: Border.all(color: JediTheme.surfaceBorder),
                      ),
                    ),
                  ),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
