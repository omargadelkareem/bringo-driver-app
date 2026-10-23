import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:get_storage/get_storage.dart';

import 'notification_service.dart';

class OrderNotificationListener {
  OrderNotificationListener._();

  static final OrderNotificationListener instance =
      OrderNotificationListener._();

  final DatabaseReference _ordersRef = FirebaseDatabase.instance.ref('orders');

  final GetStorage _storage = GetStorage();

  StreamSubscription<DatabaseEvent>? _subscription;

  static const String _storageKey = 'notified_driver_orders';

  /// الحالات التي تعني أن الطلب أصبح جاهزًا للطيار.
  static const Set<String> _readyStatuses = {
    'ready',
    'ready_for_pickup',
    'readyforpickup',
  };

  final Set<String> _knownAvailableOrders = {};
  final Set<String> _notifiedOrders = {};

  bool _firstSnapshot = true;

  Future<void> start() async {
    await stop();

    _loadNotifiedOrders();

    _firstSnapshot = true;
    _knownAvailableOrders.clear();

    _subscription = _ordersRef.onValue.listen(
      _handleOrders,
      onError: (error) {
        print('Order notification listener error: $error');
      },
    );
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  void _loadNotifiedOrders() {
    final saved = _storage.read<List>(_storageKey);

    _notifiedOrders
      ..clear()
      ..addAll(
        saved?.map((e) => e.toString()) ?? <String>[],
      );
  }

  Future<void> _handleOrders(DatabaseEvent event) async {
    final value = event.snapshot.value;

    if (value == null || value is! Map) {
      _firstSnapshot = false;
      return;
    }

    final data = Map<dynamic, dynamic>.from(value);

    final currentlyAvailable = <String>{};

    for (final entry in data.entries) {
      if (entry.value is! Map) continue;

      final orderId = entry.key.toString();

      final order = Map<String, dynamic>.from(entry.value as Map);

      if (!_isAvailableForDriver(order)) {
        continue;
      }

      currentlyAvailable.add(orderId);

      // أول Snapshot:
      // نسجل الطلبات الموجودة بالفعل بدون ما نعمل Notifications.
      if (_firstSnapshot) {
        _knownAvailableOrders.add(orderId);
        continue;
      }

      // الطلب كان موجودًا بالفعل كـ ready.
      if (_knownAvailableOrders.contains(orderId)) {
        continue;
      }

      // سبق إرسال Notification لهذا الطلب.
      if (_notifiedOrders.contains(orderId)) {
        continue;
      }

      await _notifyOrder(
        orderId: orderId,
        order: order,
      );

      _knownAvailableOrders.add(orderId);
      _notifiedOrders.add(orderId);

      await _saveNotifiedOrders();
    }

    // لو الطلب خرج من حالة ready، نشيله من القائمة الحالية.
    _knownAvailableOrders.removeWhere(
      (id) => !currentlyAvailable.contains(id),
    );

    _knownAvailableOrders.addAll(currentlyAvailable);

    _firstSnapshot = false;
  }

  bool _isAvailableForDriver(
    Map<String, dynamic> order,
  ) {
    final status = (order['status'] ?? order['orderStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    final driverId = order['driverId']?.toString().trim() ?? '';

    if (driverId.isNotEmpty) {
      return false;
    }

    return _readyStatuses.contains(status);
  }

  Future<void> _notifyOrder({
    required String orderId,
    required Map<String, dynamic> order,
  }) async {
    final storeName = _firstText([
      order['storeName'],
      order['restaurantName'],
      order['pharmacyName'],
      order['merchantName'],
      order['vendorName'],
      order['shopName'],
      order['providerName'],
    ]);

    final deliveryFee = num.tryParse(
          order['deliveryFee']?.toString() ?? '0',
        ) ??
        0;

    await NotificationService.instance.showNewOrder(
      orderId: orderId,
      storeName: storeName.isEmpty ? 'طلب Bringo جديد' : storeName,
      deliveryFee: deliveryFee,
    );
  }

  String _firstText(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';

      if (text.isNotEmpty && text != 'null') {
        return text;
      }
    }

    return '';
  }

  Future<void> _saveNotifiedOrders() async {
    // نحتفظ بآخر 200 فقط حتى لا يكبر التخزين بلا داعٍ.
    final ids = _notifiedOrders.toList();

    final trimmed = ids.length > 200 ? ids.sublist(ids.length - 200) : ids;

    await _storage.write(
      _storageKey,
      trimmed,
    );
  }
}
