import 'dart:convert';

import 'package:bringo_driver/core/constants/app_colors.dart';
import 'package:bringo_driver/core/routes/app_routes.dart';
import 'package:bringo_driver/core/session/driver_session.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class DriverProfileSetupScreen extends StatefulWidget {
  const DriverProfileSetupScreen({super.key});

  @override
  State<DriverProfileSetupScreen> createState() =>
      _DriverProfileSetupScreenState();
}

class _DriverProfileSetupScreenState extends State<DriverProfileSetupScreen> {
  final nameController = TextEditingController();
  final nationalIdController = TextEditingController();

  String vehicleType = 'موتوسيكل';
  String startTime = '10 صباحًا';
  String endTime = '10 مساءً';

  String personalImage = '';
  String nationalIdImage = '';
  String licenseImage = '';
  String vehicleImage = '';

  bool loading = false;

  final picker = ImagePicker();

  final List<String> vehicleTypes = [
    'موتوسيكل',
    'سكوتر',
    'دراجة',
    'سيارة',
  ];

  final List<String> times = [
    '6 صباحًا',
    '7 صباحًا',
    '8 صباحًا',
    '9 صباحًا',
    '10 صباحًا',
    '11 صباحًا',
    '12 ظهرًا',
    '1 مساءً',
    '2 مساءً',
    '3 مساءً',
    '4 مساءً',
    '5 مساءً',
    '6 مساءً',
    '7 مساءً',
    '8 مساءً',
    '9 مساءً',
    '10 مساءً',
    '11 مساءً',
    '12 مساءً',
  ];

  Future<void> pickImage(String type) async {
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 45,
      maxWidth: 1200,
      maxHeight: 1200,
    );

    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final base64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';

