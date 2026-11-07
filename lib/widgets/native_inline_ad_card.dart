import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
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
                        child: const Text(
                          'AD · 추천',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      const Text(
                        '원장님 맞춤 매장 파트너',
                        softWrap: true,
                        style: TextStyle(
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
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      '광고 끄기 >',
                      style: TextStyle(
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
                      children: const [
                        Text(
                          '안 쓰는 공기계를 무인 출결 키오스크로!',
                          softWrap: true,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '타사 월 49,000원 기기 대신 광고 없는 올인원 VIP 패스로 24시간 무료 체험해 보세요.',
                          softWrap: true,
                          style: TextStyle(
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
                      onPressed: () {
                        if (bm.isRewardedAdAvailable) {
                          bm.showRewardedAd(
                            onRewarded: () async {
                              await bm.grantTemporaryAdFreeHours(24, includeKiosk: true);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('🎉 24시간 광고 제거 + 무인 키오스크 VIP 패스가 활성화되었습니다!'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                            onFailed: () async {
                              await bm.grantTemporaryAdFreeHours(24, includeKiosk: true);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('🎁 24시간 광고 제거 + 무인 키오스크 VIP 패스가 열렸습니다!'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                          );
                        } else {
                          bm.grantTemporaryAdFreeHours(24, includeKiosk: true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🎁 24시간 광고 제거 + 무인 키오스크 VIP 패스가 열렸습니다!'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFF8FAFC),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(
                        '무료 체험',
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

