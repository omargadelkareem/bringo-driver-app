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

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  List<Map<String, dynamic>> parseItems(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.where((e) => e is Map).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    if (value is Map) return value.values.where((e) => e is Map).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return [];
  }

  String buildAddress(Map<String, dynamic> order) {
    final directAddress = order['customerAddress'] ?? order['deliveryAddress'] ?? order['address'] ?? order['fullAddress'];
    if (directAddress is Map) {
      final a = Map<String, dynamic>.from(directAddress);
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
    final text = directAddress?.toString().trim() ?? '';
    if (text.isEmpty) return 'لم يتم تحديد العنوان';
    if (text.contains('{') && text.contains('}')) {
      return text.replaceAll('{', '').replaceAll('}', '').replaceAll('notes:', 'ملاحظات:').replaceAll('floor:', 'الدور:').replaceAll('apartment:', 'شقة:').replaceAll('building:', 'عمارة:').replaceAll('street:', 'شارع:').replaceAll('area:', 'منطقة:').replaceAll(',', ' - ');
    }
    return text;
  }

  String cleanPhone(String phone) => phone.replaceAll(' ', '').replaceAll('-', '').trim();
  Future<void> callCustomer(String phone) async { final clean = cleanPhone(phone); if (clean.isNotEmpty) await launchUrl(Uri.parse('tel:$clean')); }
  Future<void> whatsappCustomer(String phone, String name) async {
    var clean = cleanPhone(phone); if (clean.isEmpty) return; if (clean.startsWith('0')) clean = '2$clean';
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
        if (status == 'pickedUp') widget.order['pickedUpAt'] = now;
        if (status == 'onDelivery') widget.order['onDeliveryAt'] = now;
      });
      _message(status == 'pickedUp' ? 'تم استلام الطلب من المتجر' : 'بدأ التوصيل للعميل');
    } catch (_) {
      if (mounted) _message('حدث خطأ أثناء تحديث الطلب');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(value, textAlign: TextAlign.right, style: GoogleFonts.cairo(fontWeight: FontWeight.w700)), backgroundColor: darkTeal, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r))));
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final customerName = _firstText([order['customerName'], order['name']]);
    final phone = _firstText([order['customerPhone'], order['phone']]);
    final address = buildAddress(order);
    final total = _num(order['total']); final subtotal = _num(order['subtotal']); final deliveryFee = _num(order['deliveryFee']);
    final status = _firstText([order['status'], order['orderStatus'], 'assigned']);
    final items = parseItems(order['items']); final storeId = _firstText([order['storeId']]);
    final directStoreName = _firstText([order['storeName'], order['restaurantName'], order['pharmacyName'], order['merchantName'], order['shopName']]);
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(backgroundColor: background, body: SafeArea(child: Column(children: [_topBar(context), Expanded(child: ListView(padding: EdgeInsets.fromLTRB(18.w,8.h,18.w,28.h), physics: const BouncingScrollPhysics(), children: [
      _journeyHero(status), SizedBox(height:14.h), _StoreCard(storeId:storeId,directName:directStoreName,storeType:_firstText([order['storeType']])), SizedBox(height:14.h), _sectionLabel('التوصيل للعميل'), SizedBox(height:9.h), _customerCard(name:customerName.isEmpty?'عميل Bringo':customerName,phone:phone,address:address), SizedBox(height:22.h), _sectionLabel('تفاصيل الحساب'), SizedBox(height:9.h), _paymentCard(subtotal:subtotal,deliveryFee:deliveryFee,total:total), SizedBox(height:22.h), Row(children:[Container(padding:EdgeInsets.symmetric(horizontal:9.w,vertical:4.h),decoration:BoxDecoration(color:mint,borderRadius:BorderRadius.circular(20.r)),child:Text('${items.length} منتج',style:GoogleFonts.cairo(color:darkTeal,fontSize:10.sp,fontWeight:FontWeight.w900))),const Spacer(),_sectionLabel('محتويات الطلب')]), SizedBox(height:9.h),
      if(items.isEmpty) _emptyProducts() else Container(decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(21.r),border:Border.all(color:border)),child:Column(children:List.generate(items.length,(index)=>Column(children:[_ProductItem(item:items[index]),if(index!=items.length-1) Divider(height:1,indent:14.w,endIndent:14.w,color:border)])))), SizedBox(height:24.h), _statusAction(status)
    ])))]))));
  }

  Widget _topBar(BuildContext context)=>Padding(padding:EdgeInsets.fromLTRB(18.w,10.h,18.w,8.h),child:Row(children:[InkWell(onTap:()=>Navigator.pop(context),borderRadius:BorderRadius.circular(50.r),child:Container(width:43.w,height:43.w,decoration:BoxDecoration(color:Colors.white,shape:BoxShape.circle,border:Border.all(color:border)),child:Icon(Icons.arrow_back_ios_new_rounded,color:darkTeal,size:17.sp))),const Spacer(),Column(crossAxisAlignment:CrossAxisAlignment.end,children:[Text('تفاصيل المشوار',style:GoogleFonts.cairo(color:textDark,fontSize:19.sp,fontWeight:FontWeight.w900)),Text(orderKey.isEmpty?'طلب Bringo':'#${_shortOrderId(orderKey)}',style:GoogleFonts.cairo(color:textGrey,fontSize:10.sp,fontWeight:FontWeight.w600))]),SizedBox(width:10.w),const _BringoMark(size:38)]));
  String _shortOrderId(String value)=>value.length<=7?value:value.substring(value.length-7).toUpperCase();

  Widget _journeyHero(String status){final data=_statusData(status);return Container(padding:EdgeInsets.all(18.w),decoration:BoxDecoration(color:darkTeal,borderRadius:BorderRadius.circular(24.r)),child:Column(crossAxisAlignment:CrossAxisAlignment.end,children:[Row(children:[Container(padding:EdgeInsets.symmetric(horizontal:10.w,vertical:5.h),decoration:BoxDecoration(color:lime,borderRadius:BorderRadius.circular(30.r)),child:Text(data.label,style:GoogleFonts.cairo(color:darkTeal,fontSize:10.sp,fontWeight:FontWeight.w900))),const Spacer(),Column(crossAxisAlignment:CrossAxisAlignment.end,children:[Text(data.title,style:GoogleFonts.cairo(color:Colors.white,fontSize:16.sp,fontWeight:FontWeight.w900)),SizedBox(height:2.h),Text(data.subtitle,style:GoogleFonts.cairo(color:Colors.white.withOpacity(.65),fontSize:10.5.sp,fontWeight:FontWeight.w600))]),SizedBox(width:10.w),Container(width:43.w,height:43.w,decoration:BoxDecoration(color:Colors.white.withOpacity(.09),shape:BoxShape.circle),child:Icon(data.icon,color:lime,size:22.sp))]),SizedBox(height:20.h),_progress(status)]));}
  Widget _progress(String rawStatus){final step=_stepForStatus(rawStatus);const labels=['قبول','استلام','في الطريق','تسليم'];return Row(children:List.generate(4,(index){final done=index<=step;return Expanded(child:Row(children:[if(index!=0) Expanded(child:Container(height:2.h,color:index<=step?lime:Colors.white.withOpacity(.15))),Column(children:[Container(width:24.w,height:24.w,decoration:BoxDecoration(color:done?lime:Colors.white.withOpacity(.10),shape:BoxShape.circle),child:Icon(done?Icons.check_rounded:Icons.circle,color:done?darkTeal:Colors.white.withOpacity(.35),size:done?15.sp:7.sp)),SizedBox(height:5.h),Text(labels[index],style:GoogleFonts.cairo(color:done?Colors.white:Colors.white.withOpacity(.40),fontSize:8.5.sp,fontWeight:FontWeight.w700))])])) ;}));}
  int _stepForStatus(String status){switch(status.toLowerCase()){case'pickedup':return 1;case'ondelivery':return 2;case'completed':case'delivered':return 3;default:return 0;}}
  _StatusData _statusData(String status){switch(status.toLowerCase()){case'pickedup':return const _StatusData('تم الاستلام','اتجه للعميل','الطلب معاك الآن، توجه لعنوان العميل',Icons.inventory_2_outlined);case'ondelivery':return const _StatusData('في الطريق','أنت في مرحلة التوصيل','وصل الطلب للعميل بأمان',Icons.delivery_dining_rounded);case'completed':case'delivered':return const _StatusData('تم التسليم','المشوار اكتمل','تم تسليم الطلب بنجاح',Icons.check_circle_outline_rounded);default:return const _StatusData('مقبول','اتجه للمتجر','استلم الطلب من المتجر وابدأ المشوار',Icons.storefront_rounded);}}
  Widget _sectionLabel(String value)=>Text(value,textAlign:TextAlign.right,style:GoogleFonts.cairo(color:textDark,fontSize:15.sp,fontWeight:FontWeight.w900));

  Widget _customerCard({required String name,required String phone,required String address})=>Container(padding:EdgeInsets.all(15.w),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(21.r),border:Border.all(color:border)),child:Column(children:[Row(children:[_contactCircle(icon:Icons.chat_bubble_outline_rounded,color:const Color(0xFF1FAF61),enabled:phone.isNotEmpty,onTap:()=>whatsappCustomer(phone,name)),SizedBox(width:8.w),_contactCircle(icon:Icons.call_outlined,color:teal,enabled:phone.isNotEmpty,onTap:()=>callCustomer(phone)),const Spacer(),Column(crossAxisAlignment:CrossAxisAlignment.end,children:[Text(name,style:GoogleFonts.cairo(color:textDark,fontSize:14.sp,fontWeight:FontWeight.w900)),if(phone.isNotEmpty)Text(phone,style:GoogleFonts.cairo(color:textGrey,fontSize:10.5.sp,fontWeight:FontWeight.w600))]),SizedBox(width:9.w),Container(width:43.w,height:43.w,decoration:const BoxDecoration(color:mint,shape:BoxShape.circle),child:Icon(Icons.person_outline_rounded,color:teal,size:21.sp))]),SizedBox(height:13.h),Container(width:double.infinity,padding:EdgeInsets.all(12.w),decoration:BoxDecoration(color:background,borderRadius:BorderRadius.circular(14.r)),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(Icons.location_on_outlined,color:teal,size:19.sp),SizedBox(width:7.w),Expanded(child:Text(address,textAlign:TextAlign.right,style:GoogleFonts.cairo(color:textDark,fontSize:11.sp,height:1.55,fontWeight:FontWeight.w700))) ]))]));
  Widget _contactCircle({required IconData icon,required Color color,required bool enabled,required VoidCallback onTap})=>InkWell(onTap:enabled?onTap:null,borderRadius:BorderRadius.circular(50.r),child:Container(width:39.w,height:39.w,decoration:BoxDecoration(color:enabled?color.withOpacity(.09):background,shape:BoxShape.circle),child:Icon(icon,color:enabled?color:Colors.grey.shade400,size:18.sp)));
  Widget _paymentCard({required double subtotal,required double deliveryFee,required double total})=>Container(padding:EdgeInsets.all(15.w),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(21.r),border:Border.all(color:border)),child:Column(children:[if(subtotal>0)...[_priceRow('قيمة المنتجات',subtotal),SizedBox(height:9.h)],_priceRow('رسوم التوصيل',deliveryFee,highlighted:true),Padding(padding:EdgeInsets.symmetric(vertical:11.h),child:Divider(height:1,color:border)),Row(children:[Text('${total.toStringAsFixed(0)} جنيه',style:GoogleFonts.cairo(color:darkTeal,fontSize:18.sp,fontWeight:FontWeight.w900)),const Spacer(),Text('الإجمالي',style:GoogleFonts.cairo(color:textDark,fontSize:13.sp,fontWeight:FontWeight.w900))]) ]));
  Widget _priceRow(String title,double value,{bool highlighted=false})=>Row(children:[Container(padding:highlighted?EdgeInsets.symmetric(horizontal:8.w,vertical:3.h):EdgeInsets.zero,decoration:highlighted?BoxDecoration(color:lime,borderRadius:BorderRadius.circular(10.r)):null,child:Text('${value.toStringAsFixed(0)} جنيه',style:GoogleFonts.cairo(color:darkTeal,fontSize:11.5.sp,fontWeight:FontWeight.w900))),const Spacer(),Text(title,style:GoogleFonts.cairo(color:textGrey,fontSize:11.sp,fontWeight:FontWeight.w700))]);
  Widget _emptyProducts()=>Container(width:double.infinity,padding:EdgeInsets.symmetric(vertical:24.h),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20.r),border:Border.all(color:border)),child:Column(children:[Icon(Icons.shopping_bag_outlined,color:textGrey,size:27.sp),SizedBox(height:6.h),Text('لا توجد منتجات مسجلة في الطلب',style:GoogleFonts.cairo(color:textGrey,fontSize:11.sp,fontWeight:FontWeight.w700))]));

  Widget _statusAction(String status){final s=status.toLowerCase();if(s=='completed'||s=='delivered')return Container(padding:EdgeInsets.all(15.w),decoration:BoxDecoration(color:mint,borderRadius:BorderRadius.circular(18.r)),child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(Icons.check_circle_rounded,color:teal,size:20.sp),SizedBox(width:7.w),Text('تم إنهاء هذا المشوار',style:GoogleFonts.cairo(color:darkTeal,fontSize:12.sp,fontWeight:FontWeight.w900))]));String title;String nextStatus;IconData icon;if(s=='pickedup'){title='بدء التوصيل للعميل';nextStatus='onDelivery';icon=Icons.delivery_dining_rounded;}else if(s=='ondelivery'){title='تأكيد تسليم الطلب';nextStatus='completed';icon=Icons.check_circle_outline_rounded;}else{title='تم استلام الطلب من المتجر';nextStatus='pickedUp';icon=Icons.inventory_2_outlined;}return SizedBox(width:double.infinity,height:54.h,child:ElevatedButton(onPressed:loading?null:()=>updateStatus(nextStatus),style:ElevatedButton.styleFrom(elevation:0,backgroundColor:teal,disabledBackgroundColor:teal.withOpacity(.45),foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16.r))),child:loading?SizedBox(width:21.w,height:21.w,child:const CircularProgressIndicator(strokeWidth:2.2,color:Colors.white)):Row(mainAxisAlignment:MainAxisAlignment.center,children:[Text(title,style:GoogleFonts.cairo(fontSize:13.sp,fontWeight:FontWeight.w900)),SizedBox(width:8.w),Icon(icon,size:20.sp)])));}
}

