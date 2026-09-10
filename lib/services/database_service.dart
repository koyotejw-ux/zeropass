import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import '../models/member.dart';
import '../models/pass_record.dart';
import '../models/invoice.dart';
import '../models/studio_profile.dart';

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
      version: 1,
      onCreate: _onCreate,
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
        registeredAt TEXT NOT NULL
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
        autoBankDetectEnabled INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Insert Default Studio Profile
    final defaultProfile = StudioProfile.defaultProfile();
    await db.insert('studio_profile', defaultProfile.toMap());

    // Insert Rich Realistic Mock Data (5 Multi-industry members)
    await _seedMockData(db);
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
        name: '정하율 (쇼팽 피아노)',
        phone: '01099881234',
        groupName: '피아노 클래식반',
        billingType: BillingType.monthlyRecurring,
        defaultFee: 180000,
        totalSessions: 0,
        remainingSessions: 0,
        memo: '자매 회원: 정하린(동생)과 같은 학부모 전화번호',
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
    await db.insert('pass_records', record.toMap());
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
}
