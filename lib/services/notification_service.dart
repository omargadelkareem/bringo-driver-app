import 'package:bringo_driver/core/routes/app_router.dart';
import 'package:bringo_driver/core/routes/app_routes.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _ordersChannel =
      AndroidNotificationChannel(
    'bringo_driver_orders',
    'طلبات Bringo',
    description: 'إشعارات طلبات التوصيل الجديدة',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        final orderId = response.payload;

        if (orderId == null || orderId.trim().isEmpty) {
          return;
        }

        openOrder(orderId.trim());
      },
    );

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      _ordersChannel,
    );

    await androidPlugin?.requestNotificationsPermission();
  }

  Future<void> showNewOrder({
    required String orderId,
    required String storeName,
    required num deliveryFee,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'bringo_driver_orders',
      'طلبات Bringo',
      channelDescription: 'إشعارات طلبات التوصيل الجديدة',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
    );

    const details = NotificationDetails(
      android: androidDetails,
    );

    await _notifications.show(
      orderId.hashCode,
      'طلب توصيل جديد 🚚',
      '$storeName • التوصيل ${deliveryFee.toStringAsFixed(0)} ج.م',
      details,
      payload: orderId,
    );
  }

  Future<void> openOrder(String orderId) async {
    try {
      final snapshot =
          await FirebaseDatabase.instance.ref('orders/$orderId').get();

      if (!snapshot.exists || snapshot.value == null) {
        debugPrint(
          'Notification order no longer exists: $orderId',
        );
        return;
      }

      if (snapshot.value is! Map) {
        return;
      }

      final order = Map<String, dynamic>.from(
        snapshot.value as Map,
      );

      // مهم لأن باقي التطبيق بيعتمد عليه.
      order['firebaseKey'] = orderId;

      AppRouter.router.push(
        AppRoutes.orderDetails,
        extra: order,
      );
    } catch (e) {
      debugPrint(
        'Failed to open notification order: $e',
      );
    }
  }
}
