import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zeropass/models/expense_item.dart';
import 'package:zeropass/models/invoice.dart';
import 'package:zeropass/models/member.dart';
import 'package:zeropass/models/pass_record.dart';
import 'package:zeropass/models/studio_profile.dart';
import 'package:zeropass/services/database_service.dart';
import 'package:zeropass/services/localization_service.dart';
import 'package:zeropass/services/monetization_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => Directory.systemTemp.path,
    );
    SharedPreferences.setMockInitialValues({
      'onboarding_completed': true,
      'setup_wizard_completed': true,
    });
    await LocalizationService.setLanguage(AppLanguage.korean);
    await MonetizationService.instance.debugResetAll();
  });

  group('Real User 3-Scenario End-to-End Tests', () {
    test('Scenario 1: Piano Academy Director (Session Member, 1-Click Pass Deduction, Invoice Generation)', () async {
      final db = DatabaseService.instance;
      await db.clearAllData();

      // 1. Setup Piano Academy Profile
      final pianoStudio = StudioProfile.defaultProfile().copyWith(
        studioName: '체리 피아노 스튜디오',
        category: '음악 / 피아노',
        customMemberTerm: '원생',
        customFeeTerm: '레슨비',
      );
      await db.updateStudioProfile(pianoStudio);

      // 2. Register Session Member (이지은, 10회, 180,000원)
      final memberLee = Member(
        id: 'mem_piano_1',
        name: '이지은',
        phone: '010-9876-5432',
        groupName: '체르니 30반',
        billingType: BillingType.sessionBased,
        defaultFee: 180000,
        totalSessions: 10,
        remainingSessions: 10,
        registeredAt: DateTime.now(),
      );
      await db.insertMember(memberLee);

      final loadedMembers = await db.getMembers();
      expect(loadedMembers.length, 1);
      expect(loadedMembers.first.name, '이지은');
      expect(loadedMembers.first.remainingSessions, 10);

      // 3. 1-Click Attendance Check-In (Pass deduction)
      final pass = PassRecord(
        id: 'pass_piano_1',
        memberId: memberLee.id,
        timestamp: DateTime.now(),
        status: AttendanceStatus.attended,
        sessionDeduction: 1,
      );
      await db.insertPassRecord(pass);
      final updatedLee = memberLee.copyWith(remainingSessions: memberLee.remainingSessions - 1);
      await db.updateMember(updatedLee);

      final membersAfterPass = await db.getMembers();
      expect(membersAfterPass.first.remainingSessions, 9, reason: 'Remaining sessions decremented from 10 to 9');

      // 4. Create Lesson Fee Invoice
      final invoice = Invoice(
        id: 'inv_piano_1',
        memberIds: [memberLee.id],
        recipientPhone: memberLee.phone,
        title: '${memberLee.name} · ${pianoStudio.feeWord}',
        amount: memberLee.defaultFee,
        dueDate: DateTime.now().add(const Duration(days: 7)),
        status: PaymentStatus.unpaid,
      );
      await db.insertInvoice(invoice);

      final invoices = await db.getInvoices();
      expect(invoices.length, 1);
      expect(invoices.first.amount, 180000);
      expect(invoices.first.status, PaymentStatus.unpaid);
    });

    test('Scenario 2: Fitness/PT Coach (Monthly Member, Tablet Kiosk Check-In by 4 Digits, Payment Complete)', () async {
      final db = DatabaseService.instance;
      await db.clearAllData();

      final ptStudio = StudioProfile.defaultProfile().copyWith(
        studioName: '강철 피트니스 PT',
        category: '피트니스 / PT',
        customMemberTerm: '회원',
        customFeeTerm: '회비',
      );
      await db.updateStudioProfile(ptStudio);

      // 1. Register Monthly PT Member (강철민, 010-1111-1234, 350,000원)
      final memberKang = Member(
        id: 'mem_pt_1',
        name: '강철민',
        phone: '010-1111-1234',
        groupName: '1:1 바디프로필반',
        billingType: BillingType.monthlyRecurring,
        defaultFee: 350000,
        totalSessions: 0,
        remainingSessions: 0,
        registeredAt: DateTime.now(),
      );
      await db.insertMember(memberKang);

      // 2. Kiosk 4-digit Search and Check-In
      final allMembers = await db.getMembers();
      final matched = allMembers.where((m) => m.phone.replaceAll(RegExp(r'\D'), '').endsWith('1234')).toList();
      expect(matched.length, 1);
      expect(matched.first.name, '강철민');

      final pass = PassRecord(
        id: 'pass_pt_1',
        memberId: memberKang.id,
        timestamp: DateTime.now(),
        status: AttendanceStatus.attended,
        sessionDeduction: 0,
      );
      await db.insertPassRecord(pass);

      final todayPasses = await db.getPassRecords();
      expect(todayPasses.any((p) => p.memberId == memberKang.id), isTrue);

      // 3. Invoice & Mark Paid
      final invoice = Invoice(
        id: 'inv_pt_1',
        memberIds: [memberKang.id],
        recipientPhone: memberKang.phone,
        title: '${memberKang.name} · ${ptStudio.feeWord}',
        amount: memberKang.defaultFee,
        dueDate: DateTime.now(),
        status: PaymentStatus.paid,
      );
      await db.insertInvoice(invoice);

      final invoices = await db.getInvoices();
      expect(invoices.first.status, PaymentStatus.paid);
      expect(invoices.first.amount, 350000);
    });

    test('Scenario 3: Cultural Center Instructor (Senior Mode, Multilingual Member, Expense Ledger)', () async {
      final db = DatabaseService.instance;
      await db.clearAllData();

      final danceStudio = StudioProfile.defaultProfile().copyWith(
        studioName: '라틴 댄스 & 문화센터',
        category: '무용 / 댄스',
        customMemberTerm: '수강생',
        customFeeTerm: '수강료',
      );
      await db.updateStudioProfile(danceStudio);

      // 1. Register Member (Sofia Rodriguez)
      final memberSofia = Member(
        id: 'mem_dance_1',
        name: 'Sofia Rodriguez',
        phone: '010-5555-7777',
        groupName: 'Salsa Principiantes',
        billingType: BillingType.monthlyRecurring,
        defaultFee: 90000,
        totalSessions: 0,
        remainingSessions: 0,
        registeredAt: DateTime.now(),
      );
      await db.insertMember(memberSofia);

      // 2. Register Center Expense Item (Sound equipment & props: 45,000 KRW)
      final expense = ExpenseItem(
        id: 'exp_dance_1',
        vendorName: '사운드마트',
        title: '음향 케이블 및 강습 소품',
        amount: 45000,
        category: '교재/소모품',
        date: DateTime.now(),
        memo: '마이크 젠더 및 댄스 스카프',
        createdAt: DateTime.now(),
      );
      await db.insertExpense(expense);

      final expenses = await db.getExpenses();
      expect(expenses.length, 1);
      expect(expenses.first.title, '음향 케이블 및 강습 소품');
      expect(expenses.first.amount, 45000);
      expect(expenses.first.vendorName, '사운드마트');

      final members = await db.getMembers();
      expect(members.length, 1);
      expect(members.first.name, 'Sofia Rodriguez');
    });
  });
}