    setState(() {
      if (type == 'personal') personalImage = base64;
      if (type == 'national') nationalIdImage = base64;
      if (type == 'license') licenseImage = base64;
      if (type == 'vehicle') vehicleImage = base64;
    });
  }

  Future<void> saveProfile() async {
    final driverId = DriverSession.driverId;

    if (driverId == null || driverId.isEmpty) return;

    if (nameController.text.trim().isEmpty ||
        nationalIdController.text.trim().length < 14 ||
        personalImage.isEmpty ||
        nationalIdImage.isEmpty ||
        licenseImage.isEmpty ||
        vehicleImage.isEmpty) {
      _msg('كمل كل البيانات والصور المطلوبة');
      return;
    }

    final workHours = '$startTime - $endTime';

    try {
      setState(() => loading = true);

      await FirebaseDatabase.instance.ref('drivers/$driverId').update({
        'name': nameController.text.trim(),
        'nationalId': nationalIdController.text.trim(),
        'vehicleType': vehicleType,
        'workHours': workHours,
        'personalImage': personalImage,
        'nationalIdImage': nationalIdImage,
        'licenseImage': licenseImage,
        'vehicleImage': vehicleImage,
        'profileCompleted': true,
        'isAvailable': true,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      await DriverSession.saveDriver(
        driverId: driverId,
        name: nameController.text.trim(),
        phone: DriverSession.driverPhone ?? '',
      );

      if (!mounted) return;
      context.go(AppRoutes.mainLayout);
    } catch (e) {
      _msg('حصل خطأ أثناء حفظ البيانات');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _msg(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text, style: GoogleFonts.cairo())),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    nationalIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7F8),
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 28.h),
            physics: const BouncingScrollPhysics(),
            children: [
              Text(
                'استكمال بيانات الطيار',
                style: GoogleFonts.cairo(
                  color: AppColors.dark,
                  fontSize: 27.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'من فضلك أدخل بياناتك بدقة حتى يتم تفعيل حسابك.',
                style: GoogleFonts.cairo(
                  color: Colors.grey.shade600,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 22.h),
              _sectionCard(
                title: 'البيانات الأساسية',
                children: [
                  _input(
                    controller: nameController,
                    hint: 'اسم الطيار بالكامل',
                    icon: Icons.person_rounded,
                  ),
                  _input(
                    controller: nationalIdController,
                    hint: 'رقم البطاقة 14 رقم',
                    icon: Icons.badge_rounded,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(14),
                    ],
                  ),
                  _dropdown(
                    title: 'نوع المركبة',
                    value: vehicleType,
                    items: vehicleTypes,
                    icon: Icons.two_wheeler_rounded,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => vehicleType = value);
                    },
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              _sectionCard(
                title: 'مواعيد العمل',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _dropdown(
                          title: 'إلى',
                          value: endTime,
                          items: times,
                          icon: Icons.schedule_rounded,
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => endTime = value);
                          },
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: _dropdown(
                          title: 'من',
                          value: startTime,
                          items: times,
                          icon: Icons.access_time_filled_rounded,
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => startTime = value);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              _sectionCard(
                title: 'صور التوثيق',
                children: [
                  _imageBtn(
                    title: 'الصورة الشخصية',
                    subtitle: 'افتح الكاميرا وصوّر وجهك بوضوح',
                    image: personalImage,
                    icon: Icons.person_pin_rounded,
                    onTap: () => pickImage('personal'),
                  ),
                  _imageBtn(
                    title: 'صورة البطاقة',
                    subtitle: 'صوّر البطاقة بشكل واضح',
                    image: nationalIdImage,
                    icon: Icons.credit_card_rounded,
                    onTap: () => pickImage('national'),
                  ),
                  _imageBtn(
                    title: 'صورة الرخصة',
                    subtitle: 'صوّر رخصة القيادة أو التصريح',
                    image: licenseImage,
                    icon: Icons.assignment_ind_rounded,
                    onTap: () => pickImage('license'),
                  ),
                  _imageBtn(
                    title: 'صورة المركبة',
                    subtitle: 'صوّر الموتوسيكل أو وسيلة التوصيل',
                    image: vehicleImage,
                    icon: Icons.two_wheeler_rounded,
                    onTap: () => pickImage('vehicle'),
                  ),
                ],
              ),
              SizedBox(height: 24.h),
              SizedBox(
                height: 56.h,
                child: ElevatedButton(
                  onPressed: loading ? null : saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                  ),
                  child: Text(
                    loading ? 'جاري الحفظ...' : 'حفظ وبدء العمل',
                    style: GoogleFonts.cairo(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            title,
            style: GoogleFonts.cairo(
              color: AppColors.dark,
              fontSize: 18.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 14.h),
          ...children,
        ],
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        textAlign: TextAlign.right,
        style: GoogleFonts.cairo(
          color: AppColors.dark,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: GoogleFonts.cairo(
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Icon(icon, color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String title,
    required String value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          style: GoogleFonts.cairo(
            color: AppColors.dark,
            fontWeight: FontWeight.w800,
          ),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item, textAlign: TextAlign.right),
            );
          }).toList(),
          onChanged: onChanged,
          hint: Text(title),
        ),
      ),
    );
  }

  Widget _imageBtn({
    required String title,
    required String subtitle,
    required String image,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final uploaded = image.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: uploaded ? AppColors.softPink : const Color(0xFFF7F7F8),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: uploaded
                ? AppColors.primary.withOpacity(.25)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48.w,
              height: 48.w,
              decoration: BoxDecoration(
                color: uploaded ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Icon(
                uploaded ? Icons.check_rounded : Icons.camera_alt_rounded,
                color: uploaded ? Colors.white : AppColors.primary,
                size: 24.sp,
              ),
            ),
            const Spacer(),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    uploaded ? '$title تم رفعها' : title,
                    style: GoogleFonts.cairo(
                      color: AppColors.dark,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    uploaded ? 'اضغط لإعادة التصوير' : subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      color: Colors.grey.shade600,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            Icon(icon, color: AppColors.primary, size: 24.sp),
          ],
        ),
      ),
    );
  }
}
