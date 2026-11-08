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

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  DatabaseService._internal();

  Database? _database;

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

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'zeropass_local_vault.db');

    return await openDatabase(
      path,
      version: 9,
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
        customFeeTerm TEXT
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

    final members = [
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
    final invoices = [
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

    final vendors = [
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
    ];

    for (final v in vendors) {
      await db.insert('vendors', v.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }

    final expenses = [
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
    ];

    for (final exp in expenses) {
      await db.insert('expense_items', exp.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }
}

