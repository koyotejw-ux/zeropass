import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../services/localization_service.dart';
import '../theme/app_theme.dart';
import 'app_bottom_sheet.dart';
import 'design_system.dart';

/// Compact Language + Country/Currency selector chip that opens a unified picker sheet.
class RegionLanguageChip extends ConsumerWidget {
  final VoidCallback? onChanged;

  const RegionLanguageChip({super.key, this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final currency = ref.watch(currencyProvider);

    return InkWell(
      onTap: () => showRegionLanguagePickerSheet(context, ref, onChanged: onChanged),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(lang.flag, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 5),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '${lang.label} · ${currency.code}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryDark,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.expand_more_rounded, size: 15, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

Future<void> showRegionLanguagePickerSheet(
  BuildContext context,
  WidgetRef ref, {
  VoidCallback? onChanged,
}) async {
  await AppBottomSheet.show<void>(
    context: context,
    maxHeightRatio: 0.88,
    builder: (ctx) => StickyBottomSheetLayout(
      bodyPadding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      footerPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      footer: ZeroButton.primary(
        label: LocalizationService.tr('common_confirm'),
        size: ZeroButtonSize.large,
        fullWidth: true,
        onPressed: () => Navigator.of(ctx).pop(),
      ),
      body: Consumer(
        builder: (context, sheetRef, _) {
          final activeLang = sheetRef.watch(languageProvider);
          final activeCurrency = sheetRef.watch(currencyProvider);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          LocalizationService.tr('lang_country_picker_title'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          LocalizationService.tr('lang_country_picker_sub'),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                LocalizationService.tr('region_language_label'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryDark,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppLanguage.values.map((lang) {
                  final selected = lang == activeLang;
                  return ChoiceChip(
                    selected: selected,
                    label: Text('${lang.flag} ${lang.label}'),
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? Colors.white : AppTheme.textPrimary,
                    ),
                    selectedColor: AppTheme.primaryDark,
                    backgroundColor: const Color(0xFFF4F4F5),
                    onSelected: (_) async {
                      await sheetRef.read(languageProvider.notifier).setLanguage(lang);
                      await sheetRef
                          .read(currencyProvider.notifier)
                          .setCurrency(AppCurrency.defaultForLanguage(lang));
                      onChanged?.call();
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              Text(
                LocalizationService.tr('region_currency_label'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryDark,
                ),
              ),
              const SizedBox(height: 8),
              ...AppCurrency.values.map((cur) {
                final selected = cur == activeCurrency;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () async {
                      await sheetRef.read(currencyProvider.notifier).setCurrency(cur);
                      onChanged?.call();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xFFEEF2FF) : const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? AppTheme.primaryBlue : const Color(0xFFE4E4E7),
                          width: selected ? 1.4 : 0.9,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(cur.flag, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${cur.code} (${cur.symbol}) · ${cur.displayName}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                                    color: AppTheme.primaryDark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${cur.paymentChannelsSummary} · ${cur.taxPolicy}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                  softWrap: true,
                                ),
                              ],
                            ),
                          ),
                          if (selected)
                            const Icon(Icons.check_circle_rounded, color: AppTheme.primaryBlue, size: 18),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    ),
  );
}
