import 'package:bringo_driver/core/routes/app_routes.dart';
import 'package:bringo_driver/core/session/driver_session.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class DriverOrdersScreen extends StatefulWidget {
  const DriverOrdersScreen({super.key});

  @override
  State<DriverOrdersScreen> createState() => _DriverOrdersScreenState();
}

class _DriverOrdersScreenState extends State<DriverOrdersScreen>
    with SingleTickerProviderStateMixin {
  static const teal = Color(0xFF1F5A59);
  static const darkTeal = Color(0xFF174746);
  static const lime = Color(0xFFDDFB8A);
  static const mint = Color(0xFFEAF3F2);
  static const background = Color(0xFFF7FAF8);
  static const textDark = Color(0xFF182322);
  static const textGrey = Color(0xFF77817F);
  static const border = Color(0xFFE3EAE8);

  late final TabController tabController;

  final String driverId = DriverSession.driverId ?? '';
  final String driverName = DriverSession.driverName ?? 'طيار Bringo';
  final String driverPhone = DriverSession.driverPhone ?? '';

  String? loadingOrderId;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> parseOrders(dynamic value) {
    if (value == null || value is! Map) return [];

    final data = Map<dynamic, dynamic>.from(value);
    final orders = <Map<String, dynamic>>[];

    data.forEach((key, value) {
      if (value is! Map) return;
      final item = Map<String, dynamic>.from(value);
      item['firebaseKey'] = key.toString();
      orders.add(item);
    });

    orders.sort((a, b) {
      final aTime = int.tryParse(
            (a['createdAt'] ?? a['updatedAt'] ?? 0).toString(),
          ) ??
          0;
      final bTime = int.tryParse(
            (b['createdAt'] ?? b['updatedAt'] ?? 0).toString(),
          ) ??
          0;
      return bTime.compareTo(aTime);
    });

    return orders;
  }

  String _status(Map<String, dynamic> order) {
    return (order['status'] ?? order['orderStatus'] ?? 'pending')
        .toString()
        .trim();
  }

  Future<void> acceptOrder(Map<String, dynamic> order) async {
    final key = order['firebaseKey']?.toString() ?? '';
    if (key.isEmpty || loadingOrderId != null) return;

    try {
      setState(() => loadingOrderId = key);

      final orderRef = FirebaseDatabase.instance.ref('orders/$key');
      final snapshot = await orderRef.get();

      if (!snapshot.exists || snapshot.value == null) {
        _msg('الطلب لم يعد موجودًا');
        return;
      }

      final fresh = Map<String, dynamic>.from(snapshot.value as Map);
      final currentDriverId = fresh['driverId']?.toString() ?? '';
      final currentDriverKey = fresh['driverKey']?.toString() ?? '';
      final currentStatus =
          (fresh['status'] ?? fresh['orderStatus'] ?? 'pending').toString();

      if (currentDriverId.isNotEmpty || currentDriverKey.isNotEmpty) {
        _msg('تم قبول الطلب بواسطة طيار آخر');
        return;
      }

      const allowed = {'pending', 'confirmed', 'new', 'accepted'};
      if (!allowed.contains(currentStatus)) {
        _msg('هذا الطلب غير متاح الآن');
        return;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      await orderRef.update({
        'driverId': driverId,
        'driverKey': driverId,
        'driverName': driverName,
        'driverPhone': driverPhone,
        'status': 'assigned',
        'orderStatus': 'assigned',
        'acceptedAt': now,
        'updatedAt': now,
      });

      _msg('تم قبول الطلب');
      tabController.animateTo(1);
    } catch (_) {
      _msg('حدث خطأ أثناء قبول الطلب');
    } finally {
      if (mounted) setState(() => loadingOrderId = null);
    }
  }

  Future<void> updateStatus(
    Map<String, dynamic> order,
    String status,
  ) async {
    final key = order['firebaseKey']?.toString() ?? '';
    if (key.isEmpty || loadingOrderId != null) return;

    try {
      setState(() => loadingOrderId = key);
      final now = DateTime.now().millisecondsSinceEpoch;

      final updates = <String, dynamic>{
        'status': status,
        'orderStatus': status,
        'updatedAt': now,
      };

      if (status == 'pickedUp') updates['pickedUpAt'] = now;
      if (status == 'onDelivery') updates['onDeliveryAt'] = now;
      if (status == 'completed') updates['completedAt'] = now;

      await FirebaseDatabase.instance.ref('orders/$key').update(updates);

      _msg(
        status == 'pickedUp'
            ? 'تم تأكيد استلام الطلب'
            : status == 'onDelivery'
                ? 'تم بدء التوصيل'
                : 'تم تسليم الطلب بنجاح',
      );
    } catch (_) {
      _msg('حدث خطأ أثناء تحديث الطلب');
    } finally {
      if (mounted) setState(() => loadingOrderId = null);
    }
  }

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            text,
            textAlign: TextAlign.right,
            style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
          ),
          backgroundColor: darkTeal,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
        ),
      );
  }

  bool _belongsToMe(Map<String, dynamic> order) {
    final dId = order['driverId']?.toString() ?? '';
    final dKey = order['driverKey']?.toString() ?? '';
    return dId == driverId || dKey == driverId;
  }

  bool _isAvailableOrder(Map<String, dynamic> order) {
    final status = _status(order);
    final dId = order['driverId']?.toString() ?? '';
    final dKey = order['driverKey']?.toString() ?? '';

    return dId.isEmpty &&
        dKey.isEmpty &&
        const {'pending', 'confirmed', 'new', 'accepted'}.contains(status);
  }

  bool _isMyActiveOrder(Map<String, dynamic> order) {
    final status = _status(order);
    return _belongsToMe(order) &&
        const {
          'assigned',
          'pickedUp',
          'onDelivery',
          'picked',
          'way',
        }.contains(status);
  }

  bool _isMyCompletedOrder(Map<String, dynamic> order) {
    final status = _status(order);
    return _belongsToMe(order) &&
        const {'completed', 'delivered', 'done'}.contains(status);
  }

  @override
  Widget build(BuildContext context) {
    if (driverId.isEmpty) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: background,
          body: Center(
            child: Text(
              'من فضلك سجل الدخول مرة أخرى',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: Column(
            children: [
              _header(),
              _tabs(),
              SizedBox(height: 8.h),
              Expanded(
                child: StreamBuilder<DatabaseEvent>(
                  stream: FirebaseDatabase.instance.ref('orders').onValue,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                            ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const _OrdersShimmer();
                    }

                    if (snapshot.hasError) {
                      return _emptyState(
                        icon: Icons.cloud_off_rounded,
                        title: 'تعذر تحميل الطلبات',
                        subtitle: 'تحقق من الإنترنت وحاول مرة أخرى',
                      );
                    }

                    final orders = parseOrders(snapshot.data?.snapshot.value);
                    final available =
                        orders.where(_isAvailableOrder).toList();
                    final mine =
                        orders.where(_isMyActiveOrder).toList();
                    final completed =
                        orders.where(_isMyCompletedOrder).toList();

                    return TabBarView(
                      controller: tabController,
                      children: [
                        _ordersList(
                          available,
                          type: _OrderListType.available,
                          emptyTitle: 'مفيش طلبات متاحة دلوقتي',
                          emptySubtitle:
                              'أول ما يظهر طلب جديد هتلاقيه هنا',
                        ),
                        _ordersList(
                          mine,
                          type: _OrderListType.active,
                          emptyTitle: 'مفيش مشوار شغال معاك',
                          emptySubtitle:
                              'بعد قبول أي طلب هتتابع خطواته من هنا',
                        ),
                        _ordersList(
                          completed,
                          type: _OrderListType.completed,
                          emptyTitle: 'لسه مفيش طلبات مكتملة',
                          emptySubtitle:
                              'الطلبات اللي سلمتها هتظهر هنا',
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: EdgeInsets.fromLTRB(18.w, 14.h, 18.w, 14.h),
      child: Row(
        children: [
          Container(
            width: 41.w,
            height: 41.w,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: border),
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              color: darkTeal,
              size: 20.sp,
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'الطلبات',
                style: GoogleFonts.cairo(
                  color: textDark,
                  fontSize: 23.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'تابع كل مشاويرك من مكان واحد',
                style: GoogleFonts.cairo(
                  color: textGrey,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(width: 10.w),
          const _BringoMark(),
        ],
      ),
    );
  }

  Widget _tabs() {
    return Container(
      height: 51.h,
      margin: EdgeInsets.symmetric(horizontal: 18.w),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3F2),
        borderRadius: BorderRadius.circular(17.r),
      ),
      child: TabBar(
        controller: tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        labelColor: darkTeal,
        unselectedLabelColor: textGrey,
        dividerColor: Colors.transparent,
        labelPadding: EdgeInsets.zero,
        labelStyle: GoogleFonts.cairo(
          fontSize: 10.sp,
          fontWeight: FontWeight.w900,
        ),
        unselectedLabelStyle: GoogleFonts.cairo(
          fontSize: 9.5.sp,
          fontWeight: FontWeight.w700,
        ),
        tabs: const [
          Tab(text: 'متاحة'),
          Tab(text: 'معايا'),
          Tab(text: 'مكتملة'),
        ],
      ),
    );
  }

  Widget _ordersList(
    List<Map<String, dynamic>> orders, {
    required _OrderListType type,
    required String emptyTitle,
    required String emptySubtitle,
  }) {
    if (orders.isEmpty) {
      return _emptyState(
        icon: type == _OrderListType.available
            ? Icons.notifications_none_rounded
            : type == _OrderListType.active
                ? Icons.delivery_dining_rounded
                : Icons.task_alt_rounded,
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }

    return RefreshIndicator(
      color: teal,
      onRefresh: () async {
        await FirebaseDatabase.instance.ref('orders').get();
      },
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(18.w, 8.h, 18.w, 120.h),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: orders.length,
        separatorBuilder: (_, __) => SizedBox(height: 11.h),
        itemBuilder: (_, index) {
          final order = orders[index];
          final key = order['firebaseKey']?.toString() ?? '';

          return _OrderCard(
            order: order,
            type: type,
            loading: loadingOrderId == key,
            onAccept: () => acceptOrder(order),
            onDetails: () {
              context.push(AppRoutes.orderDetails, extra: order);
            },
            onPickedUp: () => updateStatus(order, 'pickedUp'),
            onDelivery: () => updateStatus(order, 'onDelivery'),
            onCompleted: () => updateStatus(order, 'completed'),
          );
        },
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(30.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70.w,
              height: 70.w,
              decoration: const BoxDecoration(
                color: mint,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: teal, size: 31.sp),
            ),
            SizedBox(height: 14.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                color: textDark,
                fontSize: 14.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                color: textGrey,
                fontSize: 10.sp,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _OrderListType { available, active, completed }

class _OrderCard extends StatelessWidget {
  static const teal = Color(0xFF1F5A59);
  static const darkTeal = Color(0xFF174746);
  static const lime = Color(0xFFDDFB8A);
  static const mint = Color(0xFFEAF3F2);
  static const background = Color(0xFFF7FAF8);
  static const textDark = Color(0xFF182322);
  static const textGrey = Color(0xFF77817F);
  static const border = Color(0xFFE3EAE8);

  final Map<String, dynamic> order;
  final _OrderListType type;
  final bool loading;
  final VoidCallback onAccept;
  final VoidCallback onDetails;
  final VoidCallback onPickedUp;
  final VoidCallback onDelivery;
  final VoidCallback onCompleted;

  const _OrderCard({
    required this.order,
    required this.type,
    required this.loading,
    required this.onAccept,
    required this.onDetails,
    required this.onPickedUp,
    required this.onDelivery,
    required this.onCompleted,
  });

  String _firstText(List<dynamic> values, [String fallback = '']) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != 'null') return text;
    }
    return fallback;
  }

  double _num(dynamic value) =>
      double.tryParse(value?.toString() ?? '0') ?? 0;

  String get status =>
      _firstText([order['status'], order['orderStatus']], 'pending');

  String get storeName {
    final store = order['store'] is Map
        ? Map<String, dynamic>.from(order['store'] as Map)
        : <String, dynamic>{};

    return _firstText([
      order['storeName'],
      order['restaurantName'],
      order['pharmacyName'],
      order['merchantName'],
      order['vendorName'],
      order['shopName'],
      order['providerName'],
      store['name'],
      store['storeName'],
    ], 'متجر Bringo');
  }

  String get pickupAddress {
    final store = order['store'] is Map
        ? Map<String, dynamic>.from(order['store'] as Map)
        : <String, dynamic>{};

    return _firstText([
      order['storeAddress'],
      order['pickupAddress'],
      order['merchantAddress'],
      order['restaurantAddress'],
      order['pharmacyAddress'],
      store['address'],
      store['area'],
    ], 'عنوان الاستلام غير متاح');
  }

  String get deliveryAddress {
    final address = order['address'] is Map
        ? Map<String, dynamic>.from(order['address'] as Map)
        : <String, dynamic>{};

    return _firstText([
      order['customerAddress'],
      order['deliveryAddress'],
      order['addressText'],
      address['fullAddress'],
      address['address'],
      address['area'],
      order['address'] is String ? order['address'] : null,
    ], 'عنوان العميل غير متاح');
  }

  int get itemsCount {
    final items = order['items'];
    if (items is List) return items.length;
    if (items is Map) return items.length;
    return int.tryParse(order['itemsCount']?.toString() ?? '0') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final total = _num(order['total']);
    final deliveryFee = _num(order['deliveryFee']);
    final id = _firstText([order['id'], order['firebaseKey']], '-');

    return Container(
      padding: EdgeInsets.all(15.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              _statusBadge(),
              const Spacer(),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      storeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        color: textDark,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      'طلب #${_shortId(id)}',
                      style: GoogleFonts.cairo(
                        color: textGrey,
                        fontSize: 8.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              Container(
                width: 41.w,
                height: 41.w,
                decoration: const BoxDecoration(
                  color: mint,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.storefront_rounded,
                  color: teal,
                  size: 20.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 13.h),

          _routeLine(
            icon: Icons.storefront_outlined,
            label: 'الاستلام',
            text: pickupAddress,
            top: true,
          ),
          _routeLine(
            icon: Icons.location_on_outlined,
            label: 'التسليم',
            text: deliveryAddress,
            top: false,
          ),

          SizedBox(height: 12.h),

          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 11.w,
              vertical: 10.h,
            ),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(13.r),
            ),
            child: Row(
              children: [
                _smallValue(
                  'الإجمالي',
                  '${total.toStringAsFixed(0)} ج',
                ),
                _verticalDivider(),
                _smallValue(
                  'التوصيل',
                  '${deliveryFee.toStringAsFixed(0)} ج',
                  highlighted: true,
                ),
                _verticalDivider(),
                _smallValue(
                  'الطلبات',
                  itemsCount == 0 ? '-' : '$itemsCount',
                ),
              ],
            ),
          ),

          SizedBox(height: 13.h),
          _actions(),
        ],
      ),
    );
  }

  Widget _routeLine({
    required IconData icon,
    required String label,
    required String text,
    required bool top,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    color: textGrey,
                    fontSize: 8.5.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.cairo(
                    color: textDark,
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          Column(
            children: [
              Container(
                width: 31.w,
                height: 31.w,
                decoration: BoxDecoration(
                  color: top ? mint : lime.withOpacity(.55),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: darkTeal,
                  size: 15.sp,
                ),
              ),
              if (top)
                Container(
                  width: 1.5.w,
                  height: 17.h,
                  color: border,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _smallValue(
    String label,
    String value, {
    bool highlighted = false,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.cairo(
              color: darkTeal,
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 1.h),
          Container(
            padding: highlighted
                ? EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h)
                : EdgeInsets.zero,
            decoration: highlighted
                ? BoxDecoration(
                    color: lime,
                    borderRadius: BorderRadius.circular(7.r),
                  )
                : null,
            child: Text(
              label,
              style: GoogleFonts.cairo(
                color: highlighted ? darkTeal : textGrey,
                fontSize: 8.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 30.h,
      color: border,
    );
  }

  Widget _actions() {
    if (type == _OrderListType.available) {
      return Row(
        children: [
          Expanded(
            child: _secondaryButton(
              'التفاصيل',
              Icons.visibility_outlined,
              onDetails,
            ),
          ),
          SizedBox(width: 9.w),
          Expanded(
            flex: 2,
            child: _primaryButton(
              'قبول الطلب',
              Icons.check_rounded,
              onAccept,
            ),
          ),
        ],
      );
    }

    if (type == _OrderListType.completed) {
      return _secondaryButton(
        'عرض تفاصيل الطلب',
        Icons.receipt_long_outlined,
        onDetails,
        fullWidth: true,
      );
    }

    final normalized = status;

    if (normalized == 'assigned') {
      return _primaryButton(
        'استلمت الطلب من المتجر',
        Icons.inventory_2_outlined,
        onPickedUp,
        fullWidth: true,
      );
    }

    if (normalized == 'pickedUp' || normalized == 'picked') {
      return _primaryButton(
        'ابدأ التوصيل للعميل',
        Icons.delivery_dining_rounded,
        onDelivery,
        fullWidth: true,
      );
    }

    if (normalized == 'onDelivery' || normalized == 'way') {
      return _primaryButton(
        'تم التسليم للعميل',
        Icons.task_alt_rounded,
        onCompleted,
        fullWidth: true,
      );
    }

    return _secondaryButton(
      'عرض التفاصيل',
      Icons.visibility_outlined,
      onDetails,
      fullWidth: true,
    );
  }

  Widget _primaryButton(
    String text,
    IconData icon,
    VoidCallback onTap, {
    bool fullWidth = false,
  }) {
    final button = SizedBox(
      height: 47.h,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onTap,
        icon: loading
            ? SizedBox(
                width: 16.w,
                height: 16.w,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 18.sp),
        label: Text(
          text,
          style: GoogleFonts.cairo(
            fontSize: 10.5.sp,
            fontWeight: FontWeight.w900,
          ),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: darkTeal,
          foregroundColor: Colors.white,
          disabledBackgroundColor: darkTeal.withOpacity(.55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13.r),
          ),
        ),
      ),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }

  Widget _secondaryButton(
    String text,
    IconData icon,
    VoidCallback onTap, {
    bool fullWidth = false,
  }) {
    final button = SizedBox(
      height: 47.h,
      child: OutlinedButton.icon(
        onPressed: loading ? null : onTap,
        icon: Icon(icon, size: 17.sp),
        label: Text(
          text,
          style: GoogleFonts.cairo(
            fontSize: 10.sp,
            fontWeight: FontWeight.w900,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: darkTeal,
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13.r),
          ),
        ),
      ),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }

  Widget _statusBadge() {
    String text = 'جديد';
    Color bg = lime;
    Color fg = darkTeal;

    if (status == 'confirmed') text = 'مؤكد';
    if (status == 'assigned') {
      text = 'مقبول';
      bg = mint;
    }
    if (status == 'pickedUp' || status == 'picked') {
      text = 'تم الاستلام';
      bg = mint;
    }
    if (status == 'onDelivery' || status == 'way') {
      text = 'في الطريق';
      bg = lime;
    }
    if (const {'completed', 'delivered', 'done'}.contains(status)) {
      text = 'تم التسليم';
      bg = const Color(0xFFE7F6EC);
      fg = const Color(0xFF237A42);
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 9.w,
        vertical: 5.h,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        text,
        style: GoogleFonts.cairo(
          color: fg,
          fontSize: 8.5.sp,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  String _shortId(String value) {
    if (value.isEmpty || value == '-') return '-';
    if (value.length <= 6) return value.toUpperCase();
    return value.substring(value.length - 6).toUpperCase();
  }
}

class _BringoMark extends StatelessWidget {
  const _BringoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40.w,
      height: 40.w,
      decoration: BoxDecoration(
        color: const Color(0xFF174746),
        borderRadius: BorderRadius.circular(13.r),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'b',
            style: TextStyle(
              color: Colors.white,
              fontSize: 25.sp,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          Positioned(
            top: 7.h,
            right: 7.w,
            child: Transform.rotate(
              angle: -.5,
              child: Container(
                width: 10.w,
                height: 6.h,
                decoration: const BoxDecoration(
                  color: Color(0xFFDDFB8A),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersShimmer extends StatefulWidget {
  const _OrdersShimmer();

  @override
  State<_OrdersShimmer> createState() => _OrdersShimmerState();
}

class _OrdersShimmerState extends State<_OrdersShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Widget bone(double width, double height, {double radius = 14}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE4E9E7),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final x = controller.value * 2 - 1;

        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-1.6 + x, 0),
            end: Alignment(1.6 + x, 0),
            colors: const [
              Color(0xFFE4E9E7),
              Color(0xFFF9FBFA),
              Color(0xFFE4E9E7),
            ],
            stops: const [.25, .5, .75],
          ).createShader(bounds),
          child: ListView(
            padding: EdgeInsets.fromLTRB(18.w, 8.h, 18.w, 120.h),
            children: [
              bone(double.infinity, 260.h, radius: 20.r),
              SizedBox(height: 11.h),
              bone(double.infinity, 260.h, radius: 20.r),
            ],
          ),
        );
      },
    );
  }
}
