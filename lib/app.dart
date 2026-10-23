import 'package:bringo_driver/core/routes/app_router.dart';
import 'package:bringo_driver/services/order_notification_listener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class DriverApp extends StatefulWidget {
  const DriverApp({super.key});

  @override
  State<DriverApp> createState() => _DriverAppState();
}

class _DriverAppState extends State<DriverApp> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      OrderNotificationListener.instance.start();
    });
  }

  @override
  void dispose() {
    OrderNotificationListener.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(430, 932),
      minTextAdapt: true,
      splitScreenMode: true,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'طيار برينجو',
        routerConfig: AppRouter.router,
        theme: ThemeData(
          fontFamily: 'Tajawal',
          scaffoldBackgroundColor: const Color(0xFFF7FAF8),
          useMaterial3: true,
        ),
      ),
    );
  }
}
