import 'dart:convert';

import 'package:bringo_driver/core/routes/app_routes.dart';
import 'package:bringo_driver/core/session/driver_session.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverAccountScreen extends StatefulWidget {
  const DriverAccountScreen({super.key});

  @override
  State<DriverAccountScreen> createState() => _DriverAccountScreenState();
}

class _DriverAccountScreenState extends State<DriverAccountScreen> {
  static const teal = Color(0xFF1F5A59);
  static const darkTeal = Color(0xFF174746);
  static const lime = Color(0xFFDDFB8A);
  static const mint = Color(0xFFEAF3F2);
  static const background = Color(0xFFF7FAF8);
  static const textDark = Color(0xFF182322);
  static const textGrey = Color(0xFF77817F);
  static const border = Color(0xFFE3EAE8);
  static const danger = Color(0xFFD94C55);

  final String driverId = DriverSession.driverId ?? '';
  final ImagePicker picker = ImagePicker();
  bool loading = false;

  Future<void> pickAndUpdateProfileImage() async {
    if (driverId.isEmpty || loading) return;

    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 45,
    );
    if (picked == null) return;

    try {
      setState(() => loading = true);
      final bytes = await picked.readAsBytes();
      final base64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      await FirebaseDatabase.instance.ref('drivers/$driverId').update({
        'personalImage': base64,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      _msg('تم تحديث الصورة الشخصية');
    } catch (_) {
      _msg('حدث خطأ أثناء تحديث الصورة');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> toggleAvailability(bool value) async {
    if (driverId.isEmpty) return;
    try {
      await FirebaseDatabase.instance.ref('drivers/$driverId').update({
        'isAvailable': value,
        'lastSeenAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {
      _msg('تعذر تحديث حالة العمل');
    }
  }

  Future<void> callSupport() async {
    await launchUrl(
      Uri.parse('tel:01115057318'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> whatsappSupport() async {
    final message = Uri.encodeComponent(
      'مرحبًا، أنا طيار في Bringo وأحتاج دعم فني.',
    );
    await launchUrl(
      Uri.parse('https://wa.me/201115057318?text=$message'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> logout() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _LogoutSheet(),
    );

    if (confirmed != true) return;

    await toggleAvailability(false);
    await DriverSession.logout();
    if (!mounted) return;
    context.go(AppRoutes.login);
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

  String _text(dynamic value, [String fallback = '-']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == 'null' ? fallback : text;
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
              style: GoogleFonts.cairo(
                color: textDark,
                fontWeight: FontWeight.w800,
              ),
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
          child: StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance.ref('drivers/$driverId').onValue,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const _AccountShimmer();
              }

              if (snapshot.hasError) {
                return _errorState();
              }

              final data = snapshot.data?.snapshot.value;
              if (data == null || data is! Map) {
                return _errorState(
                  title: 'بيانات الحساب غير متاحة',
                  subtitle: 'سجل الدخول مرة أخرى أو تواصل مع الدعم',
                );
              }

              final driver = Map<String, dynamic>.from(data);

              return RefreshIndicator(
                color: teal,
                onRefresh: () async {
                  await FirebaseDatabase.instance
                      .ref('drivers/$driverId')
                      .get();
                },
                child: ListView(
                  padding: EdgeInsets.fromLTRB(18.w, 14.h, 18.w, 120.h),
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  children: [
                    _header(),
                    SizedBox(height: 18.h),
                    _profileHero(driver),
                    SizedBox(height: 12.h),
                    _availabilityCard(driver),
                    SizedBox(height: 24.h),
                    _sectionTitle('حسابي'),
                    SizedBox(height: 9.h),
                    _accountMenu(driver),
                    SizedBox(height: 24.h),
                    _sectionTitle('المساعدة'),
                    SizedBox(height: 9.h),
                    _supportMenu(),
                    SizedBox(height: 18.h),
                    _logoutTile(),
                    SizedBox(height: 14.h),
                    Center(
                      child: Text(
                        'Bringo Driver',
                        style: GoogleFonts.cairo(
                          color: textGrey.withOpacity(.65),
                          fontSize: 9.5.sp,
                          fontWeight: FontWeight.w600,
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

  Widget _header() {
    return Row(
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
            Icons.notifications_none_rounded,
            color: darkTeal,
            size: 20.sp,
          ),
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'حسابي',
              style: GoogleFonts.cairo(
                color: textDark,
                fontSize: 23.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'إدارة حسابك وحالة عملك',
              style: GoogleFonts.cairo(
                color: textGrey,
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(width: 10.w),
        const _BringoMark(size: 39),
      ],
    );
  }

  Widget _profileHero(Map<String, dynamic> driver) {
    final image = _text(driver['personalImage'], '');
    final name = _text(driver['name'], 'طيار Bringo');
    final phone = _text(driver['phone'], '');
    final completed = driver['profileCompleted'] == true;
    final active = driver['isActive'] != false;
    final rating = _text(driver['rating'], '5.0');
    final totalOrders = _text(driver['totalOrders'], '0');

    return Container(
      padding: EdgeInsets.all(17.w),
      decoration: BoxDecoration(
        color: darkTeal,
        borderRadius: BorderRadius.circular(25.r),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _heroStat(
                    Icons.star_rounded,
                    rating,
                    'التقييم',
                  ),
                  SizedBox(height: 9.h),
                  _heroStat(
                    Icons.delivery_dining_rounded,
                    totalOrders,
                    'طلب',
                  ),
                ],
              ),
              const Spacer(),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (phone.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        phone,
                        textDirection: TextDirection.ltr,
                        style: GoogleFonts.cairo(
                          color: Colors.white.withOpacity(.65),
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    SizedBox(height: 9.h),
                    Wrap(
                      spacing: 6.w,
                      runSpacing: 6.h,
                      alignment: WrapAlignment.end,
                      children: [
                        _badge(
                          active ? 'الحساب نشط' : 'الحساب موقوف',
                          active ? lime : Colors.white.withOpacity(.15),
                          active ? darkTeal : Colors.white,
                        ),
                        _badge(
                          completed ? 'البيانات مكتملة' : 'أكمل بياناتك',
                          Colors.white.withOpacity(.09),
                          Colors.white,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 13.w),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 78.w,
                    height: 78.w,
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: lime,
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: _ProfileImage(image: image),
                    ),
                  ),
                  Positioned(
                    left: -2.w,
                    bottom: -2.h,
                    child: InkWell(
                      onTap: loading ? null : pickAndUpdateProfileImage,
                      borderRadius: BorderRadius.circular(30.r),
                      child: Container(
                        width: 29.w,
                        height: 29.w,
                        decoration: BoxDecoration(
                          color: lime,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: darkTeal,
                            width: 2,
                          ),
                        ),
                        child: loading
                            ? Padding(
                                padding: EdgeInsets.all(7.w),
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: darkTeal,
                                ),
                              )
                            : Icon(
                                Icons.camera_alt_outlined,
                                color: darkTeal,
                                size: 14.sp,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(
    IconData icon,
    String value,
    String label,
  ) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 12.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.cairo(
                color: Colors.white.withOpacity(.52),
                fontSize: 8.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(width: 6.w),
        Icon(icon, color: lime, size: 16.sp),
      ],
    );
  }

  Widget _badge(String text, Color bg, Color fg) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8.w,
        vertical: 4.h,
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
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _availabilityCard(Map<String, dynamic> driver) {
    final available = driver['isAvailable'] == true;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 15.w,
        vertical: 13.h,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Transform.scale(
            scale: .85,
            child: Switch(
              value: available,
              activeColor: darkTeal,
              activeTrackColor: lime,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFD6DEDC),
              onChanged: toggleAvailability,
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                available ? 'أنت متاح للعمل' : 'أنت غير متاح الآن',
                style: GoogleFonts.cairo(
                  color: textDark,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                available
                    ? 'هتظهر لك الطلبات الجديدة'
                    : 'مش هيوصلك طلب جديد',
                style: GoogleFonts.cairo(
                  color: textGrey,
                  fontSize: 9.5.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(width: 10.w),
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: available ? mint : background,
              shape: BoxShape.circle,
            ),
            child: Icon(
              available
                  ? Icons.delivery_dining_rounded
                  : Icons.pause_rounded,
              color: available ? teal : textGrey,
              size: 21.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      textAlign: TextAlign.right,
      style: GoogleFonts.cairo(
        color: textDark,
        fontSize: 15.sp,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _accountMenu(Map<String, dynamic> driver) {
    final rows = <Widget>[
      _menuTile(
        icon: Icons.badge_outlined,
        title: 'بيانات الطيار',
        subtitle: 'المركبة، مواعيد العمل والبيانات الشخصية',
        onTap: () => _showDriverInfo(driver),
      ),
      _menuTile(
        icon: Icons.verified_user_outlined,
        title: 'حالة الحساب',
        subtitle: driver['isActive'] == false
            ? 'الحساب موقوف'
            : 'الحساب نشط ويعمل بشكل طبيعي',
        trailingText: driver['isActive'] == false ? 'موقوف' : 'نشط',
        onTap: () => _showAccountStatus(driver),
      ),
      _menuTile(
        icon: Icons.photo_camera_outlined,
        title: 'الصورة الشخصية',
        subtitle: 'تغيير صورة حسابك',
        onTap: loading ? null : pickAndUpdateProfileImage,
      ),
    ];

    return _menuContainer(rows);
  }

  Widget _supportMenu() {
    return _menuContainer([
      _menuTile(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'الدعم عبر واتساب',
        subtitle: 'للطلبات والمحفظة ومشاكل الحساب',
        onTap: whatsappSupport,
      ),
      _menuTile(
        icon: Icons.headset_mic_outlined,
        title: 'اتصل بالدعم',
        subtitle: 'تواصل مباشرة مع فريق Bringo',
        onTap: callSupport,
      ),
    ]);
  }

  Widget _menuContainer(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: border),
      ),
      child: Column(
        children: List.generate(children.length, (index) {
          return Column(
            children: [
              children[index],
              if (index != children.length - 1)
                Divider(
                  height: 1,
                  indent: 15.w,
                  endIndent: 61.w,
                  color: border,
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    String? trailingText,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18.r),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 13.w,
          vertical: 13.h,
        ),
        child: Row(
          children: [
            Icon(
              Icons.arrow_back_ios_new_rounded,
              color: textGrey.withOpacity(.55),
              size: 13.sp,
            ),
            if (trailingText != null) ...[
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 7.w,
                  vertical: 3.h,
                ),
                decoration: BoxDecoration(
                  color: mint,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  trailingText,
                  style: GoogleFonts.cairo(
                    color: darkTeal,
                    fontSize: 8.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
            const Spacer(),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.cairo(
                      color: textDark,
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
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
              width: 38.w,
              height: 38.w,
              decoration: const BoxDecoration(
                color: mint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: teal,
                size: 19.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logoutTile() {
    return InkWell(
      onTap: logout,
      borderRadius: BorderRadius.circular(18.r),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 14.w,
          vertical: 13.h,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF5F5),
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: danger.withOpacity(.12),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.arrow_back_ios_new_rounded,
              color: danger.withOpacity(.65),
              size: 13.sp,
            ),
            const Spacer(),
            Text(
              'تسجيل الخروج',
              style: GoogleFonts.cairo(
                color: danger,
                fontSize: 12.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(width: 10.w),
            Container(
              width: 37.w,
              height: 37.w,
              decoration: BoxDecoration(
                color: danger.withOpacity(.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.logout_rounded,
                color: danger,
                size: 18.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDriverInfo(Map<String, dynamic> driver) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: _InfoSheet(
          title: 'بيانات الطيار',
          icon: Icons.badge_outlined,
          rows: [
            _SheetRow(
              'رقم البطاقة',
              _text(driver['nationalId']),
            ),
            _SheetRow(
              'نوع المركبة',
              _text(driver['vehicleType']),
            ),
            _SheetRow(
              'مواعيد العمل',
              _text(driver['workHours']),
            ),
            _SheetRow(
              'التقييم',
              _text(driver['rating'], '5'),
            ),
            _SheetRow(
              'عدد الطلبات',
              _text(driver['totalOrders'], '0'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAccountStatus(Map<String, dynamic> driver) {
    final active = driver['isActive'] != false;
    final completed = driver['profileCompleted'] == true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: _InfoSheet(
          title: 'حالة الحساب',
          icon: Icons.verified_user_outlined,
          rows: [
            _SheetRow(
              'الحساب',
              active ? 'نشط' : 'موقوف',
            ),
            _SheetRow(
              'البيانات',
              completed ? 'مكتملة' : 'غير مكتملة',
            ),
            _SheetRow(
              'استقبال الطلبات',
              driver['isAvailable'] == true ? 'متاح' : 'غير متاح',
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState({
    String title = 'تعذر تحميل الحساب',
    String subtitle = 'تحقق من الإنترنت وحاول مرة أخرى',
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 65.w,
              height: 65.w,
              decoration: const BoxDecoration(
                color: mint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_off_outlined,
                color: teal,
                size: 29.sp,
              ),
            ),
            SizedBox(height: 13.h),
            Text(
              title,
              style: GoogleFonts.cairo(
                color: textDark,
                fontSize: 15.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              subtitle,
              textAlign: TextAlign.center,
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

class _ProfileImage extends StatelessWidget {
  final String image;

  const _ProfileImage({required this.image});

  @override
  Widget build(BuildContext context) {
    if (image.trim().isEmpty) return _fallback();

    if (image.startsWith('http')) {
      return Image.network(
        image,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }

    try {
      final source = image.startsWith('data:image')
          ? image.split(',').last
          : image;
      return Image.memory(
        base64Decode(source),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    } catch (_) {
      return _fallback();
    }
  }

  Widget _fallback() {
    return Container(
      color: const Color(0xFFEAF3F2),
      child: Icon(
        Icons.person_rounded,
        color: const Color(0xFF1F5A59),
        size: 37.sp,
      ),
    );
  }
}

class _InfoSheet extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_SheetRow> rows;

  const _InfoSheet({
    required this.title,
    required this.icon,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    const darkTeal = Color(0xFF174746);
    const teal = Color(0xFF1F5A59);
    const mint = Color(0xFFEAF3F2);
    const textDark = Color(0xFF182322);
    const textGrey = Color(0xFF77817F);
    const border = Color(0xFFE3EAE8);

    return Container(
      padding: EdgeInsets.fromLTRB(
        18.w,
        10.h,
        18.w,
        26.h + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28.r),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: border,
              borderRadius: BorderRadius.circular(20.r),
            ),
          ),
          SizedBox(height: 18.h),
          Row(
            children: [
              const Spacer(),
              Text(
                title,
                style: GoogleFonts.cairo(
                  color: textDark,
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(width: 9.w),
              Container(
                width: 41.w,
                height: 41.w,
                decoration: const BoxDecoration(
                  color: mint,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: teal,
                  size: 20.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          ...List.generate(rows.length, (index) {
            final row = rows[index];
            return Container(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              decoration: BoxDecoration(
                border: index == rows.length - 1
                    ? null
                    : const Border(
                        bottom: BorderSide(color: border),
                      ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.value,
                      textAlign: TextAlign.left,
                      style: GoogleFonts.cairo(
                        color: darkTeal,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(width: 15.w),
                  Text(
                    row.title,
                    style: GoogleFonts.cairo(
                      color: textGrey,
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SheetRow {
  final String title;
  final String value;

  const _SheetRow(this.title, this.value);
}

class _LogoutSheet extends StatelessWidget {
  const _LogoutSheet();

  @override
  Widget build(BuildContext context) {
    const danger = Color(0xFFD94C55);
    const textDark = Color(0xFF182322);
    const textGrey = Color(0xFF77817F);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          20.w,
          12.h,
          20.w,
          24.h + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(28.r),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: const Color(0xFFE3EAE8),
                borderRadius: BorderRadius.circular(20.r),
              ),
            ),
            SizedBox(height: 18.h),
            Container(
              width: 55.w,
              height: 55.w,
              decoration: BoxDecoration(
                color: danger.withOpacity(.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.logout_rounded,
                color: danger,
                size: 25.sp,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'تسجيل الخروج؟',
              style: GoogleFonts.cairo(
                color: textDark,
                fontSize: 17.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'سيتم إيقاف استقبال الطلبات وتسجيل خروجك من التطبيق.',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                color: textGrey,
                fontSize: 10.5.sp,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 18.h),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48.h,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textDark,
                        side: const BorderSide(
                          color: Color(0xFFE3EAE8),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      child: Text(
                        'إلغاء',
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: SizedBox(
                    height: 48.h,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: danger,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      child: Text(
                        'خروج',
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BringoMark extends StatelessWidget {
  final double size;

  const _BringoMark({required this.size});

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

class _AccountShimmer extends StatefulWidget {
  const _AccountShimmer();

  @override
  State<_AccountShimmer> createState() => _AccountShimmerState();
}

class _AccountShimmerState extends State<_AccountShimmer>
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
            padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 120.h),
            children: [
              Row(
                children: [
                  bone(41.w, 41.w, radius: 21.r),
                  const Spacer(),
                  bone(110.w, 20.h),
                  SizedBox(width: 10.w),
                  bone(39.w, 39.w, radius: 13.r),
                ],
              ),
              SizedBox(height: 20.h),
              bone(double.infinity, 150.h, radius: 25.r),
              SizedBox(height: 12.h),
              bone(double.infinity, 72.h, radius: 20.r),
              SizedBox(height: 25.h),
              bone(70.w, 15.h),
              SizedBox(height: 9.h),
              bone(double.infinity, 190.h, radius: 20.r),
              SizedBox(height: 25.h),
              bone(70.w, 15.h),
              SizedBox(height: 9.h),
              bone(double.infinity, 130.h, radius: 20.r),
            ],
          ),
        );
      },
    );
  }
}