class _StoreCard extends StatelessWidget {
  final String storeId; final String directName; final String storeType;
  const _StoreCard({required this.storeId,required this.directName,required this.storeType});
  static const teal=Color(0xFF1F5A59),darkTeal=Color(0xFF174746),mint=Color(0xFFEAF3F2),textDark=Color(0xFF182322),textGrey=Color(0xFF77817F),border=Color(0xFFE3EAE8);
  Map<String,dynamic> _map(dynamic value)=>value is Map?Map<String,dynamic>.from(value):{};
  String _text(List<dynamic> values){for(final value in values){final text=value?.toString().trim()??'';if(text.isNotEmpty&&text!='null')return text;}return '';}
  Widget _buildCard({required String name,required String address,required String image})=>Container(padding:EdgeInsets.all(15.w),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(21.r),border:Border.all(color:border)),child:Row(crossAxisAlignment:CrossAxisAlignment.center,children:[Container(padding:EdgeInsets.symmetric(horizontal:9.w,vertical:5.h),decoration:BoxDecoration(color:mint,borderRadius:BorderRadius.circular(20.r)),child:Text(storeType.isEmpty?'نقطة الاستلام':storeType,style:GoogleFonts.cairo(color:darkTeal,fontSize:9.sp,fontWeight:FontWeight.w800))),const Spacer(),Expanded(flex:3,child:Column(crossAxisAlignment:CrossAxisAlignment.end,children:[Text(name.isEmpty?'متجر Bringo':name,maxLines:1,overflow:TextOverflow.ellipsis,style:GoogleFonts.cairo(color:textDark,fontSize:14.sp,fontWeight:FontWeight.w900)),SizedBox(height:3.h),Text(address.isEmpty?'استلام الطلب من هذا المتجر':address,maxLines:2,overflow:TextOverflow.ellipsis,textAlign:TextAlign.right,style:GoogleFonts.cairo(color:textGrey,fontSize:10.sp,height:1.4,fontWeight:FontWeight.w600))])),SizedBox(width:10.w),_StoreImage(image:image)]));
  @override Widget build(BuildContext context){if(storeId.isEmpty)return _buildCard(name:directName,address:'',image:'');return FutureBuilder<DataSnapshot>(future:FirebaseDatabase.instance.ref('stores/$storeId').get(),builder:(context,snapshot){final store=snapshot.hasData?_map(snapshot.data?.value):{};final name=directName.isNotEmpty?directName:_text([store['name'],store['storeName'],store['businessName'],store['title']]);final address=_text([store['address'],store['storeAddress'],store['area'],store['locationName']]);final image=_text([store['logo'],store['image'],store['storeLogo'],store['storeImage'],store['photo'],store['imageUrl']]);return _buildCard(name:name,address:address,image:image);});}
}

