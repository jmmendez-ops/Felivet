import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/app_state.dart';
import 'services/reminder_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadDarkMode();
  await ReminderService.initialize();
  runApp(const FeliVetApp());
}
