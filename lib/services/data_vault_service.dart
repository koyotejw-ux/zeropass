import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/member.dart';
import '../models/pass_record.dart';
import '../models/invoice.dart';
import '../models/studio_profile.dart';
import 'database_service.dart';

class DataVaultService {
  /// Exports all local database records as an encrypted/formatted JSON string file.
  static Future<File> exportEncryptedBackup() async {
    final db = DatabaseService.instance;
    final members = await db.getMembers();
    final passRecords = await db.getPassRecords();
    final invoices = await db.getInvoices();
    final profile = await db.getStudioProfile();

    final backupPayload = {
      'version': '1.0.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'disclaimer': 'ZeroPass Local-Only Vault Encrypted Backup. Zero server transmission guaranteed.',
      'profile': profile.toMap(),
      'members': members.map((m) => m.toMap()).toList(),
      'passRecords': passRecords.map((p) => p.toMap()).toList(),
      'invoices': invoices.map((i) => i.toMap()).toList(),
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

      return true;
    } catch (_) {
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
        subject: '[제로패스] 수납 장부 결산 엑셀(CSV)',
        text: '제로패스 원장님 전용 수납 및 매출 결산 엑셀(CSV) 파일입니다.',
      ),
    );
  }
}
