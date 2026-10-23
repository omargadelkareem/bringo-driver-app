import 'package:bringo_driver/core/session/driver_session.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class DriverWalletScreen extends StatelessWidget {
  const DriverWalletScreen({super.key});

  static const String companyWalletNumber = '01115057318';
  static const double companyDeliveryShare = 10;

  static const Color teal = Color(0xFF1F5A59);
  static const Color darkTeal = Color(0xFF174746);
  static const Color lime = Color(0xFFDDFB8A);
  static const Color mint = Color(0xFFEAF3F2);
  static const Color background = Color(0xFFF7FAF8);
  static const Color textDark = Color(0xFF182322);
  static const Color textGrey = Color(0xFF77817F);
  static const Color border = Color(0xFFE3EAE8);

  List<Map<String, dynamic>> _parseOrders(dynamic value) {
    if (value == null || value is! Map) return [];

    final data = Map<dynamic, dynamic>.from(value);
    final list = <Map<String, dynamic>>[];

    data.forEach((key, value) {
      if (value is! Map) return;
      final item = Map<String, dynamic>.from(value);
      item['firebaseKey'] = key.toString();
      list.add(item);
    });

    list.sort((a, b) {
      final aTime = int.tryParse(
            (a['completedAt'] ?? a['updatedAt'] ?? 0).toString(),
          ) ??
          0;
      final bTime = int.tryParse(
            (b['completedAt'] ?? b['updatedAt'] ?? 0).toString(),
          ) ??
          0;
      return bTime.compareTo(aTime);
    });

    return list;
  }

  double _num(dynamic value) =>
      double.tryParse(value?.toString() ?? '0') ?? 0;

  String _status(Map<String, dynamic> order) {
    return (order['status'] ?? order['orderStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
  }

  bool _isCompleted(Map<String, dynamic> order) {
    final status = _status(order);
    return status == 'completed' ||
        status == 'delivered' ||
        status == 'done';
  }

  double _driverEarning(Map<String, dynamic> order) {
    final savedDriverEarning = _num(order['driverEarning']);
    if (savedDriverEarning > 0) return savedDriverEarning;

    final savedDriverFee = _num(order['driverFee']);
    if (savedDriverFee > 0) return savedDriverFee;

    final deliveryFee = _num(order['deliveryFee']);
    if (deliveryFee > 0) {
      final earning = deliveryFee - companyDeliveryShare;
      return earning > 0 ? earning : 0;
    }

    return 0;
  }

  double _cashCollected(Map<String, dynamic> order) {
    final savedCash = _num(order['cashCollected']);
    if (savedCash > 0) return savedCash;

    final total = _num(order['total']);
    final deliveryFee = _num(order['deliveryFee']);

    if (deliveryFee > 0 && order['totalIncludesDelivery'] != true) {
      return total + deliveryFee;
    }

    return total;
  }

  double _dueToCompany(Map<String, dynamic> order) {
    final savedDue = _num(order['amountDueToCompany']);
    if (savedDue > 0) return savedDue;

    final due = _cashCollected(order) - _driverEarning(order);
    return due > 0 ? due : 0;
  }

  @override
  Widget build(BuildContext context) {
    final driverId = DriverSession.driverId ?? '';

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
                return const _WalletShimmer();
              }

              if (snapshot.hasError) {
                return _errorState();
              }

              final orders = _parseOrders(snapshot.data?.snapshot.value);

              final completedOrders = orders.where((order) {
                final dId = order['driverId']?.toString() ?? '';
                final dKey = order['driverKey']?.toString() ?? '';
                return (dId == driverId || dKey == driverId) &&
                    _isCompleted(order);
              }).toList();

              double totalCollected = 0;
              double totalDriverEarnings = 0;
              double totalDueToCompany = 0;

              for (final order in completedOrders) {
                totalCollected += _cashCollected(order);
                totalDriverEarnings += _driverEarning(order);
                totalDueToCompany += _dueToCompany(order);
              }

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
                    _header(),
                    SizedBox(height: 20.h),

                    _balanceHero(
                      earnings: totalDriverEarnings,
                      due: totalDueToCompany,
                    ),
                    SizedBox(height: 13.h),

                    _simpleSummary(
                      collected: totalCollected,
                      completedCount: completedOrders.length,
                    ),

                    SizedBox(height: 24.h),
                    _sectionTitle(
                      'التوريد للشركة',
                      'المبلغ اللي معاك وخصمنا منه أرباحك تلقائيًا',
                    ),
                    SizedBox(height: 10.h),

                    _transferCard(
                      context,
                      totalDueToCompany,
                    ),

                    SizedBox(height: 26.h),

                    Row(
                      children: [
                        if (completedOrders.isNotEmpty)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 9.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: mint,
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Text(
                              '${completedOrders.length} طلب',
                              style: GoogleFonts.cairo(
                                color: darkTeal,
                                fontSize: 9.5.sp,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        const Spacer(),
                        _sectionTitle(
                          'آخر المشاوير',
                          'تفاصيل بسيطة لكل طلب تم تسليمه',
                        ),
                      ],
                    ),

                    SizedBox(height: 11.h),

                    if (completedOrders.isEmpty)
                      _emptyBox()
                    else
                      ...completedOrders.map(
                        (order) => _OrderWalletCard(
                          order: order,
                          cashCollected: _cashCollected(order),
                          driverEarning: _driverEarning(order),
                          dueToCompany: _dueToCompany(order),
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

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 42.w,
          height: 42.w,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: border),
          ),
          child: Icon(
            Icons.help_outline_rounded,
            color: darkTeal,
            size: 20.sp,
          ),
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'محفظتي',
              style: GoogleFonts.cairo(
                color: textDark,
                fontSize: 23.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              'أرباحك وتوريداتك بشكل بسيط',
              style: GoogleFonts.cairo(
                color: textGrey,
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(width: 10.w),
        const _WalletMark(),
      ],
    );
  }

  Widget _balanceHero({
    required double earnings,
    required double due,
  }) {
    return Container(
      padding: EdgeInsets.all(19.w),
      decoration: BoxDecoration(
        color: darkTeal,
        borderRadius: BorderRadius.circular(25.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Container(
                width: 43.w,
                height: 43.w,
                decoration: BoxDecoration(
                  color: lime,
                  borderRadius: BorderRadius.circular(13.r),
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: darkTeal,
                  size: 22.sp,
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'أرباحك من التوصيل',
                    style: GoogleFonts.cairo(
                      color: Colors.white.withOpacity(.68),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    '${earnings.toStringAsFixed(0)} جنيه',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 29.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 18.h),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 13.w,
              vertical: 11.h,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.08),
              borderRadius: BorderRadius.circular(15.r),
            ),
            child: Row(
              children: [
                Text(
                  '${due.toStringAsFixed(0)} ج',
                  style: GoogleFonts.cairo(
                    color: lime,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Text(
                  due <= 0
                      ? 'مفيش مبلغ مطلوب توريده'
                      : 'مطلوب توريده للشركة',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _simpleSummary({
    required double collected,
    required int completedCount,
  }) {
    return Row(
      children: [
        Expanded(
          child: _summaryItem(
            icon: Icons.payments_outlined,
            title: 'استلمت من العملاء',
            value: '${collected.toStringAsFixed(0)} ج',
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: _summaryItem(
            icon: Icons.check_circle_outline_rounded,
            title: 'طلبات سلمتها',
            value: '$completedCount',
          ),
        ),
      ],
    );
  }

  Widget _summaryItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      height: 92.h,
      padding: EdgeInsets.all(13.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19.r),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Icon(icon, color: teal, size: 19.sp),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.cairo(
              color: darkTeal,
              fontSize: 16.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            title,
            maxLines: 1,
            style: GoogleFonts.cairo(
              color: textGrey,
              fontSize: 9.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          title,
          textAlign: TextAlign.right,
          style: GoogleFonts.cairo(
            color: textDark,
            fontSize: 16.sp,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          subtitle,
          textAlign: TextAlign.right,
          style: GoogleFonts.cairo(
            color: textGrey,
            fontSize: 9.5.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _transferCard(
    BuildContext context,
    double due,
  ) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21.r),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 10.w,
                  vertical: 5.h,
                ),
                decoration: BoxDecoration(
                  color: due > 0 ? lime : mint,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  due > 0
                      ? '${due.toStringAsFixed(0)} ج'
                      : 'لا يوجد مستحق',
                  style: GoogleFonts.cairo(
                    color: darkTeal,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                due > 0 ? 'حوّل المبلغ للشركة' : 'حسابك متوازن',
                style: GoogleFonts.cairo(
                  color: textDark,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(width: 8.w),
              Icon(
                due > 0
                    ? Icons.account_balance_outlined
                    : Icons.verified_rounded,
                color: teal,
                size: 20.sp,
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            due > 0
                ? 'ده صافي المبلغ المطلوب بعد خصم أرباحك من التوصيل.'
                : 'لا يوجد مبلغ مطلوب منك توريده حاليًا.',
            textAlign: TextAlign.right,
            style: GoogleFonts.cairo(
              color: textGrey,
              fontSize: 10.5.sp,
              height: 1.55,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (due > 0) ...[
            SizedBox(height: 14.h),
            InkWell(
              onTap: () {
                Clipboard.setData(
                  const ClipboardData(text: companyWalletNumber),
                );
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(
                        'تم نسخ رقم المحفظة',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      backgroundColor: darkTeal,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
              },
              borderRadius: BorderRadius.circular(14.r),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 13.w,
                  vertical: 12.h,
                ),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 35.w,
                      height: 35.w,
                      decoration: const BoxDecoration(
                        color: mint,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.copy_rounded,
                        color: teal,
                        size: 17.sp,
                      ),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          companyWalletNumber,
                          textDirection: TextDirection.ltr,
                          style: GoogleFonts.cairo(
                            color: darkTeal,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'اضغط لنسخ رقم التحويل',
                          style: GoogleFonts.cairo(
                            color: textGrey,
                            fontSize: 8.5.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptyBox() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: 29.h,
        horizontal: 20.w,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21.r),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Container(
            width: 53.w,
            height: 53.w,
            decoration: const BoxDecoration(
              color: mint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              color: teal,
              size: 25.sp,
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            'لسه مفيش مشاوير مكتملة',
            style: GoogleFonts.cairo(
              color: textDark,
              fontSize: 13.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            'بعد أول طلب تسلمه هتظهر تفاصيله هنا',
            style: GoogleFonts.cairo(
              color: textGrey,
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              color: textGrey,
              size: 46.sp,
            ),
            SizedBox(height: 12.h),
            Text(
              'تعذر تحميل المحفظة',
              style: GoogleFonts.cairo(
                color: textDark,
                fontSize: 15.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'تحقق من الإنترنت وحاول مرة أخرى',
              style: GoogleFonts.cairo(
                color: textGrey,
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderWalletCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final double cashCollected;
  final double driverEarning;
  final double dueToCompany;

  const _OrderWalletCard({
    required this.order,
    required this.cashCollected,
    required this.driverEarning,
    required this.dueToCompany,
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

  @override
  Widget build(BuildContext context) {
    final id = (order['id'] ?? order['firebaseKey'] ?? '').toString();
    final storeName = _firstText([
      order['storeName'],
      order['restaurantName'],
      order['pharmacyName'],
      order['merchantName'],
      order['shopName'],
    ]);
    final customer =
        order['customerName']?.toString() ?? 'عميل Bringo';
    final completedAt =
        int.tryParse(order['completedAt']?.toString() ?? '0') ?? 0;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19.r),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                completedAt == 0 ? '' : _formatDate(completedAt),
                style: GoogleFonts.cairo(
                  color: textGrey,
                  fontSize: 8.5.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      storeName.isEmpty ? customer : storeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        color: textDark,
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
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
              SizedBox(width: 9.w),
              Container(
                width: 39.w,
                height: 39.w,
                decoration: const BoxDecoration(
                  color: mint,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: teal,
                  size: 19.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 11.w,
              vertical: 10.h,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAF9),
              borderRadius: BorderRadius.circular(13.r),
            ),
            child: Row(
              children: [
                _amount(
                  title: 'ورد للشركة',
                  value: dueToCompany,
                ),
                _divider(),
                _amount(
                  title: 'ربحك',
                  value: driverEarning,
                  highlighted: true,
                ),
                _divider(),
                _amount(
                  title: 'استلمت',
                  value: cashCollected,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _shortId(String value) {
    if (value.isEmpty) return '-';
    if (value.length <= 6) return value.toUpperCase();
    return value.substring(value.length - 6).toUpperCase();
  }

  Widget _amount({
    required String title,
    required double value,
    bool highlighted = false,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '${value.toStringAsFixed(0)} ج',
            maxLines: 1,
            style: GoogleFonts.cairo(
              color: highlighted ? darkTeal : textDark,
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 1.h),
          Container(
            padding: highlighted
                ? EdgeInsets.symmetric(
                    horizontal: 6.w,
                    vertical: 1.h,
                  )
                : EdgeInsets.zero,
            decoration: highlighted
                ? BoxDecoration(
                    color: lime,
                    borderRadius: BorderRadius.circular(7.r),
                  )
                : null,
            child: Text(
              title,
              maxLines: 1,
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

  Widget _divider() {
    return Container(
      width: 1,
      height: 30.h,
      color: border,
    );
  }

  String _formatDate(int millis) {
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final period = date.hour >= 12 ? 'م' : 'ص';

    return '${date.day}/${date.month}  $hour:${date.minute.toString().padLeft(2, '0')} $period';
  }
}

class _WalletMark extends StatelessWidget {
  const _WalletMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42.w,
      height: 42.w,
      decoration: BoxDecoration(
        color: const Color(0xFF174746),
        borderRadius: BorderRadius.circular(13.r),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_rounded,
            color: Colors.white,
            size: 22.sp,
          ),
          Positioned(
            top: 8.h,
            right: 8.w,
            child: Container(
              width: 8.w,
              height: 8.w,
              decoration: const BoxDecoration(
                color: Color(0xFFDDFB8A),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletShimmer extends StatefulWidget {
  const _WalletShimmer();

  @override
  State<_WalletShimmer> createState() => _WalletShimmerState();
}

class _WalletShimmerState extends State<_WalletShimmer>
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

  Widget bone(
    double width,
    double height, {
    double radius = 14,
  }) {
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
      builder: (context, _) {
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
            padding: EdgeInsets.fromLTRB(
              18.w,
              18.h,
              18.w,
              120.h,
            ),
            physics: const NeverScrollableScrollPhysics(),
            children: [
              Row(
                children: [
                  bone(42.w, 42.w, radius: 21.r),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      bone(100.w, 19.h),
                      SizedBox(height: 7.h),
                      bone(145.w, 9.h),
                    ],
                  ),
                  SizedBox(width: 10.w),
                  bone(42.w, 42.w, radius: 13.r),
                ],
              ),
              SizedBox(height: 20.h),
              bone(double.infinity, 170.h, radius: 25.r),
              SizedBox(height: 13.h),
              Row(
                children: [
                  Expanded(
                    child: bone(
                      double.infinity,
                      92.h,
                      radius: 19.r,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: bone(
                      double.infinity,
                      92.h,
                      radius: 19.r,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 26.h),
              bone(130.w, 16.h),
              SizedBox(height: 10.h),
              bone(double.infinity, 170.h, radius: 21.r),
              SizedBox(height: 26.h),
              bone(120.w, 16.h),
              SizedBox(height: 11.h),
              bone(double.infinity, 115.h, radius: 19.r),
            ],
          ),
        );
      },
    );
  }
}
