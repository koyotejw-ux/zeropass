import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import '../models/member.dart';
import '../models/pass_record.dart';
import '../models/invoice.dart';
import '../models/studio_profile.dart';
import '../models/vendor.dart';
import '../models/expense_item.dart';
import '../models/notification_log.dart';
import '../models/custom_category_template.dart';
import 'localization_service.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  DatabaseService._internal();

  Database? _database;

  @visibleForTesting
  static String? testDatabasePath;

  @visibleForTesting
  Future<void> resetForTesting() async {
    await _database?.close();
    _database = null;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // FFI initialization for desktop/testing support
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final String path;
    if (testDatabasePath != null) {
      path = testDatabasePath!;
    } else {
      final dbPath = await getDatabasesPath();
      path = p.join(dbPath, 'zeropass_local_vault.db');
    }

    return await openDatabase(
      path,
      version: 10,
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE members ADD COLUMN payerName TEXT');
          } catch (_) {}
        }
        if (oldVersion < 3) {
          try {
            await db.execute('ALTER TABLE studio_profile ADD COLUMN category TEXT DEFAULT "음악 / 피아노"');
          } catch (_) {}
        }
        if (oldVersion < 4) {
          try {
            await db.execute('ALTER TABLE members ADD COLUMN photoPath TEXT');
          } catch (_) {}
        }
        if (oldVersion < 5) {
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS vendors (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                category TEXT NOT NULL,
                bankName TEXT,
                accountNumber TEXT,
                accountHolder TEXT,
                phone TEXT,
                memo TEXT,
                createdAt TEXT NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE IF NOT EXISTS expense_items (
                id TEXT PRIMARY KEY,
                vendorId TEXT,
                vendorName TEXT NOT NULL,
                title TEXT NOT NULL,
                amount INTEGER NOT NULL,
                date TEXT NOT NULL,
                category TEXT NOT NULL,
                paymentMethod TEXT NOT NULL,
                isPaid INTEGER NOT NULL DEFAULT 1,
                memo TEXT,
                createdAt TEXT NOT NULL
              )
            ''');
            await _seedDefaultVendorsAndExpenses(db);
          } catch (_) {}
        }
        if (oldVersion < 6) {
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS notification_logs (
                id TEXT PRIMARY KEY,
                type TEXT NOT NULL,
                memberId TEXT,
                memberName TEXT NOT NULL,
                recipientPhone TEXT NOT NULL,
                channel TEXT NOT NULL,
                message TEXT NOT NULL,
                sentAt TEXT NOT NULL,
                isSuccess INTEGER NOT NULL DEFAULT 1
              )
            ''');
          } catch (_) {}
        }
        if (oldVersion < 7) {
          try {
            await db.execute('ALTER TABLE studio_profile ADD COLUMN cardPaymentUrl TEXT DEFAULT ""');
            await db.execute('ALTER TABLE studio_profile ADD COLUMN cardPaymentEnabled INTEGER NOT NULL DEFAULT 0');
          } catch (_) {}
        }
        if (oldVersion < 8) {
          try {
            await db.execute('ALTER TABLE studio_profile ADD COLUMN logoPath TEXT');
            await db.execute('ALTER TABLE expense_items ADD COLUMN taxEvidence TEXT DEFAULT "기타/통장증빙"');
            await db.execute('ALTER TABLE expense_items ADD COLUMN isWithholdingApplied INTEGER NOT NULL DEFAULT 0');
            await db.execute('ALTER TABLE expense_items ADD COLUMN withholdingTax INTEGER NOT NULL DEFAULT 0');
          } catch (_) {}
        }
        if (oldVersion < 9) {
          try {
            await db.execute('ALTER TABLE studio_profile ADD COLUMN customMemberTerm TEXT');
            await db.execute('ALTER TABLE studio_profile ADD COLUMN customFeeTerm TEXT');
          } catch (_) {}
        }
        if (oldVersion < 10) {
          try {
            await db.execute('ALTER TABLE studio_profile ADD COLUMN customRoleTerm TEXT');
            await db.execute('ALTER TABLE studio_profile ADD COLUMN customPlaceTerm TEXT');
          } catch (_) {}
        }
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Members Table
    await db.execute('''
      CREATE TABLE members (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        groupName TEXT NOT NULL,
        billingType TEXT NOT NULL,
        defaultFee INTEGER NOT NULL,
        totalSessions INTEGER NOT NULL,
        remainingSessions INTEGER NOT NULL,
        memo TEXT,
        payerName TEXT,
        registeredAt TEXT NOT NULL,
        photoPath TEXT
      )
    ''');

    // 2. Pass Records Table
    await db.execute('''
      CREATE TABLE pass_records (
        id TEXT PRIMARY KEY,
        memberId TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        status TEXT NOT NULL,
        sessionDeduction INTEGER,
        FOREIGN KEY (memberId) REFERENCES members (id) ON DELETE CASCADE
      )
    ''');

    // 3. Invoices Table
    await db.execute('''
      CREATE TABLE invoices (
        id TEXT PRIMARY KEY,
        memberIds TEXT NOT NULL,
        recipientPhone TEXT NOT NULL,
        title TEXT NOT NULL,
        amount INTEGER NOT NULL,
        dueDate TEXT NOT NULL,
        status TEXT NOT NULL,
        paymentMethod TEXT,
        paidAt TEXT,
        externalOrderId TEXT
      )
    ''');

    // 4. Studio Profile Table
    await db.execute('''
      CREATE TABLE studio_profile (
        id INTEGER PRIMARY KEY DEFAULT 1,
        studioName TEXT NOT NULL,
        instructorName TEXT NOT NULL,
        bankName TEXT NOT NULL,
        accountNumber TEXT NOT NULL,
        accountHolder TEXT NOT NULL,
        category TEXT DEFAULT "음악 / 피아노",
        autoBankDetectEnabled INTEGER NOT NULL DEFAULT 1,
        invoiceTemplate TEXT,
        attendanceTemplate TEXT,
        departureTemplate TEXT,
        cardPaymentUrl TEXT DEFAULT "",
        cardPaymentEnabled INTEGER NOT NULL DEFAULT 0,
        logoPath TEXT,
        customMemberTerm TEXT,
        customFeeTerm TEXT,
        customRoleTerm TEXT,
        customPlaceTerm TEXT
      )
    ''');

    // 5. Vendors Table (체크인 페이 거래처 장부)
    await db.execute('''
      CREATE TABLE vendors (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        bankName TEXT,
        accountNumber TEXT,
        accountHolder TEXT,
        phone TEXT,
        memo TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    // 6. Expense Items Table (체크인 페이 지출/매입 장부)
    await db.execute('''
      CREATE TABLE expense_items (
        id TEXT PRIMARY KEY,
        vendorId TEXT,
        vendorName TEXT NOT NULL,
        title TEXT NOT NULL,
        amount INTEGER NOT NULL,
        date TEXT NOT NULL,
        category TEXT NOT NULL,
        paymentMethod TEXT NOT NULL,
        isPaid INTEGER NOT NULL DEFAULT 1,
        memo TEXT,
        createdAt TEXT NOT NULL,
        taxEvidence TEXT DEFAULT "기타/통장증빙",
        isWithholdingApplied INTEGER NOT NULL DEFAULT 0,
        withholdingTax INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 7. Notification Logs Table
    await db.execute('''
      CREATE TABLE notification_logs (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        memberId TEXT,
        memberName TEXT NOT NULL,
        recipientPhone TEXT NOT NULL,
        channel TEXT NOT NULL,
        message TEXT NOT NULL,
        sentAt TEXT NOT NULL,
        isSuccess INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Insert Default Studio Profile
    final defaultProfile = StudioProfile.defaultProfile();
    await db.insert('studio_profile', defaultProfile.toMap());

    // Insert Rich Realistic Mock Data (5 Multi-industry members)
    await _seedMockData(db);
    await _seedDefaultVendorsAndExpenses(db);
  }

  Future<void> _seedMockData(Database db) async {
    final now = DateTime.now();
    final lang = LocalizationService.currentLanguage;
    final cur = LocalizationService.currentCurrency;
    final useKoreanDefault = lang == AppLanguage.korean && cur == AppCurrency.krw;

    int amt(int krw) => CustomCategoryState.scaleAmount(krw, cur);

    final members = useKoreanDefault
        ? [
            Member(
              id: 'mem_1',
              name: '이도현 (중2 수학반)',
              phone: '01055219012',
              groupName: '중등수학 정규반',
              billingType: BillingType.monthlyRecurring,
              defaultFee: 320000,
              totalSessions: 0,
              remainingSessions: 0,
              memo: '학부모 요청: 수요일 7시 오답노트 점검 요망',
              registeredAt: now.subtract(const Duration(days: 60)),
            ),
            Member(
              id: 'mem_2',
              name: '박민지 (1:1 필라테스)',
              phone: '01033418872',
              groupName: '기구 필라테스',
              billingType: BillingType.sessionBased,
              defaultFee: 700000,
              totalSessions: 10,
              remainingSessions: 2, // 만료 임박
              memo: '체형교정 및 라운드숄더 집중 케어',
              registeredAt: now.subtract(const Duration(days: 45)),
            ),
            Member(
              id: 'mem_3',
              name: '정하율 (바이올린 초급)',
              phone: '01099881234',
              groupName: '바이올린 주말반',
              billingType: BillingType.monthlyRecurring,
              defaultFee: 180000,
              totalSessions: 0,
              remainingSessions: 0,
              memo: '자매 동시 수강 (하린 학생과 함께 수강)',
              payerName: '이영희',
              registeredAt: now.subtract(const Duration(days: 90)),
            ),
            Member(
              id: 'mem_4',
              name: '정하린 (체르니 피아노)',
              phone: '01099881234', // Sibling with mem_3!
              groupName: '피아노 클래식반',
              billingType: BillingType.monthlyRecurring,
              defaultFee: 160000,
              totalSessions: 0,
              remainingSessions: 0,
              memo: '형제 묶음 청구 대상 (어머니 연락처 일치)',
              payerName: '이영희',
              registeredAt: now.subtract(const Duration(days: 90)),
            ),
            Member(
              id: 'mem_5',
              name: '강지훈 (바디프로필 PT)',
              phone: '01077654321',
              groupName: 'PT 화목반',
              billingType: BillingType.sessionBased,
              defaultFee: 880000,
              totalSessions: 12,
              remainingSessions: 1, // 만료 임박
              memo: '체지방 감량 목표 4주 코스',
              registeredAt: now.subtract(const Duration(days: 30)),
            ),
            Member(
              id: 'mem_6',
              name: '최예원 (도예 주말 원데이)',
              phone: '01066779911',
              groupName: '도예 주말반',
              billingType: BillingType.sessionBased,
              defaultFee: 240000,
              totalSessions: 4,
              remainingSessions: 4,
              memo: '물레 및 핸드빌딩 4회 패스',
              registeredAt: now.subtract(const Duration(days: 10)),
            ),
          ]
        : [
            Member(
              id: 'mem_1',
              name: LocalizationService.pick(
                ko: '이도현 (중2 수학반)',
                en: 'Ethan Carter (Grade 8 Math)',
                ja: '佐藤 蓮 (中2 数学クラス)',
                zh: '陈子轩 (初二数学常规班)',
                vi: 'Nguyễn Minh Anh (Toán THCS)',
                es: 'Mateo Silva (Matemáticas Sec.)',
              ),
              phone: LocalizationService.pick(
                ko: '01055219012',
                en: '4155550101',
                ja: '09055219012',
                zh: '13800139012',
                vi: '0912559012',
                es: '612559012',
              ),
              groupName: LocalizationService.pick(
                ko: '중등수학 정규반',
                en: 'Middle School Core',
                ja: '中学生定期テスト',
                zh: '初中同步班',
                vi: 'Lớp THCS',
                es: 'Secundaria Base',
              ),
              billingType: BillingType.monthlyRecurring,
              defaultFee: amt(320000),
              totalSessions: 0,
              remainingSessions: 0,
              memo: LocalizationService.pick(
                ko: '학부모 요청: 수요일 7시 오답노트 점검 요망',
                en: 'Parent note: Review error notebook every Wed 7 PM',
                ja: '保護者要望: 水曜19時に復習ノート確認',
                zh: '家长备注: 每周三19:00检查错题本',
                vi: 'Ghi chú phụ huynh: Kiểm tra vở bài tập thứ Tư 19:00',
                es: 'Nota familiar: Revisar cuaderno miércoles 19:00',
              ),
              registeredAt: now.subtract(const Duration(days: 60)),
            ),
            Member(
              id: 'mem_2',
              name: LocalizationService.pick(
                ko: '박민지 (1:1 필라테스)',
                en: 'Sophia Miller (1:1 Pilates)',
                ja: '高橋 美咲 (1:1 ピラティス)',
                zh: '林思涵 (1对1普拉提)',
                vi: 'Trần Thảo Vy (Pilates 1:1)',
                es: 'Lucía Gómez (Pilates 1:1)',
              ),
              phone: LocalizationService.pick(
                ko: '01033418872',
                en: '4155550102',
                ja: '09033418872',
                zh: '13800138872',
                vi: '0913348872',
                es: '613348872',
              ),
              groupName: LocalizationService.pick(
                ko: '기구 필라테스',
                en: 'Private Reformer Pilates',
                ja: 'マシンピラティス',
                zh: '器械普拉提',
                vi: 'Pilates Máy 1:1',
                es: 'Pilates Reformer',
              ),
              billingType: BillingType.sessionBased,
              defaultFee: amt(700000),
              totalSessions: 10,
              remainingSessions: 2,
              memo: LocalizationService.pick(
                ko: '체형교정 및 라운드숄더 집중 케어',
                en: 'Posture alignment & upper-back mobility focus',
                ja: '姿勢改善・巻き肩集中ケア',
                zh: '体态矫正与圆肩专项护理',
                vi: 'Tập trung chỉnh dáng & vai cổ',
                es: 'Enfoque en corrección postural y hombros',
              ),
              registeredAt: now.subtract(const Duration(days: 45)),
            ),
            Member(
              id: 'mem_3',
              name: LocalizationService.pick(
                ko: '정하율 (바이올린 초급)',
                en: 'Maya Brooks (Violin Beginner)',
                ja: '鈴木 結衣 (バイオリン初級)',
                zh: '周雨桐 (小提琴初级)',
                vi: 'Lê Bảo Ngọc (Violin Cơ bản)',
                es: 'Sofía Ruiz (Violín Inicial)',
              ),
              phone: LocalizationService.pick(
                ko: '01099881234',
                en: '4155550199',
                ja: '09099881234',
                zh: '13800131234',
                vi: '0919981234',
                es: '619981234',
              ),
              groupName: LocalizationService.pick(
                ko: '바이올린 주말반',
                en: 'Weekend Strings Studio',
                ja: '週末バイオリンクラス',
                zh: '周末弦乐班',
                vi: 'Lớp Nhạc cuối tuần',
                es: 'Cuerdas Fin de Semana',
              ),
              billingType: BillingType.monthlyRecurring,
              defaultFee: amt(180000),
              totalSessions: 0,
              remainingSessions: 0,
              memo: LocalizationService.pick(
                ko: '자매 동시 수강 (하린 학생과 함께 수강)',
                en: 'Sibling bundle enrollment (same parent phone)',
                ja: '姉妹同時受講（まとめ請求対象）',
                zh: '姐妹共同报名（关联家庭账单）',
                vi: 'Đăng ký theo cặp chị em (chung SĐT phụ huynh)',
                es: 'Inscripción conjunta de hermanas (mismo contacto)',
              ),
              payerName: LocalizationService.pick(
                ko: '이영희',
                en: 'Claire Brooks',
                ja: '鈴木 恵子',
                zh: '周女士',
                vi: 'Lê Thu Hà',
                es: 'Elena Ruiz',
              ),
              registeredAt: now.subtract(const Duration(days: 90)),
            ),
            Member(
              id: 'mem_4',
              name: LocalizationService.pick(
                ko: '정하린 (체르니 피아노)',
                en: 'Chloe Brooks (Piano Classic)',
                ja: '鈴木 陽菜 (ピアノクラシック)',
                zh: '周子晴 (钢琴古典班)',
                vi: 'Lê Bảo Hân (Piano Cổ điển)',
                es: 'Valentina Ruiz (Piano Clásico)',
              ),
              phone: LocalizationService.pick(
                ko: '01099881234',
                en: '4155550199',
                ja: '09099881234',
                zh: '13800131234',
                vi: '0919981234',
                es: '619981234',
              ),
              groupName: LocalizationService.pick(
                ko: '피아노 클래식반',
                en: 'Classical Repertoire',
                ja: 'クラシック専門コース',
                zh: '古典钢琴提高班',
                vi: 'Piano Cổ điển',
                es: 'Repertorio Clásico',
              ),
              billingType: BillingType.monthlyRecurring,
              defaultFee: amt(160000),
              totalSessions: 0,
              remainingSessions: 0,
              memo: LocalizationService.pick(
                ko: '형제 묶음 청구 대상 (어머니 연락처 일치)',
                en: 'Eligible for sibling combined invoice',
                ja: '兄弟姉妹まとめ請求対象',
                zh: '家庭合并账单对象',
                vi: 'Gộp hóa đơn gia đình với chị/em',
                es: 'Facturación conjunta familiar',
              ),
              payerName: LocalizationService.pick(
                ko: '이영희',
                en: 'Claire Brooks',
                ja: '鈴木 恵子',
                zh: '周女士',
                vi: 'Lê Thu Hà',
                es: 'Elena Ruiz',
              ),
              registeredAt: now.subtract(const Duration(days: 90)),
            ),
            Member(
              id: 'mem_5',
              name: LocalizationService.pick(
                ko: '강지훈 (바디프로필 PT)',
                en: 'Liam Kim (1:1 Conditioning PT)',
                ja: '中村 翔太 (ボディメイク PT)',
                zh: '张浩宇 (体能私教课)',
                vi: 'Phạm Quốc Bảo (PT Hình thể)',
                es: 'Carlos Navarro (PT Fuerza)',
              ),
              phone: LocalizationService.pick(
                ko: '01077654321',
                en: '4155550105',
                ja: '09077654321',
                zh: '13800134321',
                vi: '0917764321',
                es: '617764321',
              ),
              groupName: LocalizationService.pick(
                ko: 'PT 화목반',
                en: '1:1 Personal Training',
                ja: '1:1 パーソナルPT',
                zh: '1对1私教课',
                vi: 'PT Cá nhân 1:1',
                es: 'Entrenamiento 1:1',
              ),
              billingType: BillingType.sessionBased,
              defaultFee: amt(880000),
              totalSessions: 12,
              remainingSessions: 1,
              memo: LocalizationService.pick(
                ko: '체지방 감량 목표 4주 코스',
                en: '12-session lean conditioning program',
                ja: '体脂肪減少目標4週間コース',
                zh: '减脂塑形4周专项训练',
                vi: 'Lộ trình giảm mỡ 12 buổi',
                es: 'Programa intensivo 12 sesiones',
              ),
              registeredAt: now.subtract(const Duration(days: 30)),
            ),
            Member(
              id: 'mem_6',
              name: LocalizationService.pick(
                ko: '최예원 (도예 주말 원데이)',
                en: 'Hannah Park (Ceramic Studio)',
                ja: '山本 さくら (陶芸週末コース)',
                zh: '王若溪 (周末陶艺课)',
                vi: 'Đỗ Khánh Linh (Gốm cuối tuần)',
                es: 'Paula Torres (Taller Cerámica)',
              ),
              phone: LocalizationService.pick(
                ko: '01066779911',
                en: '4155550106',
                ja: '09066779911',
                zh: '13800139911',
                vi: '0916679911',
                es: '616679911',
              ),
              groupName: LocalizationService.pick(
                ko: '도예 주말반',
                en: 'Wheel Pottery Studio',
                ja: '陶芸ろくろコース',
                zh: '拉坯陶艺常规班',
                vi: 'Lớp Gốm bàn xoay',
                es: 'Torno y Cerámica',
              ),
              billingType: BillingType.sessionBased,
              defaultFee: amt(240000),
              totalSessions: 4,
              remainingSessions: 4,
              memo: LocalizationService.pick(
                ko: '물레 및 핸드빌딩 4회 패스',
                en: 'Wheel throwing & glazing 4-session pass',
                ja: 'ろくろ・手びねり4回パス',
                zh: '拉坯与手工塑形4次卡',
                vi: 'Gói 4 buổi nặn & xoay gốm',
                es: 'Bono 4 sesiones torno y esmalte',
              ),
              registeredAt: now.subtract(const Duration(days: 10)),
            ),
          ];

    for (final m in members) {
      await db.insert('members', m.toMap());
    }

    // Pass attendance records for today / yesterday
    final passRecords = [
      PassRecord(
        id: 'pass_1',
        memberId: 'mem_1',
        timestamp: now.subtract(const Duration(hours: 3)),
        status: AttendanceStatus.attended,
      ),
      PassRecord(
        id: 'pass_2',
        memberId: 'mem_2',
        timestamp: now.subtract(const Duration(hours: 1)),
        status: AttendanceStatus.attended,
        sessionDeduction: 1,
      ),
      PassRecord(
        id: 'pass_3',
        memberId: 'mem_3',
        timestamp: now.subtract(const Duration(hours: 2)),
        status: AttendanceStatus.late,
      ),
    ];

    for (final p in passRecords) {
      await db.insert('pass_records', p.toMap());
    }

    // Invoices (Unpaid & Paid)
    final invoices = useKoreanDefault
        ? [
            Invoice(
              id: 'inv_1',
              memberIds: ['mem_3', 'mem_4'], // Siblings bundle!
              recipientPhone: '01099881234',
              title: '9월 피아노 수강료 (하율/하린 자매 합산)',
              amount: 340000,
              dueDate: now.add(const Duration(days: 3)),
              status: PaymentStatus.unpaid,
            ),
            Invoice(
              id: 'inv_2',
              memberIds: ['mem_5'],
              recipientPhone: '01077654321',
              title: 'PT 12회 재등록 안내 (잔여 1회 만료임박)',
              amount: 880000,
              dueDate: now.add(const Duration(days: 1)),
              status: PaymentStatus.unpaid,
            ),
            Invoice(
              id: 'inv_3',
              memberIds: ['mem_2'],
              recipientPhone: '01033418872',
              title: '필라테스 10회권 수강료',
              amount: 700000,
              dueDate: now.subtract(const Duration(days: 20)),
              status: PaymentStatus.paid,
              paymentMethod: 'TRANSFER',
              paidAt: now.subtract(const Duration(days: 19)),
            ),
            Invoice(
              id: 'inv_4',
              memberIds: ['mem_1'],
              recipientPhone: '01055219012',
              title: '8월 중등수학 정규반 수업료',
              amount: 320000,
              dueDate: now.subtract(const Duration(days: 35)),
              status: PaymentStatus.paid,
              paymentMethod: 'OFFLINE_CARD',
              paidAt: now.subtract(const Duration(days: 34)),
            ),
          ]
        : [
            Invoice(
              id: 'inv_1',
              memberIds: ['mem_3', 'mem_4'],
              recipientPhone: LocalizationService.pick(
                ko: '01099881234',
                en: '4155550199',
                ja: '09099881234',
                zh: '13800131234',
                vi: '0919981234',
                es: '619981234',
              ),
              title: LocalizationService.pick(
                ko: '9월 피아노 수강료 (하율/하린 자매 합산)',
                en: 'Monthly Music Tuition (Maya & Chloe Bundle)',
                ja: '音楽教室 月謝まとめ請求（結衣・陽菜）',
                zh: '本月音乐课程学费（家庭合并账单）',
                vi: 'Học phí Âm nhạc (Gộp Maya & Chloe)',
                es: 'Mensualidad Música (Pack Hermanas)',
              ),
              amount: amt(340000),
              dueDate: now.add(const Duration(days: 3)),
              status: PaymentStatus.unpaid,
            ),
            Invoice(
              id: 'inv_2',
              memberIds: ['mem_5'],
              recipientPhone: LocalizationService.pick(
                ko: '01077654321',
                en: '4155550105',
                ja: '09077654321',
                zh: '13800134321',
                vi: '0917764321',
                es: '617764321',
              ),
              title: LocalizationService.pick(
                ko: 'PT 12회 재등록 안내 (잔여 1회 만료임박)',
                en: 'PT 12-Session Renewal (1 Left)',
                ja: 'PT 12回更新のご案内（残り1回）',
                zh: '私教12节续费通知（仅剩1节）',
                vi: 'Gia hạn PT 12 buổi (còn 1 buổi)',
                es: 'Renovación Bono 12 PT (Queda 1)',
              ),
              amount: amt(880000),
              dueDate: now.add(const Duration(days: 1)),
              status: PaymentStatus.unpaid,
            ),
            Invoice(
              id: 'inv_3',
              memberIds: ['mem_2'],
              recipientPhone: LocalizationService.pick(
                ko: '01033418872',
                en: '4155550102',
                ja: '09033418872',
                zh: '13800138872',
                vi: '0913348872',
                es: '613348872',
              ),
              title: LocalizationService.pick(
                ko: '필라테스 10회권 수강료',
                en: 'Reformer Pilates 10-Session Pass',
                ja: 'ピラティス10回券レッスン料',
                zh: '普拉提10次卡课程费',
                vi: 'Gói tập Pilates 10 buổi',
                es: 'Bono 10 Clases Pilates',
              ),
              amount: amt(700000),
              dueDate: now.subtract(const Duration(days: 20)),
              status: PaymentStatus.paid,
              paymentMethod: 'TRANSFER',
              paidAt: now.subtract(const Duration(days: 19)),
            ),
            Invoice(
              id: 'inv_4',
              memberIds: ['mem_1'],
              recipientPhone: LocalizationService.pick(
                ko: '01055219012',
                en: '4155550101',
                ja: '09055219012',
                zh: '13800139012',
                vi: '0912559012',
                es: '612559012',
              ),
              title: LocalizationService.pick(
                ko: '8월 중등수학 정규반 수업료',
                en: 'Previous Month Math Core Tuition',
                ja: '先月分 中学数学レギュラー月謝',
                zh: '上月数学常规班学费',
                vi: 'Học phí Toán tháng trước',
                es: 'Cuota Mensual Matemáticas',
              ),
              amount: amt(320000),
              dueDate: now.subtract(const Duration(days: 35)),
              status: PaymentStatus.paid,
              paymentMethod: 'OFFLINE_CARD',
              paidAt: now.subtract(const Duration(days: 34)),
            ),
          ];

    for (final inv in invoices) {
      await db.insert('invoices', inv.toMap());
    }
  }

  // Members CRUD
  Future<List<Member>> getMembers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('members', orderBy: 'name ASC');
    return maps.map((m) => Member.fromMap(m)).toList();
  }

  Future<void> insertMember(Member member) async {
    final db = await database;
    await db.insert('members', member.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateMember(Member member) async {
    final db = await database;
    await db.update('members', member.toMap(), where: 'id = ?', whereArgs: [member.id]);
  }

  Future<void> deleteMember(String id) async {
    final db = await database;
    await db.delete('members', where: 'id = ?', whereArgs: [id]);
    await db.delete('pass_records', where: 'memberId = ?', whereArgs: [id]);
  }

  // Pass Records CRUD
  Future<List<PassRecord>> getPassRecords() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('pass_records', orderBy: 'timestamp DESC');
    return maps.map((m) => PassRecord.fromMap(m)).toList();
  }

  Future<void> insertPassRecord(PassRecord record) async {
    final db = await database;
    await db.insert('pass_records', record.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deletePassRecord(String id) async {
    final db = await database;
    await db.delete('pass_records', where: 'id = ?', whereArgs: [id]);
  }

  // Invoices CRUD
  Future<List<Invoice>> getInvoices() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('invoices', orderBy: 'dueDate DESC');
    return maps.map((m) => Invoice.fromMap(m)).toList();
  }

  Future<void> insertInvoice(Invoice invoice) async {
    final db = await database;
    await db.insert('invoices', invoice.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateInvoice(Invoice invoice) async {
    final db = await database;
    await db.update('invoices', invoice.toMap(), where: 'id = ?', whereArgs: [invoice.id]);
  }

  Future<void> deleteInvoice(String id) async {
    final db = await database;
    await db.delete('invoices', where: 'id = ?', whereArgs: [id]);
  }

  // Studio Profile
  Future<StudioProfile> getStudioProfile() async {
    final db = await database;
    final maps = await db.query('studio_profile', where: 'id = 1');
    if (maps.isNotEmpty) {
      return StudioProfile.fromMap(maps.first);
    }
    return StudioProfile.defaultProfile();
  }

  Future<void> updateStudioProfile(StudioProfile profile) async {
    final db = await database;
    await db.update('studio_profile', profile.toMap(), where: 'id = 1');
  }

  // Vendors CRUD (체크인 페이 거래처)
  Future<List<Vendor>> getVendors() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('vendors', orderBy: 'name ASC');
    return maps.map((m) => Vendor.fromMap(m)).toList();
  }

  Future<void> insertVendor(Vendor vendor) async {
    final db = await database;
    await db.insert('vendors', vendor.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateVendor(Vendor vendor) async {
    final db = await database;
    await db.update('vendors', vendor.toMap(), where: 'id = ?', whereArgs: [vendor.id]);
  }

  Future<void> deleteVendor(String id) async {
    final db = await database;
    await db.delete('vendors', where: 'id = ?', whereArgs: [id]);
  }

  // Expense Items CRUD (체크인 페이 지출/매입)
  Future<List<ExpenseItem>> getExpenses() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('expense_items', orderBy: 'date DESC');
    return maps.map((m) => ExpenseItem.fromMap(m)).toList();
  }

  Future<void> insertExpense(ExpenseItem expense) async {
    final db = await database;
    await db.insert('expense_items', expense.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateExpense(ExpenseItem expense) async {
    final db = await database;
    await db.update('expense_items', expense.toMap(), where: 'id = ?', whereArgs: [expense.id]);
  }

  Future<void> deleteExpense(String id) async {
    final db = await database;
    await db.delete('expense_items', where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================
  // NOTIFICATION LOGS CRUD
  // ==========================================
  Future<List<NotificationLog>> getNotificationLogs({
    String? memberId,
    NotificationType? type,
    int limit = 100,
  }) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;

    if (memberId != null && type != null) {
      where = 'memberId = ? AND type = ?';
      whereArgs = [memberId, type.name];
    } else if (memberId != null) {
      where = 'memberId = ?';
      whereArgs = [memberId];
    } else if (type != null) {
      where = 'type = ?';
      whereArgs = [type.name];
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'notification_logs',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'sentAt DESC',
      limit: limit,
    );
    return maps.map((m) => NotificationLog.fromMap(m)).toList();
  }

  Future<void> insertNotificationLog(NotificationLog log) async {
    final db = await database;
    await db.insert(
      'notification_logs',
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteNotificationLog(String id) async {
    final db = await database;
    await db.delete('notification_logs', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAllNotificationLogs() async {
    final db = await database;
    await db.delete('notification_logs');
  }

  /// Reset all data and clear out mock data for clean real usage
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('pass_records');
    await db.delete('invoices');
    await db.delete('members');
    await db.delete('expense_items');
    await db.delete('vendors');
    await db.delete('notification_logs');
  }

  /// Re-seed sample practice data
  Future<void> restoreSampleData() async {
    final db = await database;
    await clearAllData();
    await _seedMockData(db);
    await _seedDefaultVendorsAndExpenses(db);
  }

  Future<void> _seedDefaultVendorsAndExpenses(Database db) async {
    final now = DateTime.now();
    final lang = LocalizationService.currentLanguage;
    final cur = LocalizationService.currentCurrency;
    final useKoreanDefault = lang == AppLanguage.korean && cur == AppCurrency.krw;
    int amt(int krw) => CustomCategoryState.scaleAmount(krw, cur);

    final vendors = useKoreanDefault
        ? [
            Vendor(
              id: 'vnd_1',
              name: '(주)에듀프라임 교재총판',
              category: '교재/교구',
              bankName: '국민은행',
              accountNumber: '482102-04-192831',
              accountHolder: '김영수(에듀프라임)',
              phone: '010-8821-3912',
              memo: '매월 25일 교재 및 워크북 정기 발주',
              createdAt: now.subtract(const Duration(days: 90)),
            ),
            Vendor(
              id: 'vnd_2',
              name: '피트니스&매트 프로몰',
              category: '시설/기구',
              bankName: '신한은행',
              accountNumber: '110-382-991204',
              accountHolder: '박진우(프로몰)',
              phone: '010-3920-1192',
              memo: '수건 렌탈/세탁 및 기구 소모품 납품처',
              createdAt: now.subtract(const Duration(days: 75)),
            ),
            Vendor(
              id: 'vnd_3',
              name: '센트럴타워 관리사무소',
              category: '임대/관리비',
              bankName: '우리은행',
              accountNumber: '1002-381-002911',
              accountHolder: '센트럴타워운영회',
              phone: '02-581-0192',
              memo: '매월 말일 임대료 및 공용 관리비 납부',
              createdAt: now.subtract(const Duration(days: 120)),
            ),
            Vendor(
              id: 'vnd_4',
              name: '이지원 강사 (파트너)',
              category: '강사/코치료',
              bankName: '카카오뱅크',
              accountNumber: '3333-01-2918231',
              accountHolder: '이지원',
              phone: '010-9281-0012',
              memo: '주말 특강 및 1:1 레슨 파트타임 (인센티브 정산)',
              createdAt: now.subtract(const Duration(days: 40)),
            ),
          ]
        : [
            Vendor(
              id: 'vnd_1',
              name: LocalizationService.pick(
                ko: '(주)에듀프라임 교재총판',
                en: 'EduPrime Books & Kits',
                ja: 'エデュプライム教材社',
                zh: '优学教材教具供应链',
                vi: 'Nhà sách & Học liệu EduPrime',
                es: 'Editorial EduPrime',
              ),
              category: LocalizationService.pick(
                ko: '교재/교구',
                en: 'Books / Supplies',
                ja: '教材・備品',
                zh: '教材 / 教具',
                vi: 'Giáo trình / Học liệu',
                es: 'Libros y Material',
              ),
              bankName: cur.defaultBankName,
              accountNumber: '4821-0419-2831',
              accountHolder: 'EduPrime Supply',
              phone: '415-555-3912',
              memo: LocalizationService.pick(
                ko: '매월 25일 교재 및 워크북 정기 발주',
                en: 'Monthly workbook & study kit order on the 25th',
                ja: '毎月25日に教材定期発注',
                zh: '每月25日定期采购教材',
                vi: 'Đặt giáo trình định kỳ ngày 25',
                es: 'Pedido mensual de libros el día 25',
              ),
              createdAt: now.subtract(const Duration(days: 90)),
            ),
            Vendor(
              id: 'vnd_2',
              name: LocalizationService.pick(
                ko: '피트니스&매트 프로몰',
                en: 'ProStudio Gear & Laundry',
                ja: 'スタジオ用品・リネン社',
                zh: '健身器材与清洁用品商',
                vi: 'Thiết bị & Giặt là ProStudio',
                es: 'Equipos ProStudio',
              ),
              category: LocalizationService.pick(
                ko: '시설/기구',
                en: 'Equipment / Facility',
                ja: '設備・器具',
                zh: '设备 / 耗材',
                vi: 'Thiết bị / Cơ sở',
                es: 'Equipamiento',
              ),
              bankName: cur.defaultBankName,
              accountNumber: '1103-8299-1204',
              accountHolder: 'ProStudio Gear',
              phone: '415-555-1192',
              memo: LocalizationService.pick(
                ko: '수건 렌탈/세탁 및 기구 소모품 납품처',
                en: 'Towel service & studio maintenance consumables',
                ja: 'タオル・消毒用品の定期納品',
                zh: '毛巾清洗及场馆消耗品配送',
                vi: 'Dịch vụ khăn tập & dung dịch vệ sinh',
                es: 'Servicio de toallas y consumibles',
              ),
              createdAt: now.subtract(const Duration(days: 75)),
            ),
            Vendor(
              id: 'vnd_3',
              name: LocalizationService.pick(
                ko: '센트럴타워 관리사무소',
                en: 'Central Plaza Management',
                ja: 'セントラルビル管理',
                zh: '中心大厦物业管理处',
                vi: 'Ban quản lý Central Tower',
                es: 'Administración Central Plaza',
              ),
              category: LocalizationService.pick(
                ko: '임대/관리비',
                en: 'Rent / Utilities',
                ja: '家賃・管理費',
                zh: '房租 / 物业费',
                vi: 'Thuê mặt bằng / Quản lý',
                es: 'Alquiler y Gastos',
              ),
              bankName: cur.defaultBankName,
              accountNumber: '1002-3810-2911',
              accountHolder: 'Central Plaza Mgmt',
              phone: '415-555-0192',
              memo: LocalizationService.pick(
                ko: '매월 말일 임대료 및 공용 관리비 납부',
                en: 'Monthly studio lease and building maintenance',
                ja: '毎月末の家賃・共益費振込',
                zh: '每月底结算房租及物业费',
                vi: 'Thanh toán tiền thuê mặt bằng hàng tháng',
                es: 'Alquiler mensual y mantenimiento',
              ),
              createdAt: now.subtract(const Duration(days: 120)),
            ),
            Vendor(
              id: 'vnd_4',
              name: LocalizationService.pick(
                ko: '이지원 강사 (파트너)',
                en: 'Jordan Lee (Partner Coach)',
                ja: '佐藤 健太 (業務委託講師)',
                zh: '李教练 (合作讲师)',
                vi: 'HLV Minh Tuấn (Cộng tác viên)',
                es: 'Diego Morales (Coach Colaborador)',
              ),
              category: LocalizationService.pick(
                ko: '강사/코치료',
                en: 'Contractor Payout',
                ja: '講師謝礼',
                zh: '讲师课时费',
                vi: 'Thù lao giảng viên',
                es: 'Honorarios Coach',
              ),
              bankName: cur.defaultBankName,
              accountNumber: '3333-0129-1823',
              accountHolder: 'Jordan Lee',
              phone: '415-555-0012',
              memo: LocalizationService.pick(
                ko: '주말 특강 및 1:1 레슨 파트타임 (인센티브 정산)',
                en: 'Weekend classes & 1:1 lesson payout',
                ja: '週末クラス・1:1レッスン報酬精算',
                zh: '周末特色课及一对一课时提成',
                vi: 'Thù lao lớp cuối tuần & dạy 1:1',
                es: 'Liquidación clases de fin de semana',
              ),
              createdAt: now.subtract(const Duration(days: 40)),
            ),
          ];

    for (final v in vendors) {
      await db.insert('vendors', v.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }

    final bankTransferLabel = LocalizationService.pick(
      ko: '계좌이체',
      en: 'Bank Transfer',
      ja: '銀行振込',
      zh: '银行转账',
      vi: 'Chuyển khoản',
      es: 'Transferencia',
    );
    final creditCardLabel = LocalizationService.pick(
      ko: '신용카드',
      en: 'Credit Card',
      ja: 'クレジットカード',
      zh: '信用卡',
      vi: 'Thẻ tín dụng',
      es: 'Tarjeta',
    );

    final expenses = useKoreanDefault
        ? [
            ExpenseItem(
              id: 'exp_1',
              vendorId: 'vnd_1',
              vendorName: '(주)에듀프라임 교재총판',
              title: '5월 학습 교재 및 워크북 30부 발주',
              amount: 280000,
              date: DateTime(now.year, now.month, 5),
              category: '교재비',
              paymentMethod: '계좌이체',
              isPaid: true,
              memo: '택배 수령 완료 및 정상 입금',
              createdAt: now.subtract(const Duration(days: 20)),
            ),
            ExpenseItem(
              id: 'exp_2',
              vendorId: 'vnd_3',
              vendorName: '센트럴타워 관리사무소',
              title: '스튜디오 월세 및 기본 관리비',
              amount: 1200000,
              date: DateTime(now.year, now.month, 1),
              category: '임대료',
              paymentMethod: '계좌이체',
              isPaid: true,
              memo: '월초 정기 이체 완료',
              createdAt: now.subtract(const Duration(days: 25)),
            ),
            ExpenseItem(
              id: 'exp_3',
              vendorId: 'vnd_2',
              vendorName: '피트니스&매트 프로몰',
              title: '친환경 소독제 & 회원용 타올 세탁비',
              amount: 85000,
              date: DateTime(now.year, now.month, 10),
              category: '소모품비',
              paymentMethod: '신용카드',
              isPaid: true,
              memo: '정기 소모품 비용 결제',
              createdAt: now.subtract(const Duration(days: 15)),
            ),
            ExpenseItem(
              id: 'exp_4',
              vendorId: 'vnd_4',
              vendorName: '이지원 강사 (파트너)',
              title: '4월 주말 수업료 및 출결 인센티브 정산',
              amount: 650000,
              date: DateTime(now.year, now.month, 15),
              category: '강사료',
              paymentMethod: '계좌이체',
              isPaid: false, // 미지급 대기
              memo: '5월 10일 송금 예정 (3.3% 원천징수 공제)',
              createdAt: now.subtract(const Duration(days: 8)),
            ),
          ]
        : [
            ExpenseItem(
              id: 'exp_1',
              vendorId: 'vnd_1',
              vendorName: vendors[0].name,
              title: LocalizationService.pick(
                ko: '5월 학습 교재 및 워크북 30부 발주',
                en: 'Monthly Workbooks & Materials (30 sets)',
                ja: '今月分 テキスト・教材 30部発注',
                zh: '本月教学教材与练习册 30 套采购',
                vi: 'Đặt 30 bộ giáo trình & bài tập',
                es: 'Pedido de 30 cuadernos y material',
              ),
              amount: amt(280000),
              date: DateTime(now.year, now.month, 5),
              category: LocalizationService.pick(
                ko: '교재비',
                en: 'Books',
                ja: '教材費',
                zh: '教材费',
                vi: 'Giáo trình',
                es: 'Libros',
              ),
              paymentMethod: bankTransferLabel,
              isPaid: true,
              memo: LocalizationService.pick(
                ko: '택배 수령 완료 및 정상 입금',
                en: 'Delivered & paid via bank transfer',
                ja: '配送完了・振込済み',
                zh: '已签收并完成对账付款',
                vi: 'Đã nhận hàng & thanh toán',
                es: 'Recibido y pagado por transferencia',
              ),
              createdAt: now.subtract(const Duration(days: 20)),
            ),
            ExpenseItem(
              id: 'exp_2',
              vendorId: 'vnd_3',
              vendorName: vendors[2].name,
              title: LocalizationService.pick(
                ko: '스튜디오 월세 및 기본 관리비',
                en: 'Monthly Studio Lease & Maintenance',
                ja: 'スタジオ家賃・基本管理費',
                zh: '场馆月租及基础物业费',
                vi: 'Tiền thuê phòng & phí quản lý',
                es: 'Alquiler Mensual y Gastos',
              ),
              amount: amt(1200000),
              date: DateTime(now.year, now.month, 1),
              category: LocalizationService.pick(
                ko: '임대료',
                en: 'Rent',
                ja: '家賃',
                zh: '房租',
                vi: 'Mặt bằng',
                es: 'Alquiler',
              ),
              paymentMethod: bankTransferLabel,
              isPaid: true,
              memo: LocalizationService.pick(
                ko: '월초 정기 이체 완료',
                en: 'Monthly recurring transfer completed',
                ja: '月初定期振込完了',
                zh: '月初定期转账已完成',
                vi: 'Đã chuyển khoản định kỳ đầu tháng',
                es: 'Transferencia mensual completada',
              ),
              createdAt: now.subtract(const Duration(days: 25)),
            ),
            ExpenseItem(
              id: 'exp_3',
              vendorId: 'vnd_2',
              vendorName: vendors[1].name,
              title: LocalizationService.pick(
                ko: '친환경 소독제 & 회원용 타올 세탁비',
                en: 'Sanitizer & Member Towel Service',
                ja: '除菌スプレー・会員タオルクリーニング費',
                zh: '环保消毒液及会员毛巾清洗费',
                vi: 'Dung dịch khử khuẩn & giặt khăn',
                es: 'Desinfectante y Lavandería',
              ),
              amount: amt(85000),
              date: DateTime(now.year, now.month, 10),
              category: LocalizationService.pick(
                ko: '소모품비',
                en: 'Supplies',
                ja: '消耗品費',
                zh: '耗材费',
                vi: 'Vật tư',
                es: 'Suministros',
              ),
              paymentMethod: creditCardLabel,
              isPaid: true,
              memo: LocalizationService.pick(
                ko: '정기 소모품 비용 결제',
                en: 'Routine supply card payment',
                ja: '定期消耗品カード決済',
                zh: '日常耗材信用卡支付',
                vi: 'Thanh toán thẻ chi phí định kỳ',
                es: 'Pago periódico con tarjeta',
              ),
              createdAt: now.subtract(const Duration(days: 15)),
            ),
            ExpenseItem(
              id: 'exp_4',
              vendorId: 'vnd_4',
              vendorName: vendors[3].name,
              title: LocalizationService.pick(
                ko: '주말 수업료 및 출결 인센티브 정산',
                en: 'Partner Coach Weekend Session Payout',
                ja: '週末クラス報酬・インセンティブ精算',
                zh: '合作讲师周末课时提成结算',
                vi: 'Quyết toán thù lao lớp cuối tuần',
                es: 'Honorarios Coach Fin de Semana',
              ),
              amount: amt(650000),
              date: DateTime(now.year, now.month, 15),
              category: LocalizationService.pick(
                ko: '강사료',
                en: 'Instructor Fee',
                ja: '講師料',
                zh: '讲师费',
                vi: 'Lương HLV',
                es: 'Honorarios',
              ),
              paymentMethod: bankTransferLabel,
              isPaid: false,
              memo: LocalizationService.pick(
                ko: '송금 예정 정산 건',
                en: 'Pending scheduled payout',
                ja: '振込予定の精算分',
                zh: '待转账结算项目',
                vi: 'Chờ chuyển khoản quyết toán',
                es: 'Pago programado pendiente',
              ),
              createdAt: now.subtract(const Duration(days: 8)),
            ),
          ];

    for (final exp in expenses) {
      await db.insert('expense_items', exp.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }
}

