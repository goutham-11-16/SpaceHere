import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/theme/space_theme.dart';

class SpaceHereApp extends ConsumerWidget {
  const SpaceHereApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'SpaceHere',
      debugShowCheckedModeBanner: false,
      theme: SpaceTheme.dark(),
      routerConfig: router,
    );
  }
}
