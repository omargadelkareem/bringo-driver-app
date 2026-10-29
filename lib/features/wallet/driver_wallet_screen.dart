import 'package:bringo_driver/core/session/driver_session.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class DriverWalletScreen extends StatelessWidget {
  const DriverWalletScreen({super.key});

  static const String companyWalletNumber = '01115057318';
  static const Color teal = Color(0xFF1F5A59);
  static const Color darkTeal = Color(0xFF174746);
  static const Color lime = Color(0xFFDDFB8A);
  static const Color mint = Color(0xFFEAF3F2);
  static const Color background = Color(0xFFF7FAF8);
  static const Color textDark = Color(0xFF182322);
  static const Color textGrey = Color(0xFF77817F);
  static const Color border = Color(0xFFE3EAE8);

  double _num(dynamic value) => double.tryParse(value?.toString() ?? '0') ?? 0;

  List<Map<String, dynamic>> _parseOrders(dynamic value) {
    if (value is! Map) return [];
    final list = <Map<String, dynamic>>[];
    Map<dynamic, dynamic>.from(value).forEach((key, value) {
      if (value is Map) {
        final order = Map<String, dynamic>.from(value);
        order['firebaseKey'] = key.toString();
        list.add(order);
      }
    });
    list.sort((a, b) {
      final aTime = int.tryParse((a['completedAt'] ?? a['updatedAt'] ?? 0).toString()) ?? 0;
      final bTime = int.tryParse((b['completedAt'] ?? b['updatedAt'] ?? 0).toString()) ?? 0;
      return bTime.compareTo(aTime);
    });
    return list;
  }

  bool _isCompleted(Map<String, dynamic> order) {
    final status = (order['status'] ?? order['orderStatus'] ?? '').toString().toLowerCase();
    return status == 'completed' || status == 'delivered' || status == 'done';
  }

  double _deliveryFee(Map<String, dynamic> order) => _num(order['deliveryFee']);

  double _bringoShare(Map<String, dynamic> order) {
    final saved = _num(order['bringoDeliveryShare']);
    if (saved > 0) return saved;
    final fee = _deliveryFee(order);
    return double.parse((fee / 3).toStringAsFixed(2));
  }

  double _driverShare(Map<String, dynamic> order) {
    final saved = _num(order['driverDeliveryShare']);
    if (saved > 0) return saved;
    final legacy = _num(order['driverEarning']);
    if (legacy > 0) return legacy;
    final fee = _deliveryFee(order);
    return double.parse((fee - _bringoShare(order)).toStringAsFixed(2));
  }

  double _productsValue(Map<String, dynamic> order) {
    final productsTotal = _num(order['productsTotal']);
    if (productsTotal > 0) return productsTotal;
    final subtotal = _num(order['subtotal']);
    if (subtotal > 0) return subtotal;
    final total = _num(order['total']);
    final fee = _deliveryFee(order);
    if (order['totalIncludesDelivery'] == true && total >= fee) return total - fee;
    return total;
  }

  double _cashCollected(Map<String, dynamic> order) {
    final saved = _num(order['cashCollected']);
    if (saved > 0) return saved;
    return _productsValue(order) + _deliveryFee(order);
  }

  double _dueToCompany(Map<String, dynamic> order) {
    return double.parse((_productsValue(order) + _bringoShare(order)).toStringAsFixed(2));
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
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: teal));
              }
              if (snapshot.hasError) return _errorState();

              final completedOrders = _parseOrders(snapshot.data?.snapshot.value).where((order) {
                final dId = order['driverId']?.toString() ?? '';
                final dKey = order['driverKey']?.toString() ?? '';
                return (dId == driverId || dKey == driverId) && _isCompleted(order);
              }).toList();

              double products = 0;
              double driverEarnings = 0;
              double bringoEarnings = 0;
              double due = 0;
              for (final order in completedOrders) {
                products += _productsValue(order);
                driverEarnings += _driverShare(order);
                bringoEarnings += _bringoShare(order);
                due += _dueToCompany(order);
              }

              return RefreshIndicator(
                color: teal,
                onRefresh: () async => FirebaseDatabase.instance.ref('orders').get(),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(18.w, 14.h, 18.w, 120.h),
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  children: [
                    _header(),
                    SizedBox(height: 20.h),
                    _balanceHero(earnings: driverEarnings, due: due),
                    SizedBox(height: 13.h),
                    Row(
                      children: [
                        Expanded(child: _summaryItem('مستحقات Bringo', bringoEarnings, Icons.business_center_outlined)),
                        SizedBox(width: 10.w),
                        Expanded(child: _summaryItem('قيمة المنتجات', products, Icons.shopping_bag_outlined)),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    _summaryItem('إجمالي المطلوب توريده للشركة', due, Icons.account_balance_outlined, wide: true),
                    SizedBox(height: 24.h),
                    _sectionTitle('التوريد للشركة', 'قيمة المنتجات + مستحقات Bringo فقط'),
                    SizedBox(height: 10.h),
                    _transferCard(context, due),
                    SizedBox(height: 26.h),
                    _sectionTitle('آخر المشاوير', 'تفاصيل الحساب لكل طلب تم تسليمه'),
                    SizedBox(height: 11.h),
                    if (completedOrders.isEmpty)
                      _emptyBox()
                    else
                      ...completedOrders.map((order) => _OrderWalletCard(
                            order: order,
                            productsValue: _productsValue(order),
                            deliveryFee: _deliveryFee(order),
                            driverShare: _driverShare(order),
                            bringoShare: _bringoShare(order),
                            dueToCompany: _dueToCompany(order),
                            cashCollected: _cashCollected(order),
                          )),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _header() => Row(children: [
        const Spacer(),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('محفظتي', style: GoogleFonts.cairo(color: textDark, fontSize: 23.sp, fontWeight: FontWeight.w900)),
          Text('أرباحك وتوريداتك بشكل واضح', style: GoogleFonts.cairo(color: textGrey, fontSize: 10.5.sp, fontWeight: FontWeight.w600)),
        ]),
        SizedBox(width: 10.w),
        Container(width: 42.w, height: 42.w, decoration: BoxDecoration(color: darkTeal, borderRadius: BorderRadius.circular(13.r)), child: Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 22.sp)),
      ]);

  Widget _balanceHero({required double earnings, required double due}) => Container(
        padding: EdgeInsets.all(19.w),
        decoration: BoxDecoration(color: darkTeal, borderRadius: BorderRadius.circular(25.r)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('أرباحك من التوصيل', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 11.sp, fontWeight: FontWeight.w700)),
          Text('${earnings.toStringAsFixed(2)} جنيه', style: GoogleFonts.cairo(color: Colors.white, fontSize: 29.sp, fontWeight: FontWeight.w900)),
          SizedBox(height: 18.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 11.h),
            decoration: BoxDecoration(color: Colors.white.withOpacity(.08), borderRadius: BorderRadius.circular(15.r)),
            child: Row(children: [
              Text('${due.toStringAsFixed(2)} ج', style: GoogleFonts.cairo(color: lime, fontSize: 14.sp, fontWeight: FontWeight.w900)),
              const Spacer(),
              Text(due <= 0 ? 'مفيش مبلغ مطلوب توريده' : 'مطلوب توريده للشركة', style: GoogleFonts.cairo(color: Colors.white, fontSize: 10.5.sp, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      );

  Widget _summaryItem(String title, double value, IconData icon, {bool wide = false}) => Container(
        height: wide ? 82.h : 92.h,
        padding: EdgeInsets.all(13.w),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(19.r), border: Border.all(color: border)),
        child: Row(children: [
          Icon(icon, color: teal, size: 20.sp),
          const Spacer(),
          Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${value.toStringAsFixed(2)} ج', style: GoogleFonts.cairo(color: darkTeal, fontSize: 16.sp, fontWeight: FontWeight.w900)),
            Text(title, style: GoogleFonts.cairo(color: textGrey, fontSize: 9.sp, fontWeight: FontWeight.w700)),
          ]),
        ]),
      );

  Widget _sectionTitle(String title, String subtitle) => Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(title, style: GoogleFonts.cairo(color: textDark, fontSize: 16.sp, fontWeight: FontWeight.w900)),
        Text(subtitle, style: GoogleFonts.cairo(color: textGrey, fontSize: 9.5.sp, fontWeight: FontWeight.w600)),
      ]);

  Widget _transferCard(BuildContext context, double due) => Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(21.r), border: Border.all(color: border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(due > 0 ? 'حوّل ${due.toStringAsFixed(2)} جنيه للشركة' : 'حسابك متوازن', style: GoogleFonts.cairo(color: textDark, fontSize: 13.sp, fontWeight: FontWeight.w900)),
          SizedBox(height: 5.h),
          Text(due > 0 ? 'المبلغ ده عبارة عن قيمة المنتجات + مستحقات Bringo.' : 'لا يوجد مبلغ مطلوب منك توريده حاليًا.', style: GoogleFonts.cairo(color: textGrey, fontSize: 10.sp, fontWeight: FontWeight.w600)),
          if (due > 0) ...[
            SizedBox(height: 14.h),
            InkWell(
              onTap: () {
                Clipboard.setData(const ClipboardData(text: companyWalletNumber));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ رقم المحفظة')));
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14.r)),
                child: Row(children: [
                  Icon(Icons.copy_rounded, color: teal, size: 18.sp),
                  const Spacer(),
                  Text(companyWalletNumber, textDirection: TextDirection.ltr, style: GoogleFonts.cairo(color: darkTeal, fontSize: 16.sp, fontWeight: FontWeight.w900)),
                ]),
              ),
            ),
          ],
        ]),
      );

  Widget _emptyBox() => Container(
        padding: EdgeInsets.symmetric(vertical: 30.h),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(21.r), border: Border.all(color: border)),
        child: Center(child: Text('لسه مفيش مشاوير مكتملة', style: GoogleFonts.cairo(color: textGrey, fontWeight: FontWeight.w700))),
      );

  Widget _errorState() => Center(child: Text('تعذر تحميل المحفظة', style: GoogleFonts.cairo(color: textDark, fontWeight: FontWeight.w900)));
}