class _StoreImage extends StatelessWidget{final String image;const _StoreImage({required this.image});@override Widget build(BuildContext context)=>Container(width:51.w,height:51.w,padding:EdgeInsets.all(3.w),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14.r),border:Border.all(color:const Color(0xFFE3EAE8))),child:ClipRRect(borderRadius:BorderRadius.circular(11.r),child:_SmartImage(image:image,fallbackIcon:Icons.storefront_rounded)));}

class _ProductItem extends StatelessWidget{final Map<String,dynamic> item;const _ProductItem({required this.item});static const darkTeal=Color(0xFF174746),lime=Color(0xFFDDFB8A),textDark=Color(0xFF182322);double _num(dynamic value)=>double.tryParse(value?.toString()??'0')??0;@override Widget build(BuildContext context){final name=item['name']?.toString()??item['productName']?.toString()??'منتج';final image=item['image']?.toString()??item['imageUrl']?.toString()??'';final qty=item['quantity']?.toString()??item['qty']?.toString()??'1';final price=_num(item['price']);return Padding(padding:EdgeInsets.all(13.w),child:Row(children:[Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${price.toStringAsFixed(0)} ج',style:GoogleFonts.cairo(color:darkTeal,fontSize:12.5.sp,fontWeight:FontWeight.w900)),SizedBox(height:3.h),Container(padding:EdgeInsets.symmetric(horizontal:7.w,vertical:2.h),decoration:BoxDecoration(color:lime,borderRadius:BorderRadius.circular(9.r)),child:Text('× $qty',style:GoogleFonts.cairo(color:darkTeal,fontSize:9.sp,fontWeight:FontWeight.w900)))]),SizedBox(width:10.w),Expanded(child:Text(name,maxLines:2,overflow:TextOverflow.ellipsis,textAlign:TextAlign.right,style:GoogleFonts.cairo(color:textDark,fontSize:11.5.sp,height:1.45,fontWeight:FontWeight.w800))),SizedBox(width:10.w),SizedBox(width:53.w,height:53.w,child:ClipRRect(borderRadius:BorderRadius.circular(13.r),child:_SmartImage(image:image,fallbackIcon:Icons.shopping_bag_outlined))) ]));}}

class _SmartImage extends StatelessWidget{final String image;final IconData fallbackIcon;const _SmartImage({required this.image,required this.fallbackIcon});@override Widget build(BuildContext context){if(image.trim().isEmpty)return _fallback();if(image.startsWith('http'))return Image.network(image,fit:BoxFit.cover,errorBuilder:(_,__,___)=>_fallback());try{final source=image.startsWith('data:image')?image.split(',').last:image;return Image.memory(base64Decode(source),fit:BoxFit.cover,errorBuilder:(_,__,___)=>_fallback());}catch(_){return _fallback();}}Widget _fallback()=>Container(color:const Color(0xFFEAF3F2),child:Icon(fallbackIcon,color:const Color(0xFF1F5A59),size:23.sp));}

class _BringoMark extends StatelessWidget{final double size;const _BringoMark({required this.size});@override Widget build(BuildContext context){const teal=Color(0xFF1F5A59),lime=Color(0xFFDDFB8A);final s=size.w;return SizedBox(width:s,height:s,child:Stack(children:[Positioned(left:s*.23,top:s*.08,child:Container(width:s*.26,height:s*.72,decoration:BoxDecoration(color:teal,borderRadius:BorderRadius.circular(s*.17)))),Positioned(right:s*.08,bottom:s*.08,child:Container(width:s*.65,height:s*.65,decoration:const BoxDecoration(color:teal,shape:BoxShape.circle))),Positioned(left:s*.30,bottom:s*.19,child:Transform.rotate(angle:-.60,child:Container(width:s*.49,height:s*.29,decoration:BoxDecoration(color:lime,borderRadius:BorderRadius.only(topLeft:Radius.circular(s*.30),bottomRight:Radius.circular(s*.30),topRight:Radius.circular(s*.10),bottomLeft:Radius.circular(s*.10)),border:Border.all(color:Colors.white,width:s*.065))))) ]));}}

class _StatusData{final String label,title,subtitle;final IconData icon;const _StatusData(this.label,this.title,this.subtitle,this.icon);}
