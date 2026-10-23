import 'package:bringo_driver/app.dart';
import 'package:bringo_driver/firebase_options.dart';
import 'package:bringo_driver/services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await GetStorage.init();

  await NotificationService.instance.initialize();

  runApp(const DriverApp());
}
