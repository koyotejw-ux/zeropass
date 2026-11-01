import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/monetization_service.dart';

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
    _bannerAd?.dispose();
    super.dispose();
  }

  void _onPremiumChanged() {
    if (MonetizationService.instance.isAdsRemoved && mounted) {
      setState(() {
        _bannerAd?.dispose();
        _bannerAd = null;
        _isBannerLoaded = false;
      });
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
    if (MonetizationService.instance.isAdsRemoved || !_isBannerLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    final adSize = _bannerAd!.size;

    return Container(
      width: double.infinity,
      height: adSize.height.toDouble(),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 0.8)),
      ),
      child: SizedBox(
        width: adSize.width.toDouble(),
        height: adSize.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}

