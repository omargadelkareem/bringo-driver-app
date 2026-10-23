import 'package:bringo_driver/core/routes/app_routes.dart';
import 'package:bringo_driver/core/session/driver_session.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class DriverSplashScreen extends StatefulWidget {
  const DriverSplashScreen({super.key});

  @override
  State<DriverSplashScreen> createState() => _DriverSplashScreenState();
}

class _DriverSplashScreenState extends State<DriverSplashScreen>
    with TickerProviderStateMixin {
  static const Color _teal = Color(0xFF1F5A59);
  static const Color _darkTeal = Color(0xFF174746);
  static const Color _lime = Color(0xFFDDFB8A);
  static const Color _mint = Color(0xFFEAF3F2);

  late final AnimationController _introController;
  late final AnimationController _routeController;

  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _routeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _fadeAnimation = CurvedAnimation(
      parent: _introController,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(
      begin: .78,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: Curves.easeOutBack,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, .25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: Curves.easeOutCubic,
      ),
    );

    _introController.forward();

    _check();
  }

  Future<void> _check() async {
    await Future.delayed(const Duration(milliseconds: 2400));

    if (!mounted) return;

    if (DriverSession.isLoggedIn) {
      context.go(AppRoutes.mainLayout);
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _introController.dispose();
    _routeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkTeal,
      body: Stack(
        children: [
          // Background glow
          Positioned(
            top: -120,
            right: -100,
            child: _GlowCircle(
              size: 310,
              color: _lime.withOpacity(.07),
            ),
          ),

          Positioned(
            bottom: -150,
            left: -110,
            child: _GlowCircle(
              size: 350,
              color: Colors.white.withOpacity(.035),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
              ),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: const _BringoLogo(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        children: [
                          Text(
                            'Bringo',
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 35,
                              height: 1,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.8,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _lime,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              'DRIVER',
                              style: GoogleFonts.cairo(
                                color: _darkTeal,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 17),
                          Text(
                            'وصّلها أسرع.. مع برينجو',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cairo(
                              color: Colors.white.withOpacity(.72),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(flex: 2),
                  _DeliveryRoute(
                    animation: _routeController,
                  ),
                  const SizedBox(height: 24),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      'كل مشوار أقرب',
                      style: GoogleFonts.cairo(
                        color: Colors.white.withOpacity(.55),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BringoLogo extends StatelessWidget {
  const _BringoLogo();

  static const Color teal = Color(0xFF1F5A59);
  static const Color lime = Color(0xFFDDFB8A);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 126,
      height: 126,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.16),
            blurRadius: 35,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Center(
        child: SizedBox(
          width: 79,
          height: 79,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // vertical part of b
              Positioned(
                left: 11,
                top: 4,
                child: Container(
                  width: 22,
                  height: 61,
                  decoration: BoxDecoration(
                    color: teal,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),

              // round part of b
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  width: 57,
                  height: 57,
                  decoration: const BoxDecoration(
                    color: teal,
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              // inner white area
              Positioned(
                right: 16,
                bottom: 15,
                child: Container(
                  width: 35,
                  height: 35,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              // leaf
              Positioned(
                right: 17,
                bottom: 21,
                child: Transform.rotate(
                  angle: -.55,
                  child: Container(
                    width: 31,
                    height: 18,
                    decoration: BoxDecoration(
                      color: lime,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeliveryRoute extends StatelessWidget {
  final Animation<double> animation;

  const _DeliveryRoute({
    required this.animation,
  });

  static const Color lime = Color(0xFFDDFB8A);
  static const Color darkTeal = Color(0xFF174746);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 75,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final available = constraints.maxWidth - 56;

              final position = available * animation.value;

              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Positioned(
                    left: 22,
                    right: 22,
                    top: 37,
                    child: Row(
                      children: List.generate(
                        15,
                        (index) => Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 3,
                            ),
                            height: 2,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    top: 27,
                    child: Container(
                      width: 21,
                      height: 21,
                      decoration: BoxDecoration(
                        color: lime,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    right: 4,
                    top: 22,
                    child: Icon(
                      Icons.location_on_rounded,
                      color: lime,
                      size: 31,
                    ),
                  ),
                  Positioned(
                    left: 22 + position,
                    top: 19,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: lime,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: lime.withOpacity(.22),
                            blurRadius: 15,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.delivery_dining_rounded,
                        color: darkTeal,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowCircle({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
