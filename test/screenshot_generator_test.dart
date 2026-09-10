import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeropass/screens/pass_dashboard_screen.dart';
import 'package:zeropass/screens/billing_ledger_screen.dart';
import 'package:zeropass/screens/member_directory_screen.dart';
import 'package:zeropass/screens/settings_vault_screen.dart';
import 'package:zeropass/theme/app_theme.dart';

Future<void> captureScreen({
  required WidgetTester tester,
  required Widget widget,
  required Size size,
  required String outputName,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;

  final repaintKey = GlobalKey();

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: RepaintBoundary(
          key: repaintKey,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: widget,
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();

  final boundary = repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final pngBytes = byteData!.buffer.asUint8List();

  final file = File(outputName);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(pngBytes);
  // ignore: avoid_print
  print('Saved $outputName (${size.width.toInt()}x${size.height.toInt()})');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Capture Real App Screens for Google Play Console', (WidgetTester tester) async {
    // 1. Phone (1080 x 1920)
    final phoneSize = const Size(1080, 1920);
    await captureScreen(
      tester: tester,
      widget: const PassDashboardScreen(),
      size: phoneSize,
      outputName: 'assets/store/phone/screen_1_pass_dashboard.png',
    );
    await captureScreen(
      tester: tester,
      widget: const BillingLedgerScreen(),
      size: phoneSize,
      outputName: 'assets/store/phone/screen_2_billing_ledger.png',
    );
    await captureScreen(
      tester: tester,
      widget: const MemberDirectoryScreen(),
      size: phoneSize,
      outputName: 'assets/store/phone/screen_3_member_directory.png',
    );
    await captureScreen(
      tester: tester,
      widget: const SettingsVaultScreen(),
      size: phoneSize,
      outputName: 'assets/store/phone/screen_4_settings_vault.png',
    );

    // 2. 7-inch Tablet (1200 x 1920)
    final tablet7Size = const Size(1200, 1920);
    await captureScreen(
      tester: tester,
      widget: const PassDashboardScreen(),
      size: tablet7Size,
      outputName: 'assets/store/tablet_7/screen_1_pass_dashboard.png',
    );
    await captureScreen(
      tester: tester,
      widget: const BillingLedgerScreen(),
      size: tablet7Size,
      outputName: 'assets/store/tablet_7/screen_2_billing_ledger.png',
    );
    await captureScreen(
      tester: tester,
      widget: const MemberDirectoryScreen(),
      size: tablet7Size,
      outputName: 'assets/store/tablet_7/screen_3_member_directory.png',
    );
    await captureScreen(
      tester: tester,
      widget: const SettingsVaultScreen(),
      size: tablet7Size,
      outputName: 'assets/store/tablet_7/screen_4_settings_vault.png',
    );

    // 3. 10-inch Tablet (1600 x 2560)
    final tablet10Size = const Size(1600, 2560);
    await captureScreen(
      tester: tester,
      widget: const PassDashboardScreen(),
      size: tablet10Size,
      outputName: 'assets/store/tablet_10/screen_1_pass_dashboard.png',
    );
    await captureScreen(
      tester: tester,
      widget: const BillingLedgerScreen(),
      size: tablet10Size,
      outputName: 'assets/store/tablet_10/screen_2_billing_ledger.png',
    );
    await captureScreen(
      tester: tester,
      widget: const MemberDirectoryScreen(),
      size: tablet10Size,
      outputName: 'assets/store/tablet_10/screen_3_member_directory.png',
    );
    await captureScreen(
      tester: tester,
      widget: const SettingsVaultScreen(),
      size: tablet10Size,
      outputName: 'assets/store/tablet_10/screen_4_settings_vault.png',
    );
  });
}
