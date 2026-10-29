import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverOrderDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  const DriverOrderDetailsScreen({super.key, required this.order});

  @override
  State<DriverOrderDetailsScreen> createState() => _DriverOrderDetailsScreenState();
}

class _DriverOrderDetailsScreenState extends State<DriverOrderDetailsScreen> {
  static const teal = Color(0xFF1F5A59);
  static const darkTeal = Color(0xFF174746);
  static const lime = Color(0xFFDDFB8A);
  static const mint = Color(0xFFEAF3F2);
  static const background = Color(0xFFF7FAF8);
  static const textDark = Color(0xFF182322);
  static const textGrey = Color(0xFF77817F);
  static const border = Color(0xFFE3EAE8);

  bool loading = false;
  String get orderKey => widget.order['firebaseKey']?.toString() ?? widget.order['id']?.toString() ?? '';
  double _num(dynamic value) => double.tryParse(value?.toString() ?? '0') ?? 0;

  String _firstText(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != 'null') return text;
    }
    return '';
  }

  Map<String, dynamic> _map(dynamic value) => value is Map ? Map<String, dynamic>.from(value) : {};

  List<Map<String, dynamic>> parseItems(dynamic value) {
    if (value is List) return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (value is Map) return value.values.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    return [];
  }

  String buildAddress(Map<String, dynamic> order) {
    final direct = order['customerAddress'] ?? order['deliveryAddress'] ?? order['address'] ?? order['fullAddress'];
    if (direct is Map) {
      final a = Map<String, dynamic>.from(direct);
      final parts = <String>[
        if (_firstText([a['area'], a['city']]).isNotEmpty) _firstText([a['area'], a['city']]),
        if (_firstText([a['street']]).isNotEmpty) _firstText([a['street']]),
        if (_firstText([a['building']]).isNotEmpty) 'عمارة ${a['building']}',
        if (_firstText([a['floor']]).isNotEmpty) 'الدور ${a['floor']}',
        if (_firstText([a['apartment']]).isNotEmpty) 'شقة ${a['apartment']}',
        if (_firstText([a['landmark']]).isNotEmpty) _firstText([a['landmark']]),
        if (_firstText([a['notes']]).isNotEmpty) _firstText([a['notes']]),
      ];
      return parts.isEmpty ? 'لم يتم تحديد العنوان' : parts.join(' - ');
    }
    final text = direct?.toString().trim() ?? '';
    return text.isEmpty ? 'لم يتم تحديد العنوان' : text;
  }

  double? _coordinate(List<String> keys) {
    final sources = <Map<String, dynamic>>[
      widget.order,
      _map(widget.order['customerAddress']),
      _map(widget.order['deliveryAddress']),
      _map(widget.order['location']),
      _map(widget.order['customerLocation']),
    ];
    for (final source in sources) {
      for (final key in keys) {
        final value = double.tryParse(source[key]?.toString() ?? '');
        if (value != null && value != 0) return value;
      }
    }
    return null;
  }

  Future<void> openCustomerLocation() async {
    final lat = _coordinate(['customerLat', 'latitude', 'lat']);
    final lng = _coordinate(['customerLng', 'customerLon', 'longitude', 'lng', 'lon']);
    if (lat == null || lng == null) {
      _message('موقع العميل غير متاح لهذا الطلب');
      return;
    }
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) _message('تعذر فتح خرائط Google');
  }

  String cleanPhone(String phone) => phone.replaceAll(' ', '').replaceAll('-', '').trim();

  Future<void> callCustomer(String phone) async {
    final clean = cleanPhone(phone);
    if (clean.isNotEmpty) await launchUrl(Uri.parse('tel:$clean'));
  }

  Future<void> whatsappCustomer(String phone, String name) async {
    var clean = cleanPhone(phone);
    if (clean.isEmpty) return;
    if (clean.startsWith('0')) clean = '2$clean';
    final message = Uri.encodeComponent('مرحبًا $name، أنا طيار Bringo ومعي طلبك الآن.');
    await launchUrl(Uri.parse('https://wa.me/$clean?text=$message'), mode: LaunchMode.externalApplication);
  }

  Future<void> updateStatus(String status) async {
    if (orderKey.isEmpty || loading) return;
    try {
      setState(() => loading = true);
      final now = DateTime.now().millisecondsSinceEpoch;
      final updates = <String, dynamic>{'status': status, 'orderStatus': status, 'updatedAt': now};
      if (status == 'pickedUp') updates['pickedUpAt'] = now;
      if (status == 'onDelivery') updates['onDeliveryAt'] = now;
      if (status == 'completed') updates['completedAt'] = now;
      await FirebaseDatabase.instance.ref('orders/$orderKey').update(updates);
      if (!mounted) return;
      if (status == 'completed') {
        _message('تم تسليم الطلب بنجاح');
        await Future<void>.delayed(const Duration(milliseconds: 450));
        if (mounted) Navigator.pop(context, true);
        return;
      }
      setState(() {
        widget.order['status'] = status;
        widget.order['orderStatus'] = status;
        widget.order['updatedAt'] = now;
      });
      _message(status == 'pickedUp' ? 'تم استلام الطلب من المتجر' : 'بدأ التوصيل للعميل');
    } catch (_) {
      if (mounted) _message('حدث خطأ أثناء تحديث الطلب');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value, textAlign: TextAlign.right, style: GoogleFonts.cairo(fontWeight: FontWeight.w700)), backgroundColor: darkTeal, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final customerName = _firstText([order['customerName'], order['name']]);
    final phone = _firstText([order['customerPhone'], order['phone']]);
    final address = buildAddress(order);
    final subtotal = _num(order['productsTotal']) > 0 ? _num(order['productsTotal']) : _num(order['subtotal']);
    final deliveryFee = _num(order['deliveryFee']);
    final total = _num(order['total']);
    final savedBringo = _num(order['bringoDeliveryShare']);
    final savedDriver = _num(order['driverDeliveryShare']);
    final bringoShare = savedBringo > 0 ? savedBringo : double.parse((deliveryFee / 3).toStringAsFixed(2));
    final driverShare = savedDriver > 0 ? savedDriver : double.parse((deliveryFee - bringoShare).toStringAsFixed(2));
    final companyRemittance = double.parse((subtotal + bringoShare).toStringAsFixed(2));
    final status = _firstText([order['status'], order['orderStatus'], 'assigned']);
    final items = parseItems(order['items']);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: Column(children: [
            _topBar(context),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(18.w, 8.h, 18.w, 28.h),
                physics: const BouncingScrollPhysics(),
                children: [
                  _journeyHero(status),
                  SizedBox(height: 14.h),
                  _storeCard(order),
                  SizedBox(height: 14.h),
                  _sectionLabel('التوصيل للعميل'),
                  SizedBox(height: 9.h),
                  _customerCard(name: customerName.isEmpty ? 'عميل Bringo' : customerName, phone: phone, address: address),
                  SizedBox(height: 22.h),
                  _sectionLabel('تفاصيل الحساب'),
                  SizedBox(height: 9.h),
                  _paymentCard(subtotal: subtotal, deliveryFee: deliveryFee, total: total, driverShare: driverShare, bringoShare: bringoShare, companyRemittance: companyRemittance),
                  SizedBox(height: 22.h),
                  Row(children: [Text('${items.length} منتج', style: GoogleFonts.cairo(color: darkTeal, fontSize: 10.sp, fontWeight: FontWeight.w900)), const Spacer(), _sectionLabel('محتويات الطلب')]),
                  SizedBox(height: 9.h),
                  if (items.isEmpty) _emptyProducts() else ...items.map(_productItem),
                  SizedBox(height: 24.h),
                  _statusAction(status),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(18.w, 10.h, 18.w, 8.h),
        child: Row(children: [
          InkWell(onTap: () => Navigator.pop(context), child: Container(width: 43.w, height: 43.w, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: border)), child: Icon(Icons.arrow_back_ios_new_rounded, color: darkTeal, size: 17.sp))),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('تفاصيل المشوار', style: GoogleFonts.cairo(color: textDark, fontSize: 19.sp, fontWeight: FontWeight.w900)), Text(orderKey.isEmpty ? 'طلب Bringo' : '#${_shortOrderId(orderKey)}', style: GoogleFonts.cairo(color: textGrey, fontSize: 10.sp))]),
        ]),
      );

  String _shortOrderId(String value) => value.length <= 7 ? value : value.substring(value.length - 7).toUpperCase();

  Widget _journeyHero(String status) {
    final data = _statusData(status);
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(color: darkTeal, borderRadius: BorderRadius.circular(24.r)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(data.$1, style: GoogleFonts.cairo(color: lime, fontSize: 11.sp, fontWeight: FontWeight.w900)),
        Text(data.$2, style: GoogleFonts.cairo(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w900)),
        SizedBox(height: 4.h),
        Text(data.$3, style: GoogleFonts.cairo(color: Colors.white70, fontSize: 10.sp)),
      ]),
    );
  }

  (String, String, String) _statusData(String status) {
    switch (status.toLowerCase()) {
      case 'pickedup': return ('تم الاستلام', 'اتجه للعميل', 'الطلب معاك الآن، توجه لعنوان العميل');
      case 'ondelivery': return ('في الطريق', 'أنت في مرحلة التوصيل', 'وصل الطلب للعميل بأمان');
      case 'completed':
      case 'delivered': return ('تم التسليم', 'المشوار اكتمل', 'تم تسليم الطلب بنجاح');
      default: return ('مقبول', 'اتجه للمتجر', 'استلم الطلب من المتجر وابدأ المشوار');
    }
  }

  Widget _sectionLabel(String value) => Text(value, textAlign: TextAlign.right, style: GoogleFonts.cairo(color: textDark, fontSize: 15.sp, fontWeight: FontWeight.w900));

  Widget _storeCard(Map<String, dynamic> order) {
    final name = _firstText([order['storeName'], order['restaurantName'], order['pharmacyName'], order['merchantName'], order['shopName']]);
    return Container(
      padding: EdgeInsets.all(15.w),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(21.r), border: Border.all(color: border)),
      child: Row(children: [Icon(Icons.storefront_rounded, color: teal), const Spacer(), Text(name.isEmpty ? 'متجر Bringo' : name, style: GoogleFonts.cairo(color: textDark, fontSize: 14.sp, fontWeight: FontWeight.w900))]),
    );
  }

  Widget _customerCard({required String name, required String phone, required String address}) => Container(
        padding: EdgeInsets.all(15.w),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(21.r), border: Border.all(color: border)),
        child: Column(children: [
          Row(children: [
            IconButton(onPressed: phone.isEmpty ? null : () => whatsappCustomer(phone, name), icon: const Icon(Icons.chat_bubble_outline_rounded), color: const Color(0xFF1FAF61)),
            IconButton(onPressed: phone.isEmpty ? null : () => callCustomer(phone), icon: const Icon(Icons.call_outlined), color: teal),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(name, style: GoogleFonts.cairo(color: textDark, fontSize: 14.sp, fontWeight: FontWeight.w900)), if (phone.isNotEmpty) Text(phone, style: GoogleFonts.cairo(color: textGrey, fontSize: 10.sp))]),
          ]),
          SizedBox(height: 12.h),
          Container(width: double.infinity, padding: EdgeInsets.all(12.w), decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14.r)), child: Text(address, textAlign: TextAlign.right, style: GoogleFonts.cairo(color: textDark, fontSize: 11.sp, fontWeight: FontWeight.w700))),
          SizedBox(height: 10.h),
          SizedBox(
            width: double.infinity,
            height: 48.h,
            child: ElevatedButton.icon(
              onPressed: openCustomerLocation,
              icon: const Icon(Icons.map_outlined),
              label: Text('فتح الموقع على الخريطة', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
              style: ElevatedButton.styleFrom(elevation: 0, backgroundColor: mint, foregroundColor: darkTeal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r))),
            ),
          ),
        ]),
      );

  Widget _paymentCard({required double subtotal, required double deliveryFee, required double total, required double driverShare, required double bringoShare, required double companyRemittance}) => Container(
        padding: EdgeInsets.all(15.w),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(21.r), border: Border.all(color: border)),
        child: Column(children: [
          _priceRow('قيمة المنتجات', subtotal, emphasized: true),
          _priceRow('رسوم التوصيل', deliveryFee),
          const Divider(color: border),
          _priceRow('مستحقاتك', driverShare, highlighted: true),
          _priceRow('مستحقات Bringo', bringoShare),
          const Divider(color: border),
          _priceRow('المطلوب توريده للشركة', companyRemittance, emphasized: true),
          _priceRow('إجمالي تحصيل العميل', total),
        ]),
      );

  Widget _priceRow(String title, double value, {bool highlighted = false, bool emphasized = false}) => Padding(
        padding: EdgeInsets.symmetric(vertical: 6.h),
        child: Row(children: [
          Container(padding: highlighted ? EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h) : EdgeInsets.zero, decoration: highlighted ? BoxDecoration(color: lime, borderRadius: BorderRadius.circular(10.r)) : null, child: Text('${value.toStringAsFixed(2)} جنيه', style: GoogleFonts.cairo(color: darkTeal, fontSize: emphasized ? 13.sp : 11.5.sp, fontWeight: FontWeight.w900))),
          const Spacer(),
          Text(title, style: GoogleFonts.cairo(color: emphasized ? textDark : textGrey, fontSize: 11.sp, fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700)),
        ]),
      );

  Widget _productItem(Map<String, dynamic> item) {
    final name = item['name']?.toString() ?? item['productName']?.toString() ?? 'منتج';
    final qty = item['quantity']?.toString() ?? item['qty']?.toString() ?? '1';
    final price = _num(item['price']);
    final image = item['image']?.toString() ?? item['imageUrl']?.toString() ?? '';
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: border)),
      child: Row(children: [
        Text('${price.toStringAsFixed(0)} ج × $qty', style: GoogleFonts.cairo(color: darkTeal, fontWeight: FontWeight.w900)),
        const Spacer(),
        Expanded(child: Text(name, textAlign: TextAlign.right, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.cairo(color: textDark, fontWeight: FontWeight.w800))),
        if (image.isNotEmpty) ...[SizedBox(width: 8.w), _image(image)],
      ]),
    );
  }

  Widget _image(String image) {
    if (image.startsWith('http')) return ClipRRect(borderRadius: BorderRadius.circular(10.r), child: Image.network(image, width: 45.w, height: 45.w, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()));
    try {
      final source = image.startsWith('data:image') ? image.split(',').last : image;
      return ClipRRect(borderRadius: BorderRadius.circular(10.r), child: Image.memory(base64Decode(source), width: 45.w, height: 45.w, fit: BoxFit.cover));
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  Widget _emptyProducts() => Container(padding: EdgeInsets.all(20.w), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18.r), border: Border.all(color: border)), child: Center(child: Text('لا توجد منتجات مسجلة في الطلب', style: GoogleFonts.cairo(color: textGrey))));

  Widget _statusAction(String status) {
    final s = status.toLowerCase();
    if (s == 'completed' || s == 'delivered') return Container(padding: EdgeInsets.all(15.w), decoration: BoxDecoration(color: mint, borderRadius: BorderRadius.circular(18.r)), child: Center(child: Text('تم إنهاء هذا المشوار', style: GoogleFonts.cairo(color: darkTeal, fontWeight: FontWeight.w900))));
    String title;
    String nextStatus;
    IconData icon;
    if (s == 'pickedup') {
      title = 'بدء التوصيل للعميل'; nextStatus = 'onDelivery'; icon = Icons.delivery_dining_rounded;
    } else if (s == 'ondelivery') {
      title = 'تأكيد تسليم الطلب'; nextStatus = 'completed'; icon = Icons.check_circle_outline_rounded;
    } else {
      title = 'تم استلام الطلب من المتجر'; nextStatus = 'pickedUp'; icon = Icons.inventory_2_outlined;
    }
    return SizedBox(width: double.infinity, height: 54.h, child: ElevatedButton.icon(onPressed: loading ? null : () => updateStatus(nextStatus), icon: Icon(icon), label: Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.w900)), style: ElevatedButton.styleFrom(backgroundColor: teal, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)))));
  }
}