class _OrderWalletCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final double productsValue;
  final double deliveryFee;
  final double driverShare;
  final double bringoShare;
  final double dueToCompany;
  final double cashCollected;

  const _OrderWalletCard({
    required this.order,
    required this.productsValue,
    required this.deliveryFee,
    required this.driverShare,
    required this.bringoShare,
    required this.dueToCompany,
    required this.cashCollected,
  });

  static const darkTeal = Color(0xFF174746);
  static const lime = Color(0xFFDDFB8A);
  static const textDark = Color(0xFF182322);
  static const textGrey = Color(0xFF77817F);
  static const border = Color(0xFFE3EAE8);

  @override
  Widget build(BuildContext context) {
    final id = (order['id'] ?? order['firebaseKey'] ?? '').toString();
    final store = (order['storeName'] ?? order['restaurantName'] ?? order['pharmacyName'] ?? order['shopName'] ?? 'طلب Bringo').toString();
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(19.r), border: Border.all(color: border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Row(children: [
          Text('#${_shortId(id)}', style: GoogleFonts.cairo(color: textGrey, fontSize: 9.sp, fontWeight: FontWeight.w600)),
          const Spacer(),
          Expanded(child: Text(store, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.cairo(color: textDark, fontSize: 12.5.sp, fontWeight: FontWeight.w900))),
        ]),
        SizedBox(height: 12.h),
        _row('قيمة المنتجات', productsValue, emphasized: true),
        _row('رسوم التوصيل', deliveryFee),
        _row('مستحقاتك', driverShare, highlighted: true),
        _row('مستحقات Bringo', bringoShare),
        Divider(height: 20.h, color: border),
        _row('المطلوب توريده للشركة', dueToCompany, emphasized: true),
        SizedBox(height: 5.h),
        _row('إجمالي ما تم تحصيله', cashCollected),
      ]),
    );
  }

  Widget _row(String title, double value, {bool highlighted = false, bool emphasized = false}) => Padding(
        padding: EdgeInsets.symmetric(vertical: 4.h),
        child: Row(children: [
          Container(
            padding: highlighted ? EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h) : EdgeInsets.zero,
            decoration: highlighted ? BoxDecoration(color: lime, borderRadius: BorderRadius.circular(8.r)) : null,
            child: Text('${value.toStringAsFixed(2)} ج', style: GoogleFonts.cairo(color: darkTeal, fontSize: emphasized ? 12.sp : 10.5.sp, fontWeight: FontWeight.w900)),
          ),
          const Spacer(),
          Text(title, style: GoogleFonts.cairo(color: emphasized ? textDark : textGrey, fontSize: emphasized ? 11.sp : 10.sp, fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700)),
        ]),
      );

  String _shortId(String value) => value.length <= 6 ? value.toUpperCase() : value.substring(value.length - 6).toUpperCase();
}
