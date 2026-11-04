import 'package:bringo_driver/core/session/driver_session.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';

/// Manual top-up requests never credit a wallet directly.
/// The pending request must be verified and settled by a trusted backend.
class DriverWalletTopUpPanel extends StatefulWidget {
  const DriverWalletTopUpPanel({super.key});

  @override
  State<DriverWalletTopUpPanel> createState() => _DriverWalletTopUpPanelState();
}

class _DriverWalletTopUpPanelState extends State<DriverWalletTopUpPanel> {
  static const transferNumber = '01115057318';
  static const dark = Color(0xFF174746);
  static const green = Color(0xFF1F5A59);

  final amount = TextEditingController(text: '100');
  final senderPhone = TextEditingController();
  final reference = TextEditingController();
  bool submitting = false;
  String? receiptImage;
  bool picking = false;

  Future<void> pickReceipt() async {
    setState(() => picking = true);
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 45, maxWidth: 900);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.length > 350000) { message('الصورة كبيرة، اختار صورة أصغر'); return; }
      if (mounted) setState(() => receiptImage = base64Encode(bytes));
    } catch (_) { message('تعذر اختيار صورة التحويل'); }
    finally { if (mounted) setState(() => picking = false); }
  }

  @override
  void dispose() {
    amount.dispose();
    senderPhone.dispose();
    reference.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final id = DriverSession.driverId;
    final value = double.tryParse(amount.text.trim());
    final phone = senderPhone.text.replaceAll(RegExp(r'[^0-9]'), '');
    final refNumber = reference.text.trim();

    if (id == null || id.isEmpty) return;
    if (value == null || value < 100 || value > 10000 ||
        ((value * 100) - (value * 100).round()).abs() > 0.001) {
      message('أقل مبلغ للشحن 100 جنيه، وأقصى مبلغ 10000 جنيه.');
      return;
    }
    if (phone.length != 11 || !phone.startsWith('01')) {
      message('اكتب رقم المحفظة اللي حولت منها بشكل صحيح.');
      return;
    }
    if (refNumber.length < 5 || refNumber.length > 80) {
      message('اكتب رقم العملية الموجود في رسالة التحويل.');
      return;
    }

    if (receiptImage == null) { message('ارفع صورة إيصال التحويل الأول'); return; }
    setState(() => submitting = true);
    try {
      final node = FirebaseDatabase.instance.ref('walletTopUpRequests').push();
      await node.set({
        'id': node.key,
        'driverId': id,
        'driverName': DriverSession.driverName ?? '',
        'driverPhone': DriverSession.driverPhone ?? '',
        'amountCents': (value * 100).round(),
        'senderPhone': phone,
        'transferReference': refNumber,
        'receiptImageBase64': receiptImage,
        'status': 'pending',
        'createdAt': ServerValue.timestamp,
      });
      if (!mounted) return;
      amount.text = '100';
      senderPhone.clear();
      reference.clear();
      receiptImage = null;
      message('تم إرسال طلب الشحن للمراجعة. الرصيد لن يزيد إلا بعد تأكيد الإدارة.');
    } catch (_) {
      if (mounted) message('تعذر إرسال الطلب. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  void message(String content) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(content, textDirection: TextDirection.rtl)),
    );
  }

  Widget field(String title, TextEditingController controller,
      {TextInputType inputType = TextInputType.text}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      keyboardType: inputType,
      textDirection: TextDirection.ltr,
      decoration: InputDecoration(
        labelText: title,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final id = DriverSession.driverId ?? '';
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE1EAE6)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (id.isNotEmpty) ...[
              StreamBuilder<DatabaseEvent>(
                stream: FirebaseDatabase.instance.ref('driverWallets/$id').onValue,
                builder: (context, snapshot) {
                  final raw = snapshot.data?.snapshot.value;
                  final wallet = raw is Map ? raw : <dynamic,dynamic>{};
                  final cents = (wallet['balanceCents'] as num?)?.toInt() ?? 0;
                  final active = wallet['activated'] == true;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 18),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: dark,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('الرصيد المتاح',style: TextStyle(color:Color(0xFFD6E6E0),fontSize:13)),
                        const SizedBox(height: 6),
                        Text('${(cents/100).toStringAsFixed(2)} جنيه',
                            style: const TextStyle(color:Colors.white,fontSize:27,fontWeight:FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(active ? 'المحفظة مفعّلة' : 'يلزم شحن 100 جنيه وتأكيد الإدارة لتفعيل المحفظة',
                          style: const TextStyle(color:Color(0xFFDDFB8A),fontSize:12)),
                      ],
                    ),
                  );
                },
              ),
              StreamBuilder<DatabaseEvent>(
                stream: FirebaseDatabase.instance.ref('driverWalletLedger/$id')
                    .limitToLast(8).onValue,
                builder: (context,snapshot) {
                  final raw = snapshot.data?.snapshot.value;
                  if (raw is! Map || raw.isEmpty) return const SizedBox.shrink();
                  final items = raw.values.whereType<Map>().toList()
                    ..sort((a,b) => (int.tryParse(b['createdAt'].toString()) ?? 0)
                        .compareTo(int.tryParse(a['createdAt'].toString()) ?? 0));
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('آخر حركات الرصيد',style:TextStyle(fontWeight:FontWeight.bold,fontSize:15,color:dark)),
                      ...items.map((entry) {
                        final amount = (entry['amountCents'] as num?)?.toInt() ?? 0;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(amount >= 0 ? Icons.south_west : Icons.north_east,
                            color:amount >= 0 ? green : Colors.deepOrange),
                          title: Text(entry['type']=='topup'?'شحن معتمد':'عمولة توصيل'),
                          trailing: Text('${amount>=0?'+':''}${(amount/100).toStringAsFixed(2)} ج',
                            style:TextStyle(fontWeight:FontWeight.bold,color:amount>=0?green:Colors.deepOrange)),
                        );
                      }),
                      const Divider(),
                    ],
                  );
                },
              ),
            ],
            const Text('شحن رصيد المحفظة',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: dark)),
            const SizedBox(height: 8),
            const Text('حوّل المبلغ إلى محفظة Bringo، ثم ابعت رقم العملية للمراجعة. لن تتم إضافة الرصيد قبل التأكد من وصول التحويل.'),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(const ClipboardData(text: transferNumber));
                if (context.mounted) message('تم نسخ رقم التحويل');
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('01115057318   نسخ رقم التحويل'),
            ),
            const SizedBox(height: 10),
            field('مبلغ الشحن بالجنيه (100 فأكثر)', amount, inputType: const TextInputType.numberWithOptions(decimal: true)),
            field('رقم المحفظة المرسِل منها', senderPhone, inputType: TextInputType.phone),
            field('رقم العملية / مرجع التحويل', reference),
            OutlinedButton.icon(
              onPressed: picking || submitting ? null : pickReceipt,
              icon: Icon(receiptImage == null ? Icons.add_photo_alternate_outlined : Icons.check_circle_outline),
              label: Text(receiptImage == null ? 'إرفاق صورة التحويل' : 'تم إرفاق صورة التحويل'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: green),
              onPressed: submitting ? null : submit,
              child: Text(submitting ? 'جاري إرسال الطلب...' : 'إرسال طلب الشحن'),
            ),
            const SizedBox(height: 20),
            const Text('طلبات الشحن السابقة',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: dark)),
            const SizedBox(height: 8),
            if (id.isNotEmpty)
              StreamBuilder<DatabaseEvent>(
                stream: FirebaseDatabase.instance.ref('walletTopUpRequests')
                    .orderByChild('driverId').equalTo(id).limitToLast(20).onValue,
                builder: (context, snapshot) {
                  if (snapshot.hasError) return const Text('تعذر تحميل طلبات الشحن.');
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  final raw = snapshot.data?.snapshot.value;
                  if (raw is! Map) return const Text('لسه مفيش طلبات شحن.');
                  final records = raw.values.whereType<Map>().toList()
                    ..sort((a, b) => (int.tryParse(b['createdAt'].toString()) ?? 0)
                        .compareTo(int.tryParse(a['createdAt'].toString()) ?? 0));
                  return Column(children: records.map((r) {
                    final s = r['status']?.toString() ?? 'pending';
                    final label = s == 'approved' ? 'تمت الموافقة' :
                        s == 'rejected' ? 'مرفوض' : 'قيد المراجعة';
                    final cents = (r['amountCents'] as num?)?.toInt() ?? 0;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('${(cents / 100).toStringAsFixed(2)} جنيه'),
                      subtitle: Text(label),
                      trailing: Icon(s == 'approved' ? Icons.check_circle :
                          s == 'rejected' ? Icons.cancel_outlined : Icons.schedule,
                          color: s == 'approved' ? green : Colors.grey),
                    );
                  }).toList());
                },
              ),
          ],
        ),
      ),
    );
  }
}
