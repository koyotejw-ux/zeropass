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

  @override
  void initState() {
    super.initState();
    _checkAndLoadBanner();
    MonetizationService.instance.premiumStatusNotifier.addListener(_onPremiumChanged);
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

  void _checkAndLoadBanner() {
    if (MonetizationService.instance.isAdsRemoved) return;
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    final adUnitId = MonetizationService.bannerAdUnitId;
    if (adUnitId.isEmpty) return;

    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isBannerLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) {
            setState(() {
              _isBannerLoaded = false;
            });
          }
        },
      ),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    if (MonetizationService.instance.isAdsRemoved || !_isBannerLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 0.8)),
      ),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
