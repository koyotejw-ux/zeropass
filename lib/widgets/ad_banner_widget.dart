import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/monetization_service.dart';
import '../screens/pro_store_screen.dart';
import 'design_system.dart';

class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;
  int? _lastWidth;

  @override
  void initState() {
    super.initState();
    MonetizationService.instance.premiumStatusNotifier.addListener(_onPremiumChanged);
    MonetizationService.instance.addListener(_onPremiumChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentWidth = MediaQuery.sizeOf(context).width.truncate();
    if (_lastWidth != currentWidth && currentWidth > 0) {
      _lastWidth = currentWidth;
      _loadAdaptiveBanner(currentWidth);
    }
  }

  @override
  void dispose() {
    MonetizationService.instance.premiumStatusNotifier.removeListener(_onPremiumChanged);
    MonetizationService.instance.removeListener(_onPremiumChanged);
    _bannerAd?.dispose();
    super.dispose();
  }

  void _onPremiumChanged() {
    if (!mounted) return;
    if (MonetizationService.instance.isAdsRemoved) {
      setState(() {
        _bannerAd?.dispose();
        _bannerAd = null;
        _isBannerLoaded = false;
      });
    } else {
      if (_bannerAd == null && _lastWidth != null && _lastWidth! > 0) {
        _loadAdaptiveBanner(_lastWidth!);
      }
      setState(() {});
    }
  }

  Future<void> _loadAdaptiveBanner(int width) async {
    if (MonetizationService.instance.isAdsRemoved) return;
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    final adUnitId = MonetizationService.bannerAdUnitId;
    if (adUnitId.isEmpty) return;

    // Dispose old ad when screen width or orientation changes
    await _bannerAd?.dispose();
    _bannerAd = null;

    AdSize bannerSize = AdSize.banner;
    try {
      final adaptiveSize = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
      if (adaptiveSize != null) {
        bannerSize = adaptiveSize;
      }
    } catch (_) {
      bannerSize = AdSize.banner;
    }

    if (!mounted) return;

    final ad = BannerAd(
      adUnitId: adUnitId,
      size: bannerSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (loadedAd) {
          if (mounted) {
            setState(() {
              _bannerAd = loadedAd as BannerAd;
              _isBannerLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (failedAd, error) {
          failedAd.dispose();
          if (mounted) {
            setState(() {
              _isBannerLoaded = false;
            });
          }
        },
      ),
    );

    await ad.load();
  }

  @override
  Widget build(BuildContext context) {
    final bm = MonetizationService.instance;

    // 1. 만약 1시간 VIP 체험권(보상형 광고 패스)이 활성화된 상태라면 -> 구독 전환 브릿지 바 노출
    if (bm.isTemporaryPassActive && !bm.isPermanentVip) {
      return Material(
        color: const Color(0xFF0F172A),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProStoreScreen()),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF334155), width: 0.8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt_rounded, size: 15, color: Color(0xFFFBBF24)),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          '광고 없는 VIP 쾌적 모드 체험 중 (${bm.remainingTemporaryPassFormatted})',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '광고 제거 월 1,900원 (한 달) >',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (bm.isAdsRemoved) {
      return const SizedBox.shrink();
    }

    // 2. 일반 무료 모드: 상단 1줄 [광고 → 결제 전환 마이크로 캡슐 바] + 하단 AdMob 배너
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ZeroAdUtilityBar(
          onFreeAdDismiss: () => bm.launchTemporaryPassFlow(context),
          onRemoveAds: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProStoreScreen()),
            );
          },
        ),
        if (_isBannerLoaded && _bannerAd != null)
          Container(
            width: double.infinity,
            height: _bannerAd!.size.height.toDouble(),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200, width: 0.6)),
            ),
            child: SizedBox(
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
          ),
      ],
    );
  }
}

