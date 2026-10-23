import 'package:bringo_driver/core/routes/app_routes.dart';
import 'package:bringo_driver/features/home/driver_home_screen.dart';
import 'package:bringo_driver/features/login/driver_login_screen.dart';
import 'package:bringo_driver/features/main/driver_main_layout.dart';
import 'package:bringo_driver/features/orders/driver_order_details_screen.dart';
import 'package:bringo_driver/features/profile/driver_profile_setup_screen.dart';
import 'package:bringo_driver/features/splash/driver_splash_screen.dart';
import 'package:go_router/go_router.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const DriverSplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const DriverLoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const DriverHomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.orderDetails,
        builder: (context, state) {
          final order = state.extra as Map<String, dynamic>;
          return DriverOrderDetailsScreen(order: order);
        },
      ),
      GoRoute(
        path: AppRoutes.mainLayout,
        builder: (context, state) => const DriverMainLayout(),
      ),
      GoRoute(
        path: AppRoutes.profileSetup,
        builder: (context, state) => const DriverProfileSetupScreen(),
      ),
    ],
  );
}
