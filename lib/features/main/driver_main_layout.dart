import 'package:bringo_driver/features/account/driver_account_screen.dart';
import 'package:bringo_driver/features/home/driver_home_screen.dart';
import 'package:bringo_driver/features/orders/driver_orders_screen.dart';
import 'package:bringo_driver/features/wallet/driver_wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class DriverMainLayout extends StatefulWidget {
  const DriverMainLayout({super.key});

  @override
  State<DriverMainLayout> createState() => _DriverMainLayoutState();
}

class _DriverMainLayoutState extends State<DriverMainLayout> {
  static const darkTeal = Color(0xFF174746);
  static const lime = Color(0xFFDDFB8A);
  static const background = Color(0xFFF7FAF8);
  static const border = Color(0xFFE4EAE8);

  int currentIndex = 0;

  final pages = const [
    DriverHomeScreen(),
    DriverOrdersScreen(),
    DriverWalletScreen(),
    DriverAccountScreen(),
  ];

  void changePage(int index) {
    if (index == currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() => currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      extendBody: true,
      body: IndexedStack(index: currentIndex, children: pages),
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.fromLTRB(14.w, 0, 14.w, 10.h),
        child: Container(
          height: 70.h,
          padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 7.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: darkTeal.withOpacity(.07),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(child: _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, title: 'الرئيسية', active: currentIndex == 0, onTap: () => changePage(0))),
              Expanded(child: _NavItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long_rounded, title: 'الطلبات', active: currentIndex == 1, onTap: () => changePage(1))),
              Expanded(child: _NavItem(icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet_rounded, title: 'المحفظة', active: currentIndex == 2, onTap: () => changePage(2))),
              Expanded(child: _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, title: 'حسابي', active: currentIndex == 3, onTap: () => changePage(3))),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  static const darkTeal = Color(0xFF174746);
  static const lime = Color(0xFFDDFB8A);
  static const inactive = Color(0xFF8A9491);

  final IconData icon;
  final IconData activeIcon;
  final String title;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.title,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: double.infinity,
          decoration: BoxDecoration(
            color: active ? lime.withOpacity(.42) : Colors.transparent,
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: active ? 31.w : 28.w,
                height: active ? 31.w : 28.w,
                decoration: BoxDecoration(
                  color: active ? darkTeal : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  active ? activeIcon : icon,
                  color: active ? Colors.white : inactive,
                  size: active ? 18.sp : 20.sp,
                ),
              ),
              SizedBox(height: 2.h),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: GoogleFonts.cairo(
                  color: active ? darkTeal : inactive,
                  fontSize: active ? 8.6.sp : 8.2.sp,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                  height: 1.1,
                ),
                child: Text(title, maxLines: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
