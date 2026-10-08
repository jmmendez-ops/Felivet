import 'package:flutter/material.dart';

import 'app/app.dart';
import 'services/reminder_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ReminderService.initialize();
  runApp(const FeliVetApp());
}
