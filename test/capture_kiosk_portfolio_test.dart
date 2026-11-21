import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeropass/models/member.dart';
import 'package:zeropass/models/studio_profile.dart';
import 'package:zeropass/providers/app_providers.dart';
import 'package:zeropass/screens/tablet_kiosk_screen.dart';

class MockKioskMembersNotifier extends MembersNotifier {
  @override
  Future<List<Member>> build() async {
    return [
      Member(
        id: '1',
        name: '강지훈',
        phone: '01099881234',
        groupName: 'PT 화목반',
        billingType: BillingType.sessionBased,
        defaultFee: 340000,
        totalSessions: 12,
        remainingSessions: 1,
        registeredAt: DateTime.now().subtract(const Duration(days: 60)),
        memo: 'D-3 만료 임박 회원',
      ),
      Member(
        id: '2',
        name: '정하율',
        phone: '01012345678',
        groupName: '바이올린 초급',
        billingType: BillingType.sessionBased,
        defaultFee: 280000,
        totalSessions: 10,
        remainingSessions: 8,
        registeredAt: DateTime.now().subtract(const Duration(days: 15)),
        memo: '정상 회원',
      ),
    ];
  }
}

class MockKioskStudioProfileNotifier extends StudioProfileNotifier {
  @override
  Future<StudioProfile> build() async {
    return const StudioProfile(
      studioName: '체크앤페이 스튜디오 & 아카데미',
      instructorName: '이지훈',
      bankName: '카카오뱅크',
      accountNumber: '3333-01-2918231',
      accountHolder: '이지훈 (체크앤페이)',
      category: '피트니스 / PT',
      autoBankDetectEnabled: true,
      invoiceTemplate: '',
      attendanceTemplate: '',
      departureTemplate: '',
      cardPaymentUrl: '',
      cardPaymentEnabled: false,
    );
  }
}

Future<void> loadFonts() async {
  final fontFiles = [
    'assets/fonts/PretendardStd-Regular.ttf',
    'assets/fonts/PretendardStd-Medium.ttf',
    'assets/fonts/PretendardStd-SemiBold.ttf',
    'assets/fonts/PretendardStd-Bold.ttf',
  ];

  final fontLoader = FontLoader('Pretendard');
  for (final path in fontFiles) {
    final bytes = File(path).readAsBytesSync();
    fontLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await fontLoader.load();

  final matFont = File(r'C:\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf');
  if (matFont.existsSync()) {
    final matLoader = FontLoader('MaterialIcons');
    final bytes = matFont.readAsBytesSync();
    matLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
    await matLoader.load();
  }

}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Capture Real Tablet Kiosk Screen for Portfolio Deck', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'language': 'ko'});
    await initializeDateFormatting('ko_KR', null);
    await loadFonts();

    final outDir = Directory(r'd:\097.flutter_project\auto_portfolio\zeropass\assets\kiosk_mockups');
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }

    const tabletSize = Size(680, 960);
    tester.view.physicalSize = tabletSize;
    tester.view.devicePixelRatio = 1.0;

    final key1 = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          membersProvider.overrideWith(() => MockKioskMembersNotifier()),
          studioProfileProvider.overrideWith(() => MockKioskStudioProfileNotifier()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            fontFamily: 'Pretendard',
            brightness: Brightness.dark,
          ),
          home: RepaintBoundary(
            key: key1,
            child: const TabletKioskScreen(isTestMode: false),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Enter 1, 2, 3 -> Live Dialing State
    final key1Btn = find.text('1').first;
    final key2Btn = find.text('2').first;
    final key3Btn = find.text('3').first;
    await tester.tap(key1Btn);
    await tester.pump();
    await tester.tap(key2Btn);
    await tester.pump();
    await tester.tap(key3Btn);
    await tester.pumpAndSettle();

    final screenshot1 = await tester.runAsync(() async {
      final boundary = key1.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    });

    if (screenshot1 != null) {
      final path1 = r'd:\097.flutter_project\auto_portfolio\zeropass\assets\kiosk_mockups\real_tablet_kiosk_dial.png';
      File(path1).writeAsBytesSync(screenshot1);
      print('Saved Kiosk Dial Screen: $path1');
    }

    // 2. Tap '4' -> Triggers Member 1234 Match Success!
    final key4Btn = find.text('4').first;
    await tester.tap(key4Btn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    final screenshot2 = await tester.runAsync(() async {
      final boundary = key1.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    });

    if (screenshot2 != null) {
      final path2 = r'd:\097.flutter_project\auto_portfolio\zeropass\assets\kiosk_mockups\real_tablet_kiosk_success.png';
      File(path2).writeAsBytesSync(screenshot2);
      print('Saved Kiosk Success Screen: $path2');
    }
  });
}
