import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spacehere/app.dart';
import 'package:spacehere/features/dashboard/dashboard_screen.dart';
import 'package:spacehere/features/settings/settings_screen.dart';
import 'package:spacehere/features/storage/folder_view_screen.dart';
import 'package:spacehere/services/database/database_service.dart';

void main() {
  setUp(() async {
    await DatabaseService.instance.initialize();
  });

  testWidgets('SpaceHereApp builds and loads root navigation shell', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: SpaceHereApp()));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Dashboard'), findsWidgets);
  });

  testWidgets('DashboardScreen renders metric cards and weaving engine panel', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: DashboardScreen())),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Vault Health'), findsOneWidget);
    expect(find.text('Folders'), findsOneWidget);
    expect(find.text('Files'), findsWidgets);
    expect(find.text('Weaving Engine'), findsOneWidget);
  });

  testWidgets('FolderViewScreen renders files grid and upload fab', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: FolderViewScreen(parentUuid: null)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Upload'), findsOneWidget);
    expect(find.byIcon(Icons.create_new_folder_rounded), findsOneWidget);
  });

  testWidgets('SettingsScreen renders security vault key parameters', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsScreen())),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('AES-256 GCM'), findsOneWidget);
    expect(find.text('100000'), findsOneWidget);
    expect(find.text('Re-initialize Vault'), findsOneWidget);
    expect(find.text('View Raw Contract JSON'), findsOneWidget);
  });

  testWidgets('FolderViewScreen renders search bar and category filter chips', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: FolderViewScreen(parentUuid: null)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.text('All Files'), findsOneWidget);
    expect(find.text('Photos'), findsWidgets);
    expect(find.text('Videos'), findsWidgets);
    expect(find.text('Documents'), findsWidgets);
  });

  testWidgets('DashboardScreen renders Category Bento Cards', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: DashboardScreen())),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Space Categories'), findsOneWidget);
    expect(find.text('Sync With Cloud Vault'), findsOneWidget);
  });
}
