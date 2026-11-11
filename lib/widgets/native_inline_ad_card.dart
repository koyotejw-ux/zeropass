import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/localization_service.dart';
import '../services/monetization_service.dart';
import '../screens/pro_store_screen.dart';
import '../theme/app_theme.dart';

/// 카드 리스트 및 대시보드와 100% 동일한 시각 문법(16px 둥근 모서리, #E4E4E7 보더, 16px 패딩)을 따르는
/// 통합 네이티브 광고 & 스폰서드 ROI 인라인 카드 위젯.
class NativeInlineAdCard extends StatefulWidget {
  final String placementTag;
  final bool compact;

  const NativeInlineAdCard({
    super.key,
    this.placementTag = 'default',
    this.compact = false,
  });

  @override
  State<NativeInlineAdCard> createState() => _NativeInlineAdCardState();
}

class _NativeInlineAdCardState extends State<NativeInlineAdCard> {
  NativeAd? _nativeAd;
  bool _isNativeAdLoaded = false;

  @override
  void initState() {
    super.initState();
    MonetizationService.instance.addListener(_onMonetizationChanged);
    _loadNativeAd();
  }

  @override
  void dispose() {
    MonetizationService.instance.removeListener(_onMonetizationChanged);
    _nativeAd?.dispose();
    super.dispose();
  }

  void _onMonetizationChanged() {
    if (!mounted) return;
    if (MonetizationService.instance.isAdsRemoved) {
      setState(() {
        _nativeAd?.dispose();
        _nativeAd = null;
        _isNativeAdLoaded = false;
      });
    } else {
      if (_nativeAd == null) {
        _loadNativeAd();
      }
      setState(() {});
    }
  }

  void _loadNativeAd() {
    if (MonetizationService.instance.isAdsRemoved) return;
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    final unitId = MonetizationService.nativeAdUnitId;
    if (unitId.isEmpty) return;

    try {
      _nativeAd = NativeAd(
        adUnitId: unitId,
        request: const AdRequest(),
        nativeTemplateStyle: NativeTemplateStyle(
          templateType: TemplateType.small,
          mainBackgroundColor: Colors.white,
          cornerRadius: 16.0,
          callToActionTextStyle: NativeTemplateTextStyle(
            textColor: Colors.white,
            backgroundColor: AppTheme.primaryBlue,
            style: NativeTemplateFontStyle.bold,
            size: 13.0,
          ),
          primaryTextStyle: NativeTemplateTextStyle(
            textColor: AppTheme.textPrimary,
            backgroundColor: Colors.white,
            style: NativeTemplateFontStyle.bold,
            size: 14.5,
          ),
          secondaryTextStyle: NativeTemplateTextStyle(
            textColor: AppTheme.textSecondary,
            backgroundColor: Colors.white,
            style: NativeTemplateFontStyle.normal,
            size: 12.0,
          ),
        ),
        listener: NativeAdListener(
          onAdLoaded: (ad) {
            if (mounted) {
              setState(() {
                _isNativeAdLoaded = true;
              });
            }
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            if (mounted) {
              setState(() {
                _nativeAd = null;
                _isNativeAdLoaded = false;
              });
            }
          },
        ),
      )..load();
    } catch (_) {
      _isNativeAdLoaded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bm = MonetizationService.instance;
    if (bm.isAdsRemoved) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle, width: 0.9),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header Bar: [AD / 스폰서 안내] + [광고 끄기 >]
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                        ),
                        child: Text(
                          LocalizationService.pick(
                            ko: 'AD · 추천',
                            en: 'AD · Tip',
                            ja: 'AD · おすすめ',
                            zh: 'AD · 推荐',
                            vi: 'AD · Gợi ý',
                            es: 'AD · Recomendado',
                          ),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      Text(
                        LocalizationService.pick(
                          ko: '매장 운영 추천 파트너',
                          en: 'Studio Operations Partner',
                          ja: 'スタジオ運営パートナー',
                          zh: '工作室智能运营助手',
                          vi: 'Trợ lý vận hành trung tâm',
                          es: 'Aliado para tu centro',
                        ),
                        softWrap: true,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProStoreScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      LocalizationService.pick(
                        ko: '광고 끄기 >',
                        en: 'Hide Ads >',
                        ja: '広告オフ >',
                        zh: '关闭广告 >',
                        vi: 'Tắt QC >',
                        es: 'Sin anuncios >',
                      ),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // AdMob Native Template or Native House VIP Card Fallback
          if (_isNativeAdLoaded && _nativeAd != null)
            ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 280,
                minHeight: 90,
                maxHeight: 115,
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                child: AdWidget(ad: _nativeAd!),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Icon(Icons.tablet_mac_rounded, color: Color(0xFFD97706), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          LocalizationService.pick(
                            ko: '안 쓰는 공기계를 무인 출결 키오스크로!',
                            en: 'Turn Any Tablet into a Check-in Kiosk!',
                            ja: '手持ちタブレットを無人受付キオスクに！',
                            zh: '闲置平板秒变自助扫码签到终端！',
                            vi: 'Biến máy tính bảng thành Kiosk điểm danh!',
                            es: '¡Convierte tu tablet en un quiosco!',
                          ),
                          softWrap: true,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          LocalizationService.pick(
                            ko: '타사 월 49,000원 기기 대신 광고 없는 올인원 VIP 패스로 1시간 무료 체험해 보세요.',
                            en: 'Try the ad-free All-in-One VIP Kiosk pass free for 1 hour.',
                            ja: '広告なしVIPパスでキオスク機能を1時間無料でお試しください。',
                            zh: '立即免费体验 1 小时免广告全能 VIP 与自助考勤终端。',
                            vi: 'Dùng thử miễn phí 1 giờ gói VIP Kiosk không quảng cáo.',
                            es: 'Prueba 1 hora gratis del pase VIP Quiosco sin anuncios.',
                          ),
                          softWrap: true,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 36,
                    child: OutlinedButton(
                      onPressed: bm.canClaimTemporaryPass
                          ? () => bm.launchTemporaryPassFlow(context)
                          : null,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFF8FAFC),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        LocalizationService.pick(
                          ko: '무료 체험',
                          en: 'Try Free',
                          ja: '無料体験',
                          zh: '免费试用',
                          vi: 'Dùng thử',
                          es: 'Probar',
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

