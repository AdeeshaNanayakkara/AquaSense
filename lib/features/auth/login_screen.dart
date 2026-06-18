import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/constants.dart';
import '../../core/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;

  // Bubble animations
  late final List<_BubbleController> _bubbles;

  @override
  void initState() {
    super.initState();
    _bubbles = List.generate(
      8,
      (i) => _BubbleController(vsync: this, index: i),
    );
    for (final b in _bubbles) {
      b.start();
    }
  }

  @override
  void dispose() {
    for (final b in _bubbles) {
      b.dispose();
    }
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final result = await AuthService.instance.signInWithGoogle();
      if (result == null && mounted) {
        // User cancelled — not an error
        setState(() => _isLoading = false);
      }
      // On success, AuthWrapper's StreamBuilder handles navigation automatically
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign-in failed: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ─── Background gradient ───────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryDark,
                  AppColors.primary,
                  Color(0xFF1E3A8A),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // ─── Floating animated bubbles ─────────────────────────────────────
          ...List.generate(_bubbles.length, (i) {
            return AnimatedBuilder(
              animation: _bubbles[i].animation,
              builder: (context, child) {
                final progress = _bubbles[i].animation.value;
                final x = _bubbles[i].xFraction * size.width;
                final y = size.height * (1.0 - progress) - _bubbles[i].radius;
                return Positioned(
                  left: x,
                  top: y,
                  child: Opacity(
                    opacity: (0.08 + _bubbles[i].opacity * 0.12)
                        .clamp(0.0, 1.0),
                    child: Container(
                      width: _bubbles[i].radius * 2,
                      height: _bubbles[i].radius * 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 1.5,
                        ),
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          // ─── Content ───────────────────────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: SizedBox(
                height: size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),

                    // Logo + App name
                    Hero(
                      tag: 'app_logo',
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.secondary.withValues(alpha: 0.4),
                              blurRadius: 32,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, e, s) => const Icon(
                              Icons.water_drop_rounded,
                              color: Colors.white,
                              size: 44,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // App name
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Colors.white, AppColors.secondaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: const Text(
                        'AquaSense',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Smart Water Management',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.65),
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    const Spacer(flex: 2),

                    // ── Glassmorphism card ─────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 36,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 40,
                            spreadRadius: -8,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Welcome Back',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sign in to monitor and manage\nyour water system remotely',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.55),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Google Sign-In button
                          _GoogleSignInButton(
                            isLoading: _isLoading,
                            onPressed: _handleGoogleSignIn,
                          ),

                          const SizedBox(height: 20),

                          // Feature pills row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _featurePill(Icons.lock_outline_rounded, 'Secure'),
                              const SizedBox(width: 10),
                              _featurePill(Icons.bolt_rounded, 'Fast'),
                              const SizedBox(width: 10),
                              _featurePill(Icons.verified_outlined, 'Trusted'),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const Spacer(flex: 1),

                    // Footer
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Text(
                        'By signing in, you agree to our Terms & Privacy Policy',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.35),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featurePill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.secondaryLight),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Google Sign-In Button
// ─────────────────────────────────────────────────────────────────────────────

class _GoogleSignInButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _GoogleSignInButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  State<_GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<_GoogleSignInButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTapDown: (_) {
          _controller.forward();
          setState(() => _hovered = true);
        },
        onTapUp: (_) {
          _controller.reverse();
          setState(() => _hovered = false);
          if (!widget.isLoading) widget.onPressed();
        },
        onTapCancel: () {
          _controller.reverse();
          setState(() => _hovered = false);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.grey.shade100
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hovered ? 0.15 : 0.22),
                blurRadius: _hovered ? 12 : 20,
                spreadRadius: -2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: widget.isLoading
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Custom-painted Google "G" logo
                    CustomPaint(
                      size: const Size(22, 22),
                      painter: _GoogleLogoPainter(),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'Continue with Google',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3C4043),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom Google "G" Painter (no external image needed)
// ─────────────────────────────────────────────────────────────────────────────

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // Clip to circle
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r)));

    // White background
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()..color = Colors.white,
    );

    final strokeW = r * 0.22;

    // Draw 4 arcs: Blue top, Red left, Yellow bottom, Green right
    // Full circle split into 4 quadrants for the 4 Google colors
    void drawArc(Color color, double startAngle, double sweepAngle) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.butt;
      final arcR = r * 0.65;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: arcR),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }

    const pi = math.pi;
    // Red: top-right going clockwise
    drawArc(const Color(0xFFEA4335), -pi / 2, pi / 2 + 0.15);
    // Yellow: bottom-right
    drawArc(const Color(0xFFFBBC05), 0.0 + 0.05, pi / 2 + 0.05);
    // Green: bottom-left
    drawArc(const Color(0xFF34A853), pi / 2 + 0.1, pi / 2 + 0.05);
    // Blue: top-left
    drawArc(const Color(0xFF4285F4), pi + 0.1, pi / 2 + 0.1);

    // Horizontal bar for the "G" crossbar (right side only)
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;
    final arcR = r * 0.65;
    final barY = cy;
    final barLeft = cx;
    final barRight = cx + arcR;
    canvas.drawLine(Offset(barLeft, barY), Offset(barRight, barY), barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Bubble animation helper
// ─────────────────────────────────────────────────────────────────────────────

class _BubbleController {
  final int index;
  final TickerProvider vsync;

  late final AnimationController _ctrl;
  late final double xFraction;
  late final double radius;
  late final double opacity;

  _BubbleController({required this.vsync, required this.index}) {
    final rng = math.Random(index * 7 + 13);
    xFraction = rng.nextDouble() * 0.9 + 0.05;
    radius = 16.0 + rng.nextDouble() * 50.0;
    opacity = 0.4 + rng.nextDouble() * 0.6;
    final durationMs = 5000 + rng.nextInt(6000);
    _ctrl = AnimationController(
      vsync: vsync,
      duration: Duration(milliseconds: durationMs),
    );
  }

  Animation<double> get animation => _ctrl;

  void start() {
    final rng = math.Random(index * 3 + 5);
    final initialValue = rng.nextDouble();
    _ctrl.value = initialValue;
    _ctrl.repeat();
  }

  void dispose() => _ctrl.dispose();
}
