import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/database/database_service.dart';
import 'services/network/tdlib_telegram_driver.dart';
import 'services/network/telegram_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await DatabaseService.instance.initialize();

  // On native Android / Linux platforms, bind the live TDLib TelegramDriver
  if (!kIsWeb &&
      (Platform.isAndroid || Platform.isLinux || Platform.isWindows)) {
    try {
      TelegramService.instance.setDriver(TdLibTelegramDriver());
    } catch (_) {
      // Fallback gracefully to SimulatedTelegramDriver if native library loading fails
    }
  }

  await TelegramService.instance.initialize();

  runApp(const ProviderScope(child: SpaceHereApp()));
}
