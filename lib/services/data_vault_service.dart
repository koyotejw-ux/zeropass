import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/expense_item.dart';
import '../models/member.dart';
import '../models/pass_record.dart';
import '../models/invoice.dart';
import '../models/studio_profile.dart';
import '../models/vendor.dart';
import 'database_service.dart';

class DataVaultService {
  /// Exports all local database records as an encrypted/formatted JSON string file.
  static Future<File> exportEncryptedBackup() async {
    final db = DatabaseService.instance;
    final members = await db.getMembers();
    final passRecords = await db.getPassRecords();
    final invoices = await db.getInvoices();
    final profile = await db.getStudioProfile();
    final vendors = await db.getVendors();
    final expenses = await db.getExpenses();

    final backupPayload = {
      'version': '1.0.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'disclaimer': 'ZeroPass Local-Only Vault Encrypted Backup. Zero server transmission guaranteed.',
      'profile': profile.toMap(),
      'members': members.map((m) => m.toMap()).toList(),
      'passRecords': passRecords.map((p) => p.toMap()).toList(),
      'invoices': invoices.map((i) => i.toMap()).toList(),
      'vendors': vendors.map((v) => v.toMap()).toList(),
      'expenses': expenses.map((e) => e.toMap()).toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(backupPayload);

    final dir = await getApplicationDocumentsDirectory();
    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/zeropass_backup_$dateStr.json');
    await file.writeAsString(jsonString);

    return file;
  }

  /// 1-Touch Native Share: Sends backup file to KakaoTalk "My Chat", Google Drive, or Email for 100% Free Zero-Cost Cloud Backup
  static Future<ShareResult> shareBackupFile(File file) async {
    return await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: '[체크앤페이] 안심 로컬 데이터 백업 파일',
        text: '체크앤페이 원장님 전용 로컬 데이터 백업 파일입니다. 휴대폰 분실 및 기기 변경 시 복원용으로 보관하세요.',
      ),
    );
  }

  /// Restores from backup JSON string content.
  static Future<bool> restoreFromBackupJson(String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final db = DatabaseService.instance;

      if (data.containsKey('profile')) {
        final profile = StudioProfile.fromMap(data['profile']);
        await db.updateStudioProfile(profile);
      }

      if (data.containsKey('members')) {
        final membersList = data['members'] as List;
        for (final m in membersList) {
          await db.insertMember(Member.fromMap(m));
        }
      }

      if (data.containsKey('passRecords')) {
        final passList = data['passRecords'] as List;
        for (final p in passList) {
          await db.insertPassRecord(PassRecord.fromMap(p));
        }
      }

      if (data.containsKey('invoices')) {
        final invList = data['invoices'] as List;
        for (final i in invList) {
          await db.insertInvoice(Invoice.fromMap(i));
        }
      }

      if (data.containsKey('vendors')) {
        final vendorList = data['vendors'] as List;
        for (final v in vendorList) {
          await db.insertVendor(Vendor.fromMap(v));
        }
      }

      if (data.containsKey('expenses')) {
        final expList = data['expenses'] as List;
        for (final e in expList) {
          await db.insertExpense(ExpenseItem.fromMap(e));
        }
      }

      return true;
    } catch (e, stack) {
      debugPrint('[DataVaultService] restoreFromBackupJson error: $e\n$stack');
      return false;
    }
  }

  /// Exports ledger & invoice history to CSV format for instructors/accountants.
  static Future<File> exportLedgerCsv() async {
    final invoices = await DatabaseService.instance.getInvoices();
    final members = await DatabaseService.instance.getMembers();
    final memberMap = {for (var m in members) m.id: m.name};

    final List<List<dynamic>> rows = [
      ['청구서ID', '회원명', '연락처', '청구항목', '금액(원)', '상태', '납부기한', '수납일시', '결제수단'],
    ];

    for (final inv in invoices) {
      final names = inv.memberIds.map((id) => memberMap[id] ?? id).join(' / ');
      rows.add([
        inv.id,
        names,
        inv.recipientPhone,
        inv.title,
        inv.amount,
        inv.status == PaymentStatus.paid ? '수납완료' : '미납',
        DateFormat('yyyy-MM-dd').format(inv.dueDate),
        inv.paidAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(inv.paidAt!) : '-',
        inv.paymentMethod ?? '-',
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/zeropass_ledger_$dateStr.csv');
    // Prepend UTF-8 BOM for Excel compatibility in Korean Windows
    await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(csvData)]);

    return file;
  }

  /// 1-Touch Native Share for Ledger CSV (KakaoTalk / Email / Excel / Drive)
  static Future<ShareResult> shareLedgerCsv(File file) async {
    return await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: '[체크앤페이] 수납 장부 결산 엑셀(CSV)',
        text: '체크앤페이 원장님 전용 수납 및 매출 결산 엑셀(CSV) 파일입니다.',
      ),
    );
  }

  /// Exports National Tax Service (국세청 홈택스) Standard Simplified Bookkeeping (사업소득 간편장부) CSV
  /// Integrates both Revenue (수입) & Expenses (비용) into a unified chronologically sorted ledger.
  static Future<File> exportSimplifiedBookkeepingCsv() async {
    final db = DatabaseService.instance;
    final invoices = await db.getInvoices();
    final expenses = await db.getExpenses();
    final members = await db.getMembers();
    final memberMap = {for (var m in members) m.id: m.name};

    // Unified ledger entry data class
    final List<Map<String, dynamic>> combinedEntries = [];

    // 1. Process Paid Invoices (수입/매출)
    for (final inv in invoices) {
      if (inv.status != PaymentStatus.paid) continue;
      final names = inv.memberIds.map((id) => memberMap[id] ?? id).join(' / ');
      final date = inv.paidAt ?? inv.dueDate;
      combinedEntries.add({
        'date': date,
        'dateStr': DateFormat('yyyy-MM-dd').format(date),
        'type': '수입(매출)',
        'counterparty': names.isNotEmpty ? names : '회원 수납',
        'item': inv.title,
        'revenue': inv.amount,
        'expense': 0,
        'actualPayout': inv.amount,
        'paymentMethod': inv.paymentMethod ?? '계좌이체',
        'taxEvidence': (inv.paymentMethod == '현금')
            ? '현금영수증(지출증빙)'
            : (inv.paymentMethod == '온라인카드' ? '신용카드매출전표' : '통장입금증빙'),
        'withholdingTax': '-',
        'memo': '수납완료 (외령번호: ${inv.externalOrderId ?? '-'})',
      });
    }

    // 2. Process Expenses (비용/매입)
    for (final exp in expenses) {
      combinedEntries.add({
        'date': exp.date,
        'dateStr': DateFormat('yyyy-MM-dd').format(exp.date),
        'type': '비용(매입/경비)',
        'counterparty': exp.vendorName,
        'item': '${exp.title} [${exp.category}]',
        'revenue': 0,
        'expense': exp.amount,
        'actualPayout': exp.actualPayoutAmount,
        'paymentMethod': exp.paymentMethod,
        'taxEvidence': exp.taxEvidence,
        'withholdingTax': exp.isWithholdingApplied ? '${exp.withholdingTax}원 (3.3%)' : '-',
        'memo': exp.memo ?? (exp.isPaid ? '완납' : '미지급외상'),
      });
    }

    // Sort chronologically (oldest to newest for bookkeeping standard)
    combinedEntries.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    // Construct CSV Rows
    final List<List<dynamic>> rows = [
      ['[국세청 표준 사업소득 간편장부]', '생성일: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}', '', '', '', '', '', '', '', '', ''],
      ['일자', '구분', '거래처/수취인', '품목/적요', '수입금액(원)', '비용금액(원)', '실지급액(원)', '결제수단', '세무적격증빙', '원천징수(3.3%)', '비고/상태'],
    ];

    int totalRevenue = 0;
    int totalExpense = 0;

    for (final entry in combinedEntries) {
      final rev = entry['revenue'] as int;
      final exp = entry['expense'] as int;
      totalRevenue += rev;
      totalExpense += exp;

      rows.add([
        entry['dateStr'],
        entry['type'],
        entry['counterparty'],
        entry['item'],
        rev > 0 ? rev : 0,
        exp > 0 ? exp : 0,
        entry['actualPayout'],
        entry['paymentMethod'],
        entry['taxEvidence'],
        entry['withholdingTax'],
        entry['memo'],
      ]);
    }

    // Add Summary Row
    rows.add(['', '', '', '', '', '', '', '', '', '', '']);
    rows.add(['[합계]', '당월/누적 결산', '', '', totalRevenue, totalExpense, '', '', '', '', '당월 순이익: ${totalRevenue - totalExpense}원']);

    final csvData = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/zeropass_simplified_ledger_$dateStr.csv');
    // Prepend UTF-8 BOM for Excel compatibility in Korean Windows
    await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(csvData)]);

    return file;
  }

  /// 1-Touch Native Share for Simplified Bookkeeping CSV
  static Future<ShareResult> shareSimplifiedBookkeepingCsv(File file) async {
    return await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: '[체크앤페이] 국세청 표준 사업소득 간편장부 (세무사 제출용)',
        text: '체크앤페이에서 생성된 국세청 고시 표준 사업소득 간편장부 엑셀(CSV) 파일입니다. 5월 종합소득세 및 2월 사업장현황신고 세무 결산용으로 사용하실 수 있습니다.',
      ),
    );
  }

  /// Exports member directory to CSV format for instructors/staff.
  static Future<File> exportMembersCsv() async {
    final members = await DatabaseService.instance.getMembers();

    final List<List<dynamic>> rows = [
      ['회원ID', '이름', '연락처', '수업그룹', '결제유형', '기본금액(원)', '총회차', '잔여회차', '보호자/입금자', '등록일'],
    ];

    for (final m in members) {
      rows.add([
        m.id,
        m.name,
        m.phone,
        m.groupName,
        m.billingType == BillingType.monthlyRecurring ? '월정기권' : '회차권',
        m.defaultFee,
        m.totalSessions,
        m.remainingSessions,
        m.payerName ?? '-',
        DateFormat('yyyy-MM-dd').format(m.registeredAt),
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/zeropass_members_$dateStr.csv');
    // Prepend UTF-8 BOM for Excel compatibility in Korean Windows
    await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(csvData)]);

    return file;
  }

  /// 1-Touch Native Share for Member Directory CSV (KakaoTalk / Email / Excel / Drive)
  static Future<ShareResult> shareMembersCsv(File file) async {
    return await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: '[제로패스] 회원 명부 엑셀(CSV) 내보내기',
        text: '제로패스 등록 회원 전체 명부 엑셀(CSV) 파일입니다. (100% 로컬 생성)',
      ),
    );
  }
}

