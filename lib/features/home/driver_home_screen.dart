import 'package:bringo_driver/core/routes/app_routes.dart';
import 'package:bringo_driver/core/session/driver_session.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen>
    with SingleTickerProviderStateMixin {
  static const Color teal = Color(0xFF1F5A59);
  static const Color darkTeal = Color(0xFF174746);
  static const Color lime = Color(0xFFDDFB8A);
  static const Color mint = Color(0xFFEAF3F2);
  static const Color background = Color(0xFFF7FAF8);
  static const Color textDark = Color(0xFF182322);
  static const Color textGrey = Color(0xFF77817F);
  static const Color border = Color(0xFFE3EAE8);

  final driverId = DriverSession.driverId ?? '';
  final driverName = DriverSession.driverName ?? 'طيار Bringo';
  final driverPhone = DriverSession.driverPhone ?? '';

  bool accepting = false;
  String? acceptingOrderId;
  bool isAvailable = true;

  List<Map<String, dynamic>> _parseOrders(dynamic value) {
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
      final aTime = int.tryParse(a['createdAt']?.toString() ?? '0') ?? 0;
      final bTime = int.tryParse(b['createdAt']?.toString() ?? '0') ?? 0;
      return bTime.compareTo(aTime);
    });

    return orders;
  }

  String _firstText(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != 'null') return text;
    }
    return '';
  }

  Future<void> acceptOrder(Map<String, dynamic> order) async {
    final key = order['firebaseKey']?.toString() ?? '';
    if (key.isEmpty || accepting) return;

    try {
      setState(() {
        accepting = true;
        acceptingOrderId = key;
      });

      final orderRef = FirebaseDatabase.instance.ref('orders/$key');
      final freshSnapshot = await orderRef.get();

      if (!freshSnapshot.exists || freshSnapshot.value == null) {
        _msg('الطلب لم يعد موجودًا');
        return;
      }

      final freshOrder =
          Map<String, dynamic>.from(freshSnapshot.value as Map);

      final currentDriverId =
          freshOrder['driverId']?.toString().trim() ?? '';

      final currentStatus =
          freshOrder['status']?.toString() ??
          freshOrder['orderStatus']?.toString() ??
          'pending';

      if (currentDriverId.isNotEmpty) {
        _msg('تم قبول الطلب بواسطة طيار آخر');
        return;
      }

      final normalizedStatus = currentStatus.trim().toLowerCase();
      const allowedStatuses = {
        'pending',
        'new',
        'confirmed',
        'accepted',
        'approved',
        'preparing',
        'ready',
        'ready_for_pickup',
        'readyforpickup',
      };

      if (!allowedStatuses.contains(normalizedStatus)) {
        _msg('هذا الطلب غير متاح الآن');
        return;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      await orderRef.update({
        'driverId': driverId,
        'driverName': driverName,
        'driverPhone': driverPhone,

        // المشروع الحالي يعتمد status، ونكتب orderStatus أيضًا
        // للتوافق مع أي شاشة قديمة ما زالت تقرأه.
        'status': 'assigned',
        'orderStatus': 'assigned',

        'assignedAt': now,
        'acceptedAt': now,
        'updatedAt': now,
      });

      _msg('تم قبول الطلب.. جاهز للمشوار 🚀');
    } catch (_) {
      _msg('حدث خطأ أثناء قبول الطلب');
    } finally {
      if (mounted) {
        setState(() {
          accepting = false;
          acceptingOrderId = null;
        });
      }
    }
  }

  Future<void> rejectOrder(Map<String, dynamic> order) async {
    _msg('تم تجاهل الطلب');
  }

  Future<void> toggleAvailability() async {
    final newValue = !isAvailable;
    setState(() => isAvailable = newValue);

    if (driverId.isEmpty) return;

    try {
      await FirebaseDatabase.instance.ref('drivers/$driverId').update({
        'isAvailable': newValue,
        'lastSeenAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {
      if (mounted) {
        setState(() => isAvailable = !newValue);
      }
      _msg('تعذر تحديث حالة التوفر');
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
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: darkTeal,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance.ref('orders').onValue,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const _DriverHomeShimmer();
              }

              if (snapshot.hasError) {
                return _errorState();
              }

              final orders = _parseOrders(snapshot.data?.snapshot.value);

              final availableOrders = orders.where((order) {
                final status = _firstText([
                  order['status'],
                  order['orderStatus'],
                ]).toLowerCase();
                final assignedDriverId =
                    order['driverId']?.toString().trim() ?? '';

                return assignedDriverId.isEmpty &&
                    _isAvailableForDriver(status);
              }).toList();

              final myOrders = orders.where((order) {
                return order['driverId']?.toString() == driverId;
              }).toList();

              final completedOrders = myOrders.where((order) {
                final status = _firstText([
                  order['status'],
                  order['orderStatus'],
                ]).toLowerCase();
                return status == 'completed' || status == 'delivered';
              }).toList();

              final activeOrders = myOrders.where((order) {
                final status = _firstText([
                  order['status'],
                  order['orderStatus'],
                ]).toLowerCase();
                return status != 'completed' &&
                    status != 'delivered' &&
                    status != 'cancelled' &&
                    status != 'canceled';
              }).toList();

              final activeOrder =
                  activeOrders.isNotEmpty ? activeOrders.first : null;

              final todayEarnings = _todayEarnings(completedOrders);

              return RefreshIndicator(
                color: teal,
                onRefresh: () async {
                  await FirebaseDatabase.instance.ref('orders').get();
                },
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    18.w,
                    14.h,
                    18.w,
                    120.h,
                  ),
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  children: [
                    _topHeader(),
                    SizedBox(height: 17.h),

                    _availabilityCard(),
                    SizedBox(height: 22.h),

                    if (activeOrder != null) ...[
                      _sectionTitle(
                        title: 'المشوار الحالي',
                        subtitle: 'كمّل طلبك الحالي قبل ما تبدأ مشوار جديد',
                      ),
                      SizedBox(height: 11.h),
                      _CurrentOrderCard(
                        order: activeOrder,
                        onTap: () {
                          context.push(
                            AppRoutes.orderDetails,
                            extra: activeOrder,
                          );
                        },
                      ),
                      SizedBox(height: 24.h),
                    ],

                    _sectionTitle(
                      title: 'أداء اليوم',
                      subtitle: 'ملخص سريع لشغلك',
                    ),
                    SizedBox(height: 11.h),

                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            title: 'أرباح اليوم',
                            value: '${todayEarnings.toStringAsFixed(0)} ج',
                            icon: Icons.account_balance_wallet_outlined,
                            highlighted: true,
                          ),
                        ),
                        SizedBox(width: 11.w),
                        Expanded(
                          child: _statCard(
                            title: 'تم تسليمها',
                            value: completedOrders.length.toString(),
                            icon: Icons.check_circle_outline_rounded,
                          ),
                        ),
                        SizedBox(width: 11.w),
                        Expanded(
                          child: _statCard(
                            title: 'متاحة',
                            value: availableOrders.length.toString(),
                            icon: Icons.notifications_active_outlined,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 27.h),

                    Row(
                      children: [
                        if (availableOrders.isNotEmpty)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 5.h,
                            ),
                            decoration: BoxDecoration(
                              color: lime,
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Text(
                              '${availableOrders.length} متاح',
                              style: GoogleFonts.cairo(
                                color: darkTeal,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        const Spacer(),
                        Text(
                          'طلبات متاحة',
                          style: GoogleFonts.cairo(
                            color: textDark,
                            fontSize: 19.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'اختار المشوار المناسب ليك',
                        style: GoogleFonts.cairo(
                          color: textGrey,
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(height: 13.h),

                    if (!isAvailable)
                      _emptyBox(
                        icon: Icons.pause_circle_outline_rounded,
                        title: 'أنت غير متاح حاليًا',
                        subtitle:
                            'فعّل استقبال الطلبات علشان المشاوير الجديدة تظهر لك',
                      )
                    else if (availableOrders.isEmpty)
                      _emptyBox(
                        icon: Icons.delivery_dining_rounded,
                        title: 'مفيش طلبات جديدة دلوقتي',
                        subtitle:
                            'خليك متاح، أول ما ينزل طلب جديد هيظهر هنا تلقائيًا',
                      )
                    else
                      ...availableOrders.take(8).map(
                        (order) => Padding(
                          padding: EdgeInsets.only(bottom: 13.h),
                          child: _OrderRequestCard(
                            order: order,
                            accepting:
                                accepting &&
                                acceptingOrderId ==
                                    order['firebaseKey']?.toString(),
                            onAccept: () => acceptOrder(order),
                            onReject: () => rejectOrder(order),
                            onDetails: () {
                              context.push(
                                AppRoutes.orderDetails,
                                extra: order,
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  bool _isAvailableForDriver(String rawStatus) {
    final status = rawStatus.trim().toLowerCase();
    return const {
      'pending',
      'new',
      'confirmed',
      'accepted',
      'approved',
      'preparing',
      'ready',
      'ready_for_pickup',
      'readyforpickup',
    }.contains(status);
  }

  double _todayEarnings(List<Map<String, dynamic>> completedOrders) {
    final now = DateTime.now();

    return completedOrders.fold<double>(0, (sum, order) {
      final millis = int.tryParse(
            (order['completedAt'] ??
                    order['deliveredAt'] ??
                    order['updatedAt'] ??
                    order['createdAt'] ??
                    0)
                .toString(),
          ) ??
          0;

      if (millis > 0) {
        final date = DateTime.fromMillisecondsSinceEpoch(millis);
        if (date.year != now.year ||
            date.month != now.month ||
            date.day != now.day) {
          return sum;
        }
      }

      final earning = double.tryParse(
            (order['driverEarning'] ??
                    order['driverFee'] ??
                    order['deliveryFee'] ??
                    0)
                .toString(),
          ) ??
          0;

      return sum + earning;
    });
  }

  Widget _topHeader() {
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 45.w,
              height: 45.w,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: border),
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                color: darkTeal,
                size: 23.sp,
              ),
            ),
            Positioned(
              top: 2.h,
              right: 3.w,
              child: Container(
                width: 9.w,
                height: 9.w,
                decoration: BoxDecoration(
                  color: lime,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'أهلاً، ${_shortName(driverName)} 👋',
              style: GoogleFonts.cairo(
                color: textDark,
                fontSize: 20.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              'جاهز لمشاوير النهارده؟',
              style: GoogleFonts.cairo(
                color: textGrey,
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(width: 10.w),
        const _BringoMark(size: 42),
      ],
    );
  }

  String _shortName(String value) {
    final parts =
        value.trim().split(' ').where((e) => e.trim().isNotEmpty).toList();
    if (parts.isEmpty) return 'طيار Bringo';
    return parts.take(2).join(' ');
  }

  Widget _availabilityCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: EdgeInsets.symmetric(
        horizontal: 17.w,
        vertical: 15.h,
      ),
      decoration: BoxDecoration(
        color: isAvailable ? darkTeal : Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: isAvailable ? null : Border.all(color: border),
      ),
      child: Row(
        children: [
          Transform.scale(
            scale: .9,
            child: Switch(
              value: isAvailable,
              activeColor: darkTeal,
              activeTrackColor: lime,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFC8D0CE),
              onChanged: (_) => toggleAvailability(),
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isAvailable
                        ? 'متاح لاستقبال الطلبات'
                        : 'غير متاح حاليًا',
                    style: GoogleFonts.cairo(
                      color: isAvailable ? Colors.white : textDark,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(width: 7.w),
                  Container(
                    width: 8.w,
                    height: 8.w,
                    decoration: BoxDecoration(
                      color: isAvailable ? lime : Colors.grey.shade400,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 3.h),
              Text(
                isAvailable
                    ? 'هنعرض لك أي طلب جديد فورًا'
                    : 'فعّل الحالة لما تكون جاهز للشغل',
                style: GoogleFonts.cairo(
                  color: isAvailable
                      ? Colors.white.withOpacity(.66)
                      : textGrey,
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          title,
          style: GoogleFonts.cairo(
            color: textDark,
            fontSize: 18.sp,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          subtitle,
          style: GoogleFonts.cairo(
            color: textGrey,
            fontSize: 10.5.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    bool highlighted = false,
  }) {
    return Container(
      height: 105.h,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: highlighted ? mint : Colors.white,
        borderRadius: BorderRadius.circular(19.r),
        border: Border.all(
          color: highlighted ? teal.withOpacity(.10) : border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Icon(
            icon,
            color: teal,
            size: 20.sp,
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            style: GoogleFonts.cairo(
              color: darkTeal,
              fontSize: 18.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            title,
            maxLines: 1,
            style: GoogleFonts.cairo(
              color: textGrey,
              fontSize: 9.5.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyBox({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: 30.h,
        horizontal: 20.w,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Container(
            width: 58.w,
            height: 58.w,
            decoration: const BoxDecoration(
              color: mint,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: teal, size: 28.sp),
          ),
          SizedBox(height: 12.h),
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
              fontSize: 11.sp,
              height: 1.55,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState() {
    return ListView(
      padding: EdgeInsets.all(24.w),
      children: [
        SizedBox(height: 150.h),
        Icon(
          Icons.cloud_off_rounded,
          color: textGrey,
          size: 52.sp,
        ),
        SizedBox(height: 14.h),
        Text(
          'تعذر تحميل الطلبات',
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            color: textDark,
            fontSize: 17.sp,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 5.h),
        Text(
          'تحقق من الإنترنت وحاول مرة أخرى',
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            color: textGrey,
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _OrderRequestCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool accepting;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onDetails;

  const _OrderRequestCard({
    required this.order,
    required this.accepting,
    required this.onAccept,
    required this.onReject,
    required this.onDetails,
  });

  static const Color teal = Color(0xFF1F5A59);
  static const Color darkTeal = Color(0xFF174746);
  static const Color lime = Color(0xFFDDFB8A);
  static const Color mint = Color(0xFFEAF3F2);
  static const Color textDark = Color(0xFF182322);
  static const Color textGrey = Color(0xFF77817F);
  static const Color border = Color(0xFFE3EAE8);

  String _firstText(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != 'null') return text;
    }
    return '';
  }

  Map<String, dynamic> _nestedMap(String key) {
    final value = order[key];
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  String _storeName() {
    final store = _nestedMap('store');
    final merchant = _nestedMap('merchant');
    final provider = _nestedMap('provider');

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
      merchant['name'],
      provider['name'],
    ]);
  }

  String _storeAddress() {
    final store = _nestedMap('store');
    final merchant = _nestedMap('merchant');
    final provider = _nestedMap('provider');

    return _firstText([
      order['storeAddress'],
      order['pickupAddress'],
      order['merchantAddress'],
      order['restaurantAddress'],
      order['pharmacyAddress'],
      order['providerAddress'],
      store['address'],
      store['area'],
      merchant['address'],
      provider['address'],
    ]);
  }

  String _customerAddress() {
    final address = _nestedMap('address');

    return _firstText([
      order['customerAddress'],
      order['deliveryAddress'],
      order['addressText'],
      address['fullAddress'],
      address['address'],
      address['area'],
    ]);
  }

  String _storeImage() {
    final store = _nestedMap('store');

    return _firstText([
      order['storeLogo'],
      order['storeImage'],
      order['restaurantImage'],
      order['merchantImage'],
      store['logo'],
      store['image'],
      store['photo'],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final storeName = _storeName();
    final storeAddress = _storeAddress();
    final customerAddress = _customerAddress();

    final total =
        double.tryParse(order['total']?.toString() ?? '0') ?? 0;

    final deliveryFee =
        double.tryParse(order['deliveryFee']?.toString() ?? '0') ?? 0;

    final items = _parseItems(order['items']);

    return Container(
      padding: EdgeInsets.all(15.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              _ResolvedStoreAvatar(
                storeId: order['storeId']?.toString() ?? '',
                directImage: _storeImage(),
              ),
              SizedBox(width: 11.w),
              Expanded(
                child: _ResolvedStoreName(
                  storeId: order['storeId']?.toString() ?? '',
                  directName: storeName,
                  subtitle: 'طلب جديد جاهز للقبول',
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 9.w,
                  vertical: 5.h,
                ),
                decoration: BoxDecoration(
                  color: lime,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  'جديد',
                  style: GoogleFonts.cairo(
                    color: darkTeal,
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 15.h),

          _routeLine(
            icon: Icons.storefront_rounded,
            title: 'الاستلام',
            value: storeAddress.isEmpty
                ? storeName.isEmpty
                    ? 'عنوان المتجر يظهر في التفاصيل'
                    : storeName
                : storeAddress,
            active: true,
          ),

          Padding(
            padding: EdgeInsets.only(right: 15.w),
            child: Container(
              width: 1.5.w,
              height: 15.h,
              alignment: Alignment.centerRight,
              color: const Color(0xFFD8E1DE),
            ),
          ),

          _routeLine(
            icon: Icons.location_on_rounded,
            title: 'التوصيل',
            value: customerAddress.isEmpty
                ? 'عنوان العميل غير متوفر'
                : customerAddress,
          ),

          SizedBox(height: 15.h),

          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 12.w,
              vertical: 10.h,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9F8),
              borderRadius: BorderRadius.circular(15.r),
            ),
            child: Row(
              children: [
                _metric(
                  '${deliveryFee.toStringAsFixed(0)} ج',
                  'أجر التوصيل',
                ),
                _divider(),
                _metric(
                  '${items.length}',
                  'منتجات',
                ),
                _divider(),
                _metric(
                  '${total.toStringAsFixed(0)} ج',
                  'قيمة الطلب',
                ),
              ],
            ),
          ),

          SizedBox(height: 14.h),

          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 45.h,
                  child: OutlinedButton(
                    onPressed: onDetails,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: darkTeal,
                      side: const BorderSide(color: border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13.r),
                      ),
                    ),
                    child: Text(
                      'التفاصيل',
                      style: GoogleFonts.cairo(
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 9.w),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 45.h,
                  child: ElevatedButton(
                    onPressed: accepting ? null : onAccept,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: teal,
                      disabledBackgroundColor: teal.withOpacity(.45),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13.r),
                      ),
                    ),
                    child: accepting
                        ? SizedBox(
                            width: 19.w,
                            height: 19.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'قبول المشوار',
                                style: GoogleFonts.cairo(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(width: 7.w),
                              Icon(
                                Icons.arrow_back_rounded,
                                size: 18.sp,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 7.h),

          Center(
            child: TextButton(
              onPressed: onReject,
              child: Text(
                'مش مناسب ليا',
                style: GoogleFonts.cairo(
                  color: textGrey,
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _routeLine({
    required IconData icon,
    required String title,
    required String value,
    bool active = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      textDirection: TextDirection.rtl,
      children: [
        Container(
          width: 31.w,
          height: 31.w,
          decoration: BoxDecoration(
            color: active ? mint : const Color(0xFFF1F4F3),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: active ? teal : textGrey,
            size: 16.sp,
          ),
        ),
        SizedBox(width: 9.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                title,
                style: GoogleFonts.cairo(
                  color: textGrey,
                  fontSize: 9.5.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: GoogleFonts.cairo(
                  color: textDark,
                  fontSize: 11.5.sp,
                  height: 1.45,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metric(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            style: GoogleFonts.cairo(
              color: darkTeal,
              fontSize: 13.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            label,
            maxLines: 1,
            style: GoogleFonts.cairo(
              color: textGrey,
              fontSize: 8.8.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 29.h,
      color: border,
    );
  }

  static List<Map<String, dynamic>> _parseItems(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return value
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    if (value is Map) {
      return value.values
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    return [];
  }
}

class _CurrentOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTap;

  const _CurrentOrderCard({
    required this.order,
    required this.onTap,
  });

  static const Color teal = Color(0xFF1F5A59);
  static const Color darkTeal = Color(0xFF174746);
  static const Color lime = Color(0xFFDDFB8A);

  String _text(List<dynamic> values) {
    for (final value in values) {
      final result = value?.toString().trim() ?? '';
      if (result.isNotEmpty && result != 'null') return result;
    }
    return '';
  }

  String _storeName() {
    final store = order['store'] is Map
        ? Map<String, dynamic>.from(order['store'] as Map)
        : <String, dynamic>{};

    return _text([
      order['storeName'],
      order['restaurantName'],
      order['pharmacyName'],
      order['merchantName'],
      order['vendorName'],
      order['shopName'],
      order['providerName'],
      store['name'],
      store['storeName'],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final storeName = _storeName();
    final status = _text([
      order['orderStatus'],
      order['status'],
    ]);

    return Container(
      padding: EdgeInsets.all(17.w),
      decoration: BoxDecoration(
        color: darkTeal,
        borderRadius: BorderRadius.circular(23.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                width: 43.w,
                height: 43.w,
                decoration: BoxDecoration(
                  color: lime,
                  borderRadius: BorderRadius.circular(13.r),
                ),
                child: Icon(
                  Icons.delivery_dining_rounded,
                  color: darkTeal,
                  size: 23.sp,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _ResolvedStoreName(
                      storeId: order['storeId']?.toString() ?? '',
                      directName: storeName,
                      subtitle: _statusText(status),
                      darkMode: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          SizedBox(
            height: 44.h,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: lime,
                foregroundColor: darkTeal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13.r),
                ),
              ),
              child: Text(
                'متابعة المشوار',
                style: GoogleFonts.cairo(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _statusText(String status) {
    switch (status) {
      case 'assigned':
        return 'اتجه للمتجر لاستلام الطلب';
      case 'pickedUp':
      case 'pickedup':
        return 'تم الاستلام.. اتجه للعميل';
      case 'onDelivery':
      case 'ondelivery':
        return 'الطلب في الطريق للعميل';
      case 'arrived':
        return 'وصلت لعنوان العميل';
      default:
        return 'المشوار قيد التنفيذ';
    }
  }
}

class _ResolvedStoreName extends StatelessWidget {
  final String storeId;
  final String directName;
  final String subtitle;
  final bool darkMode;

  const _ResolvedStoreName({
    required this.storeId,
    required this.directName,
    required this.subtitle,
    this.darkMode = false,
  });

  String _readName(dynamic value) {
    if (value is! Map) return '';
    final map = Map<String, dynamic>.from(value);
    for (final candidate in [
      map['name'],
      map['storeName'],
      map['businessName'],
      map['title'],
    ]) {
      final text = candidate?.toString().trim() ?? '';
      if (text.isNotEmpty && text != 'null') return text;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    Widget content(String name) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            name.isEmpty ? 'متجر Bringo' : name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: GoogleFonts.cairo(
              color: darkMode ? Colors.white : const Color(0xFF182322),
              fontSize: darkMode ? 14.sp : 15.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: GoogleFonts.cairo(
              color: darkMode
                  ? Colors.white.withOpacity(.65)
                  : const Color(0xFF77817F),
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    if (directName.trim().isNotEmpty) {
      return content(directName.trim());
    }

    if (storeId.trim().isEmpty) {
      return content('');
    }

    return FutureBuilder<DataSnapshot>(
      future: FirebaseDatabase.instance.ref('stores/$storeId').get(),
      builder: (context, snapshot) {
        final resolved =
            snapshot.hasData ? _readName(snapshot.data?.value) : '';
        return content(resolved);
      },
    );
  }
}

class _ResolvedStoreAvatar extends StatelessWidget {
  final String storeId;
  final String directImage;

  const _ResolvedStoreAvatar({
    required this.storeId,
    required this.directImage,
  });

  String _readImage(dynamic value) {
    if (value is! Map) return '';
    final map = Map<String, dynamic>.from(value);
    for (final candidate in [
      map['logo'],
      map['image'],
      map['storeLogo'],
      map['storeImage'],
      map['photo'],
      map['imageUrl'],
    ]) {
      final text = candidate?.toString().trim() ?? '';
      if (text.isNotEmpty && text != 'null') return text;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (directImage.trim().isNotEmpty || storeId.trim().isEmpty) {
      return _StoreAvatar(image: directImage.trim());
    }

    return FutureBuilder<DataSnapshot>(
      future: FirebaseDatabase.instance.ref('stores/$storeId').get(),
      builder: (context, snapshot) {
        final image =
            snapshot.hasData ? _readImage(snapshot.data?.value) : '';
        return _StoreAvatar(image: image);
      },
    );
  }
}

class _StoreAvatar extends StatelessWidget {
  final String image;

  const _StoreAvatar({required this.image});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50.w,
      height: 50.w,
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: const Color(0xFFE3EAE8),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11.r),
        child: image.isEmpty
            ? _fallback()
            : Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(),
              ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: const Color(0xFFEAF3F2),
      child: Icon(
        Icons.storefront_rounded,
        color: const Color(0xFF1F5A59),
        size: 24.sp,
      ),
    );
  }
}

class _DriverHomeShimmer extends StatefulWidget {
  const _DriverHomeShimmer();

  @override
  State<_DriverHomeShimmer> createState() => _DriverHomeShimmerState();
}

class _DriverHomeShimmerState extends State<_DriverHomeShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Widget bone(
    double width,
    double height, {
    double radius = 12,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE5EAE8),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final x = controller.value * 2 - 1;

        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.6 + x, 0),
              end: Alignment(1.6 + x, 0),
              colors: const [
                Color(0xFFE4E9E7),
                Color(0xFFF9FBFA),
                Color(0xFFE4E9E7),
              ],
              stops: const [.25, .5, .75],
            ).createShader(bounds);
          },
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              18.w,
              15.h,
              18.w,
              120.h,
            ),
            physics: const NeverScrollableScrollPhysics(),
            children: [
              Row(
                children: [
                  bone(45.w, 45.w, radius: 23.r),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      bone(145.w, 16.h),
                      SizedBox(height: 8.h),
                      bone(110.w, 10.h),
                    ],
                  ),
                  SizedBox(width: 10.w),
                  bone(42.w, 42.w, radius: 14.r),
                ],
              ),
              SizedBox(height: 20.h),
              bone(double.infinity, 76.h, radius: 22.r),
              SizedBox(height: 24.h),
              bone(90.w, 17.h),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(child: bone(double.infinity, 105.h, radius: 19.r)),
                  SizedBox(width: 11.w),
                  Expanded(child: bone(double.infinity, 105.h, radius: 19.r)),
                  SizedBox(width: 11.w),
                  Expanded(child: bone(double.infinity, 105.h, radius: 19.r)),
                ],
              ),
              SizedBox(height: 28.h),
              bone(115.w, 18.h),
              SizedBox(height: 13.h),
              bone(double.infinity, 310.h, radius: 22.r),
            ],
          ),
        );
      },
    );
  }
}

class _BringoMark extends StatelessWidget {
  final double size;

  const _BringoMark({this.size = 34});

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF1F5A59);
    const lime = Color(0xFFDDFB8A);

    final s = size.w;

    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        children: [
          Positioned(
            left: s * .23,
            top: s * .08,
            child: Container(
              width: s * .26,
              height: s * .72,
              decoration: BoxDecoration(
                color: teal,
                borderRadius: BorderRadius.circular(s * .17),
              ),
            ),
          ),
          Positioned(
            right: s * .08,
            bottom: s * .08,
            child: Container(
              width: s * .65,
              height: s * .65,
              decoration: const BoxDecoration(
                color: teal,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: s * .30,
            bottom: s * .19,
            child: Transform.rotate(
              angle: -.60,
              child: Container(
                width: s * .49,
                height: s * .29,
                decoration: BoxDecoration(
                  color: lime,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(s * .30),
                    bottomRight: Radius.circular(s * .30),
                    topRight: Radius.circular(s * .10),
                    bottomLeft: Radius.circular(s * .10),
                  ),
                  border: Border.all(
                    color: Colors.white,
                    width: s * .065,
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
