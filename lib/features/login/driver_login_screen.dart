import 'package:bringo_driver/core/routes/app_routes.dart';
import 'package:bringo_driver/core/session/driver_session.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class DriverLoginScreen extends StatefulWidget {
  const DriverLoginScreen({super.key});

  @override
  State<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends State<DriverLoginScreen> {
  static const Color teal = Color(0xFF1F5A59);
  static const Color darkTeal = Color(0xFF174746);
  static const Color lime = Color(0xFFDDFB8A);
  static const Color mint = Color(0xFFEAF3F2);
  static const Color background = Color(0xFFF7FAF8);
  static const Color textDark = Color(0xFF182322);
  static const Color textGrey = Color(0xFF77817F);
  static const Color border = Color(0xFFE3EAE8);

  final phoneController = TextEditingController();
  final codeController = TextEditingController();
  final phoneFocus = FocusNode();
  final codeFocus = FocusNode();

  bool loading = false;
  bool obscureCode = true;

  @override
  void dispose() {
    phoneController.dispose();
    codeController.dispose();
    phoneFocus.dispose();
    codeFocus.dispose();
    super.dispose();
  }

  Future<void> login() async {
    FocusScope.of(context).unfocus();

    final phone = _normalizePhone(phoneController.text);
    final code = codeController.text.trim();

    if (phone.isEmpty) {
      _msg('اكتب رقم الهاتف');
      phoneFocus.requestFocus();
      return;
    }

    if (code.isEmpty) {
      _msg('اكتب كود الدخول');
      codeFocus.requestFocus();
      return;
    }

    try {
      setState(() => loading = true);

      // Compatible with the current RTDB structure.
      // IMPORTANT: RTDB security rules should prevent public reads of /drivers.
      final snapshot = await FirebaseDatabase.instance.ref('drivers').get();

      if (!snapshot.exists || snapshot.value == null) {
        _msg('تعذر تسجيل الدخول، تواصل مع الإدارة');
        return;
      }

      final data = Map<dynamic, dynamic>.from(snapshot.value as Map);

      Map<String, dynamic>? foundDriver;
      String? foundKey;

      for (final entry in data.entries) {
        if (entry.value is! Map) continue;

        final driver = Map<String, dynamic>.from(entry.value as Map);

        final savedPhone = _normalizePhone(
          driver['phone']?.toString() ?? '',
        );
        final savedCode = driver['code']?.toString().trim() ?? '';
        final isActive = driver['isActive'] != false;

        if (savedPhone == phone && savedCode == code && isActive) {
          foundDriver = driver;
          foundKey = entry.key.toString();
          break;
        }
      }

      if (foundDriver == null || foundKey == null) {
        _msg('رقم الهاتف أو كود الدخول غير صحيح');
        return;
      }

      final driverId =
          foundDriver['id']?.toString().trim().isNotEmpty == true
              ? foundDriver['id'].toString()
              : foundKey;

      final driverName =
          foundDriver['name']?.toString().trim().isNotEmpty == true
              ? foundDriver['name'].toString()
              : 'طيار Bringo';

      final driverPhone =
          foundDriver['phone']?.toString().trim().isNotEmpty == true
              ? foundDriver['phone'].toString()
              : phone;

      await DriverSession.saveDriver(
        driverId: driverId,
        name: driverName,
        phone: driverPhone,
      );

      final now = DateTime.now().millisecondsSinceEpoch;

      await FirebaseDatabase.instance.ref('drivers/$foundKey').update({
        'lastLoginAt': now,
        'lastSeenAt': now,
        'updatedAt': now,
      });

      final profileCompleted = foundDriver['profileCompleted'] == true;

      if (!mounted) return;

      if (profileCompleted) {
        context.go(AppRoutes.home);
      } else {
        context.go(AppRoutes.profileSetup);
      }
    } catch (_) {
      _msg('تعذر تسجيل الدخول، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _normalizePhone(String value) {
    var phone = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (phone.startsWith('0020')) {
      phone = phone.substring(4);
    } else if (phone.startsWith('20') && phone.length > 11) {
      phone = phone.substring(2);
    }

    if (phone.length == 10 && phone.startsWith('1')) {
      phone = '0$phone';
    }

    return phone;
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
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    22.w,
                    18.h,
                    22.w,
                    24.h,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 42.h,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _topBrand(),
                          const Spacer(),
                          _hero(),
                          SizedBox(height: 32.h),
                          _loginCard(),
                          SizedBox(height: 17.h),
                          _adminNotice(),
                          const Spacer(),
                          SizedBox(height: 20.h),
                          _footer(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBrand() {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 10.w,
            vertical: 6.h,
          ),
          decoration: BoxDecoration(
            color: mint,
            borderRadius: BorderRadius.circular(30.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified_user_outlined,
                color: darkTeal,
                size: 14.sp,
              ),
              SizedBox(width: 5.w),
              Text(
                'دخول الطيارين',
                style: GoogleFonts.cairo(
                  color: darkTeal,
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _hero() {
    return Column(
      children: [
        Container(
          width: 118.w,
          height: 118.w,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(34.r),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: darkTeal.withOpacity(.10),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: const Center(
            child: _BringoHeroLogo(),
          ),
        ),
        SizedBox(height: 22.h),
        Text(
          'أهلًا بيك في Bringo',
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            color: textDark,
            fontSize: 25.sp,
            fontWeight: FontWeight.w900,
            height: 1.25,
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          'سجّل دخولك وابدأ مشاويرك',
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            color: textGrey,
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _loginCard() {
    return Container(
      padding: EdgeInsets.all(17.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: darkTeal.withOpacity(.035),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'تسجيل الدخول',
            style: GoogleFonts.cairo(
              color: textDark,
              fontSize: 16.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            'استخدم البيانات المسلّمة لك من إدارة Bringo',
            style: GoogleFonts.cairo(
              color: textGrey,
              fontSize: 9.5.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 17.h),
          _input(
            controller: phoneController,
            focusNode: phoneFocus,
            label: 'رقم الهاتف',
            hint: '01xxxxxxxxx',
            icon: Icons.phone_android_rounded,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(14),
            ],
            onSubmitted: (_) => codeFocus.requestFocus(),
          ),
          SizedBox(height: 12.h),
          _input(
            controller: codeController,
            focusNode: codeFocus,
            label: 'كود الدخول',
            hint: 'أدخل الكود الخاص بك',
            icon: Icons.lock_outline_rounded,
            keyboardType: TextInputType.text,
            obscureText: obscureCode,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => login(),
            suffix: IconButton(
              splashRadius: 20.r,
              onPressed: () {
                setState(() => obscureCode = !obscureCode);
              },
              icon: Icon(
                obscureCode
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: textGrey,
                size: 19.sp,
              ),
            ),
          ),
          SizedBox(height: 18.h),
          SizedBox(
            width: double.infinity,
            height: 54.h,
            child: ElevatedButton(
              onPressed: loading ? null : login,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: darkTeal,
                foregroundColor: Colors.white,
                disabledBackgroundColor: darkTeal.withOpacity(.55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.r),
                ),
              ),
              child: loading
                  ? SizedBox(
                      width: 22.w,
                      height: 22.w,
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.4,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'دخول إلى حسابي',
                          style: GoogleFonts.cairo(
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Icon(
                          Icons.arrow_back_rounded,
                          size: 19.sp,
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _adminNotice() {
    return Container(
      padding: EdgeInsets.all(13.w),
      decoration: BoxDecoration(
        color: mint,
        borderRadius: BorderRadius.circular(17.r),
        border: Border.all(
          color: teal.withOpacity(.08),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: RichText(
              textAlign: TextAlign.right,
              text: TextSpan(
                style: GoogleFonts.cairo(
                  color: textGrey,
                  fontSize: 9.3.sp,
                  height: 1.6,
                  fontWeight: FontWeight.w600,
                ),
                children: [
                  TextSpan(
                    text: 'بيانات الدخول تصدر من الإدارة فقط.\n',
                    style: GoogleFonts.cairo(
                      color: darkTeal,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const TextSpan(
                    text:
                        'الكود مخصص لك شخصيًا. لا تشاركه مع أي شخص، وفريق Bringo لن يطلب منك إرسال كود الدخول لأي شخص.',
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 11.w),
          Container(
            width: 39.w,
            height: 39.w,
            decoration: BoxDecoration(
              color: lime,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              Icons.admin_panel_settings_outlined,
              color: darkTeal,
              size: 20.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.lock_outline_rounded,
          color: textGrey.withOpacity(.7),
          size: 13.sp,
        ),
        SizedBox(width: 5.w),
        Text(
          'حساب مخصص لطياري Bringo المعتمدين',
          style: GoogleFonts.cairo(
            color: textGrey.withOpacity(.8),
            fontSize: 8.5.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _input({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    TextInputAction? textInputAction,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onSubmitted,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: EdgeInsets.only(right: 3.w, bottom: 6.h),
          child: Text(
            label,
            style: GoogleFonts.cairo(
              color: textDark,
              fontSize: 10.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          obscureText: obscureText,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          onSubmitted: onSubmitted,
          textAlign: TextAlign.right,
          style: GoogleFonts.cairo(
            color: textDark,
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.cairo(
              color: textGrey.withOpacity(.7),
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Container(
              margin: EdgeInsets.all(8.w),
              width: 38.w,
              height: 38.w,
              decoration: BoxDecoration(
                color: mint,
                borderRadius: BorderRadius.circular(11.r),
              ),
              child: Icon(
                icon,
                color: teal,
                size: 19.sp,
              ),
            ),
            suffixIcon: suffix,
            filled: true,
            fillColor: background,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 13.w,
              vertical: 16.h,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15.r),
              borderSide: const BorderSide(color: border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15.r),
              borderSide: const BorderSide(
                color: teal,
                width: 1.4,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15.r),
            ),
          ),
        ),
      ],
    );
  }
}


class _BringoHeroLogo extends StatelessWidget {
  const _BringoHeroLogo();

  @override
  Widget build(BuildContext context) {
    const darkTeal = Color(0xFF174746);
    const lime = Color(0xFFDDFB8A);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 66.w,
          height: 66.w,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                'b',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 58.sp,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -4,
                ),
              ),
              Positioned(
                top: 3.h,
                right: 9.w,
                child: Transform.rotate(
                  angle: -.55,
                  child: Container(
                    width: 22.w,
                    height: 12.h,
                    decoration: BoxDecoration(
                      color: lime,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20.r),
                        bottomRight: Radius.circular(20.r),
                        topRight: Radius.circular(7.r),
                        bottomLeft: Radius.circular(7.r),
                      ),
                      border: Border.all(
                        color: Colors.white,
                        width: 2.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Transform.translate(
          offset: Offset(0, -4.h),
          child: Text(
            'برينجو',
            style: GoogleFonts.cairo(
              color: darkTeal,
              fontSize: 13.sp,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _BringoMark extends StatelessWidget {
  final double size;

  const _BringoMark({required this.size});

  @override
  Widget build(BuildContext context) {
    const darkTeal = Color(0xFF174746);
    const lime = Color(0xFFDDFB8A);

    return Container(
      width: size.w,
      height: size.w,
      decoration: BoxDecoration(
        color: darkTeal,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'b',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24.sp,
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
                  color: lime,
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
