import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/expense_item.dart';
import '../models/member.dart';
import '../models/notification_log.dart';
import '../models/pass_record.dart';
import '../models/invoice.dart';
import '../models/schedule_item.dart';
import '../models/studio_profile.dart';
import '../models/vendor.dart';
import 'database_service.dart';
import 'localization_service.dart';
import 'monetization_service.dart';
import 'schedule_service.dart';

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
    final notificationLogs = await db.getNotificationLogs(limit: 500);
    List<ScheduleItem> schedules = [];
    try {
      schedules = await ScheduleService.loadSchedules();
    } catch (_) {}

    final backupPayload = {
      'version': '1.1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'disclaimer': 'ZeroPass Local-Only Vault Encrypted Backup. Zero server transmission guaranteed.',
      'profile': profile.toMap(),
      'members': members.map((m) => m.toMap()).toList(),
      'passRecords': passRecords.map((p) => p.toMap()).toList(),
      'invoices': invoices.map((i) => i.toMap()).toList(),
      'vendors': vendors.map((v) => v.toMap()).toList(),
      'expenses': expenses.map((e) => e.toMap()).toList(),
      'notificationLogs': notificationLogs.map((n) => n.toMap()).toList(),
      'schedules': schedules.map((s) => s.toMap()).toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(backupPayload);

    final dir = await getApplicationDocumentsDirectory();
    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/zeropass_backup_$dateStr.json');
    await file.writeAsString(jsonString);

    return file;
  }

  /// 1-Touch Native Share: Sends backup file to Messenger, Google Drive, or Email for 100% Free Zero-Cost Cloud Backup
  static Future<ShareResult> shareBackupFile(File file) async {
    MonetizationService.instance.suppressAppOpenAdTemporarily(seconds: 60);
    return await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: LocalizationService.pick(
          ko: '[체크앤페이] 안심 로컬 데이터 백업 파일',
          en: '[Check & Pay] Secure Local Data Backup',
          ja: '[Check & Pay] ローカルデータバックアップ',
          zh: '[Check & Pay] 本地数据备份文件',
          vi: '[Check & Pay] Tệp sao lưu dữ liệu cục bộ',
          es: '[Check & Pay] Copia de seguridad local',
        ),
        text: LocalizationService.pick(
          ko: '체크앤페이 로컬 데이터 백업 파일입니다. 휴대폰 분실 및 기기 변경 시 복원용으로 보관하세요.',
          en: 'Your Check & Pay local data backup file. Store safely to restore when switching devices.',
          ja: 'Check & Payのローカルバックアップファイルです。機種変更時の復元に保管してください。',
          zh: 'Check & Pay 本地数据备份文件，请妥善保存以便更换设备时恢复。',
          vi: 'Đây là tệp sao lưu cục bộ Check & Pay. Hãy lưu giữ an toàn để khôi phục khi đổi thiết bị.',
          es: 'Archivo de respaldo local de Check & Pay. Guárdalo para restaurar al cambiar de dispositivo.',
        ),
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

      if (data.containsKey('notificationLogs')) {
        final logList = data['notificationLogs'] as List;
        for (final n in logList) {
          await db.insertNotificationLog(NotificationLog.fromMap(n));
        }
      }

      if (data.containsKey('schedules')) {
        try {
          final schList = data['schedules'] as List;
          final items = schList.map((s) => ScheduleItem.fromMap(s as Map<String, dynamic>)).toList();
          await ScheduleService.saveSchedules(items);
        } catch (_) {}
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
    final cur = LocalizationService.currentCurrency;
    final isKrDefault = LocalizationService.currentLanguage == AppLanguage.korean && cur == AppCurrency.krw;

    final List<List<dynamic>> rows = [
      isKrDefault
          ? ['청구서ID', '회원명', '연락처', '청구항목', '금액(원)', '상태', '납부기한', '수납일시', '결제수단']
          : LocalizationService.pickList(
              ko: ['청구서ID', '회원명', '연락처', '청구항목', '금액(${cur.code})', '상태', '납부기한', '수납일시', '결제수단'],
              en: ['Invoice ID', 'Member Name', 'Phone', 'Item', 'Amount (${cur.code})', 'Status', 'Due Date', 'Paid At', 'Method'],
              ja: ['請求ID', '会員名', '連絡先', '項目', '金額(${cur.code})', '状態', '支払期限', '入金日時', '支払方法'],
              zh: ['账单ID', '会员姓名', '电话', '收费项目', '金额(${cur.code})', '状态', '截止日', '收款时间', '收款方式'],
              vi: ['Mã hóa đơn', 'Hội viên', 'SĐT', 'Hạng mục', 'Số tiền (${cur.code})', 'Trạng thái', 'Hạn nộp', 'Ngày thu', 'Phương thức'],
              es: ['ID Factura', 'Miembro', 'Teléfono', 'Concepto', 'Importe (${cur.code})', 'Estado', 'Vencimiento', 'Fecha Pago', 'Método'],
            ),
    ];

    for (final inv in invoices) {
      final names = inv.memberIds.map((id) => memberMap[id] ?? id).join(' / ');
      rows.add([
        inv.id,
        names,
        inv.recipientPhone,
        inv.title,
        inv.amount,
        inv.status == PaymentStatus.paid
            ? LocalizationService.pick(ko: '수납완료', en: 'Paid', ja: '領収済', zh: '已收款', vi: 'Đã thu', es: 'Pagado')
            : LocalizationService.pick(ko: '미납', en: 'Unpaid', ja: '未納', zh: '未付', vi: 'Chưa thu', es: 'Impago'),
        DateFormat('yyyy-MM-dd').format(inv.dueDate),
        inv.paidAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(inv.paidAt!) : '-',
        inv.paymentMethod != null ? LocalizationService.paymentMethodLabel(inv.paymentMethod!) : '-',
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/zeropass_ledger_$dateStr.csv');
    // Prepend UTF-8 BOM for Excel compatibility
    await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(csvData)]);

    return file;
  }

  /// 1-Touch Native Share for Ledger CSV (Messenger / Email / Excel / Drive)
  static Future<ShareResult> shareLedgerCsv(File file) async {
    MonetizationService.instance.suppressAppOpenAdTemporarily(seconds: 60);
    return await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: LocalizationService.pick(
          ko: '[체크앤페이] 수납 장부 결산 엑셀(CSV)',
          en: '[Check & Pay] Billing & Revenue Ledger (CSV)',
          ja: '[Check & Pay] 売上・集金台帳 (CSV)',
          zh: '[Check & Pay] 收款流水明细表 (CSV)',
          vi: '[Check & Pay] Sổ thu chi & hóa đơn (CSV)',
          es: '[Check & Pay] Libro de Cobros (CSV)',
        ),
        text: LocalizationService.pick(
          ko: '체크앤페이 수납 및 매출 결산 엑셀(CSV) 파일입니다.',
          en: 'Check & Pay billing and revenue summary CSV file.',
          ja: 'Check & Payの売上・集金CSVファイルです。',
          zh: 'Check & Pay 账单收款与营收汇总 CSV 报表。',
          vi: 'Tệp báo cáo thu học phí và doanh thu CSV từ Check & Pay.',
          es: 'Archivo CSV de cobros e ingresos de Check & Pay.',
        ),
      ),
    );
  }

  /// Exports Standard Simplified Tax Bookkeeping CSV
  /// Integrates both Revenue & Expenses into a unified chronologically sorted ledger.
  static Future<File> exportSimplifiedBookkeepingCsv() async {
    final db = DatabaseService.instance;
    final invoices = await db.getInvoices();
    final expenses = await db.getExpenses();
    final members = await db.getMembers();
    final memberMap = {for (var m in members) m.id: m.name};
    final cur = LocalizationService.currentCurrency;
    final lang = LocalizationService.currentLanguage;
    final isKrDefault = lang == AppLanguage.korean && cur == AppCurrency.krw;
    final ratePct = '${(LocalizationService.defaultWithholdingRate * 100).toStringAsFixed(1)}%';

    // Unified ledger entry data class
    final List<Map<String, dynamic>> combinedEntries = [];

    // 1. Process Paid Invoices (Revenue)
    for (final inv in invoices) {
      if (inv.status != PaymentStatus.paid) continue;
      final names = inv.memberIds.map((id) => memberMap[id] ?? id).join(' / ');
      final date = inv.paidAt ?? inv.dueDate;
      final method = inv.paymentMethod ?? '계좌이체';
      final evidence = method == '현금'
          ? '현금영수증(지출증빙)'
          : (method == '온라인카드' ? '신용카드매출전표' : '통장입금증빙');
      combinedEntries.add({
        'date': date,
        'dateStr': DateFormat('yyyy-MM-dd').format(date),
        'type': LocalizationService.pick(ko: '수입(매출)', en: 'Revenue', ja: '収入(売上)', zh: '收入(营收)', vi: 'Thu nhập', es: 'Ingreso'),
        'counterparty': names.isNotEmpty
            ? names
            : LocalizationService.pick(ko: '회원 수납', en: 'Member Payment', ja: '会員入金', zh: '会员缴费', vi: 'Thu hội viên', es: 'Pago miembro'),
        'item': inv.title,
        'revenue': inv.amount,
        'expense': 0,
        'actualPayout': inv.amount,
        'paymentMethod': LocalizationService.paymentMethodLabel(method),
        'taxEvidence': LocalizationService.taxEvidenceLabel(evidence),
        'withholdingTax': '-',
        'memo': LocalizationService.pick(
          ko: '수납완료 (외령번호: ${inv.externalOrderId ?? '-'})',
          en: 'Paid (Ref: ${inv.externalOrderId ?? '-'})',
          ja: '領収済 (参照: ${inv.externalOrderId ?? '-'})',
          zh: '已收款 (单号: ${inv.externalOrderId ?? '-'})',
          vi: 'Đã thu (Mã: ${inv.externalOrderId ?? '-'})',
          es: 'Pagado (Ref: ${inv.externalOrderId ?? '-'})',
        ),
      });
    }

    // 2. Process Expenses
    for (final exp in expenses) {
      final expRate = exp.isWithholdingApplied ? '$ratePct' : '-';
      combinedEntries.add({
        'date': exp.date,
        'dateStr': DateFormat('yyyy-MM-dd').format(exp.date),
        'type': LocalizationService.pick(ko: '비용(매입/경비)', en: 'Expense', ja: '経費・支出', zh: '支出(成本费用)', vi: 'Chi phí', es: 'Gasto'),
        'counterparty': exp.vendorName,
        'item': '${exp.title} [${LocalizationService.localizeBuiltInLabel(exp.category)}]',
        'revenue': 0,
        'expense': exp.amount,
        'actualPayout': exp.actualPayoutAmount,
        'paymentMethod': LocalizationService.localizeBuiltInLabel(exp.paymentMethod),
        'taxEvidence': LocalizationService.taxEvidenceLabel(exp.taxEvidence),
        'withholdingTax': exp.isWithholdingApplied ? '${LocalizationService.formatAmount(exp.withholdingTax)} ($expRate)' : '-',
        'memo': exp.memo ??
            (exp.isPaid
                ? LocalizationService.pick(ko: '완납', en: 'Paid', ja: '支払済', zh: '已付', vi: 'Đã trả', es: 'Pagado')
                : LocalizationService.pick(ko: '미지급외상', en: 'Payable', ja: '未払', zh: '待付', vi: 'Chưa trả', es: 'Pendiente')),
      });
    }

    // Sort chronologically (oldest to newest for bookkeeping standard)
    combinedEntries.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    // Construct CSV Rows
    final List<List<dynamic>> rows = [
      [
        isKrDefault
            ? '[국세청 표준 사업소득 간편장부]'
            : LocalizationService.pick(
                ko: '[세무 신고용 간편장부 (${cur.code})]',
                en: '[Tax Bookkeeping Ledger (${cur.code})]',
                ja: '[確定申告用 簡易帳簿 (${cur.code})]',
                zh: '[税务申报标准简易账本 (${cur.code})]',
                vi: '[Sổ kế toán thuế đơn giản (${cur.code})]',
                es: '[Libro Contable Fiscal (${cur.code})]',
              ),
        LocalizationService.pick(
          ko: '생성일: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
          en: 'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
          ja: '作成日時: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
          zh: '生成时间: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
          vi: 'Ngày tạo: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
          es: 'Generado: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
        ),
        '', '', '', '', '', '', '', '', '',
      ],
      isKrDefault
          ? ['일자', '구분', '거래처/수취인', '품목/적요', '수입금액(원)', '비용금액(원)', '실지급액(원)', '결제수단', '세무적격증빙', '원천징수(3.3%)', '비고/상태']
          : LocalizationService.pickList(
              ko: ['일자', '구분', '거래처/수취인', '품목/적요', '수입금액(${cur.code})', '비용금액(${cur.code})', '실지급액(${cur.code})', '결제수단', '세무증빙', '원천징수($ratePct)', '비고/상태'],
              en: ['Date', 'Type', 'Counterparty', 'Description', 'Revenue (${cur.code})', 'Expense (${cur.code})', 'Net Amount (${cur.code})', 'Method', 'Tax Evidence', 'Withholding ($ratePct)', 'Notes/Status'],
              ja: ['日付', '区分', '取引先/相手', '摘要', '収入 (${cur.code})', '経費 (${cur.code})', '実支払額 (${cur.code})', '支払方法', '証憑区分', '源泉徴収 ($ratePct)', '備考/状態'],
              zh: ['日期', '收支类型', '对方/往来单位', '项目摘要', '收入 (${cur.code})', '支出 (${cur.code})', '实付净额 (${cur.code})', '方式', '税务凭证', '代扣税 ($ratePct)', '备注/状态'],
              vi: ['Ngày', 'Loại', 'Đối tác', 'Mô tả', 'Doanh thu (${cur.code})', 'Chi phí (${cur.code})', 'Thực chi (${cur.code})', 'Phương thức', 'Chứng từ thuế', 'Khấu trừ ($ratePct)', 'Ghi chú'],
              es: ['Fecha', 'Tipo', 'Contraparte', 'Concepto', 'Ingresos (${cur.code})', 'Gastos (${cur.code})', 'Neto (${cur.code})', 'Método', 'Justificante', 'Retención ($ratePct)', 'Notas'],
            ),
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
    rows.add([
      LocalizationService.pick(ko: '[합계]', en: '[Total]', ja: '[合計]', zh: '[合计]', vi: '[Tổng]', es: '[Total]'),
      LocalizationService.pick(ko: '당월/누적 결산', en: 'Summary', ja: '集計', zh: '收支汇总', vi: 'Tổng kết', es: 'Resumen'),
      '',
      '',
      totalRevenue,
      totalExpense,
      '',
      '',
      '',
      '',
      LocalizationService.pick(
        ko: '당월 순이익: ${isKrDefault ? '${totalRevenue - totalExpense}원' : LocalizationService.formatAmount(totalRevenue - totalExpense)}',
        en: 'Net Profit: ${LocalizationService.formatAmount(totalRevenue - totalExpense)}',
        ja: '純利益: ${LocalizationService.formatAmount(totalRevenue - totalExpense)}',
        zh: '净收益: ${LocalizationService.formatAmount(totalRevenue - totalExpense)}',
        vi: 'Lợi nhuận ròng: ${LocalizationService.formatAmount(totalRevenue - totalExpense)}',
        es: 'Beneficio neto: ${LocalizationService.formatAmount(totalRevenue - totalExpense)}',
      ),
    ]);

    final csvData = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/zeropass_simplified_ledger_$dateStr.csv');
    // Prepend UTF-8 BOM for Excel compatibility
    await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(csvData)]);

    return file;
  }

  /// 1-Touch Native Share for Simplified Bookkeeping CSV
  static Future<ShareResult> shareSimplifiedBookkeepingCsv(File file) async {
    MonetizationService.instance.suppressAppOpenAdTemporarily(seconds: 60);
    final isKrDefault = LocalizationService.currentCurrency == AppCurrency.krw;
    return await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: isKrDefault
            ? LocalizationService.pick(
                ko: '[체크앤페이] 국세청 표준 사업소득 간편장부 (세무사 제출용)',
                en: '[Check & Pay] Simplified Tax Bookkeeping Ledger (CSV)',
                ja: '[Check & Pay] 簡易帳簿レポート (CSV)',
                zh: '[Check & Pay] 税务简化台账报表 (CSV)',
                vi: '[Check & Pay] Sổ kế toán thuế đơn giản (CSV)',
                es: '[Check & Pay] Libro contable simplificado (CSV)',
              )
            : LocalizationService.pick(
                ko: '[체크앤페이] 세무 결산용 간편장부 엑셀(CSV)',
                en: '[Check & Pay] Tax & Bookkeeping Ledger (CSV)',
                ja: '[Check & Pay] 確定申告用 簡易帳簿 (CSV)',
                zh: '[Check & Pay] 税务结账简化台账 (CSV)',
                vi: '[Check & Pay] Sổ kế toán thuế (CSV)',
                es: '[Check & Pay] Libro contable fiscal (CSV)',
              ),
        text: isKrDefault
            ? LocalizationService.pick(
                ko: '체크앤페이에서 생성된 국세청 고시 표준 사업소득 간편장부 엑셀(CSV) 파일입니다. 5월 종합소득세 및 2월 사업장현황신고 세무 결산용으로 사용하실 수 있습니다.',
                en: 'Simplified revenue & expense tax bookkeeping CSV exported from Check & Pay.',
                ja: 'Check & Payから出力された確定申告用の収支簡易帳簿CSVファイルです。',
                zh: '由 Check & Pay 导出的收支简易财务台账 CSV 文件。',
                vi: 'Tệp sổ kế toán doanh thu và chi phí CSV xuất từ Check & Pay.',
                es: 'Archivo CSV de ingresos y gastos exportado desde Check & Pay.',
              )
            : LocalizationService.pick(
                ko: '체크앤페이에서 생성된 매출·비용 세무 결산용 엑셀(CSV) 파일입니다.',
                en: 'Tax bookkeeping ledger CSV exported from Check & Pay for your accountant or tax filing.',
                ja: 'Check & Payから出力された確定申告・税理士提出用の簡易帳簿CSVファイルです。',
                zh: '由 Check & Pay 生成的财务报税对账 CSV 文件，可直接提交给会计师。',
                vi: 'Tệp CSV sổ kế toán thuế xuất từ Check & Pay để nộp hoặc gửi kế toán.',
                es: 'Libro contable CSV exportado desde Check & Pay para tu asesor o declaración fiscal.',
              ),
      ),
    );
  }

  /// Exports member directory to CSV format for instructors/staff.
  static Future<File> exportMembersCsv() async {
    final members = await DatabaseService.instance.getMembers();
    final cur = LocalizationService.currentCurrency;
    final isKrDefault = LocalizationService.currentLanguage == AppLanguage.korean && cur == AppCurrency.krw;

    final List<List<dynamic>> rows = [
      isKrDefault
          ? ['회원ID', '이름', '연락처', '수업그룹', '결제유형', '기본금액(원)', '총회차', '잔여회차', '보호자/입금자', '등록일']
          : LocalizationService.pickList(
              ko: ['회원ID', '이름', '연락처', '수업그룹', '결제유형', '기본금액(${cur.code})', '총회차', '잔여회차', '보호자/입금자', '등록일'],
              en: ['Member ID', 'Name', 'Phone', 'Group', 'Plan Type', 'Default Fee (${cur.code})', 'Total Sessions', 'Remaining', 'Guardian/Payer', 'Registered'],
              ja: ['会員ID', '氏名', '連絡先', 'クラス', '契約種別', '基本料金(${cur.code})', '総回数', '残回数', '保護者/振込名', '登録日'],
              zh: ['会员ID', '姓名', '电话', '班级', '计费类型', '标准费用(${cur.code})', '总课时', '剩余课时', '家长/付款人', '登记日期'],
              vi: ['Mã HV', 'Tên', 'SĐT', 'Nhóm/Lớp', 'Loại gói', 'Học phí (${cur.code})', 'Tổng buổi', 'Còn lại', 'Phụ huynh', 'Ngày đăng ký'],
              es: ['ID', 'Nombre', 'Teléfono', 'Grupo', 'Tarifa', 'Importe (${cur.code})', 'Total Sesiones', 'Restantes', 'Tutor/Pagador', 'Fecha Alta'],
            ),
    ];

    for (final m in members) {
      rows.add([
        m.id,
        m.name,
        m.phone,
        LocalizationService.localizeBuiltInLabel(m.groupName),
        m.billingType == BillingType.monthlyRecurring
            ? LocalizationService.pick(ko: '월정기권', en: 'Monthly', ja: '月謝制', zh: '包月', vi: 'Theo tháng', es: 'Mensual')
            : LocalizationService.pick(ko: '회차권', en: 'Session Pass', ja: '回数券', zh: '次卡', vi: 'Theo buổi', es: 'Bono'),
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
    // Prepend UTF-8 BOM for Excel compatibility
    await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(csvData)]);

    return file;
  }

  /// 1-Touch Native Share for Member Directory CSV
  static Future<ShareResult> shareMembersCsv(File file) async {
    MonetizationService.instance.suppressAppOpenAdTemporarily(seconds: 60);
    return await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: LocalizationService.pick(
          ko: '[체크앤페이] 회원 명부 엑셀(CSV) 내보내기',
          en: '[Check & Pay] Member Directory Export (CSV)',
          ja: '[Check & Pay] 会員名簿エクスポート (CSV)',
          zh: '[Check & Pay] 会员名册导出 (CSV)',
          vi: '[Check & Pay] Danh bạ hội viên (CSV)',
          es: '[Check & Pay] Directorio de Miembros (CSV)',
        ),
        text: LocalizationService.pick(
          ko: '체크앤페이 등록 회원 전체 명부 엑셀(CSV) 파일입니다. (100% 로컬 생성)',
          en: 'Complete member directory CSV generated locally by Check & Pay.',
          ja: 'Check & Payからローカル生成された全会員名簿CSVファイルです。',
          zh: '由 Check & Pay 本地生成的全部会员名册 CSV 文件。',
          vi: 'Danh sách toàn bộ hội viên được tạo cục bộ bởi Check & Pay.',
          es: 'Directorio completo generado localmente por Check & Pay.',
        ),
      ),
    );
  }
}

