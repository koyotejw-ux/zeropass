import 'dart:io';
import 'package:flutter/material.dart';
import '../services/localization_service.dart';

/// 마스코트 펭귄의 감정 표정 (출석률 연동)
enum MascotExpression {
  /// 활짝 웃는 모습 (출석률 70% 이상 또는 완벽 출석)
  laughing,
  /// 잔잔한 미소 (출석률 35% ~ 69% 보통)
  smile,
  /// 눈물 글썽/우는 모습 (출석률 35% 미만 저조)
  crying;

  /// 출석률(0~100)에 따른 감정 상태 판별
  static MascotExpression fromAttendanceRate(num? rate) {
    if (rate == null) return MascotExpression.smile;
    if (rate >= 70) return MascotExpression.laughing;
    if (rate >= 35) return MascotExpression.smile;
    return MascotExpression.crying;
  }

  /// 해당 표정의 에셋 경로
  String get assetPath {
    switch (this) {
      case MascotExpression.laughing:
        return 'assets/icons/mascot_profile_laughing.png';
      case MascotExpression.crying:
        return 'assets/icons/mascot_profile_crying.png';
      case MascotExpression.smile:
        return 'assets/icons/mascot_profile.png';
    }
  }

  /// 해당 감정의 한 줄 설명 / 뱃지 텍스트
  String get label {
    switch (this) {
      case MascotExpression.laughing:
        return LocalizationService.tr('mascot_mood_great');
      case MascotExpression.smile:
        return LocalizationService.tr('mascot_mood_steady');
      case MascotExpression.crying:
        return LocalizationService.tr('mascot_mood_needs_boost');
    }
  }

  /// 해당 감정의 대표 이모지
  String get emoji {
    switch (this) {
      case MascotExpression.laughing:
        return '😄';
      case MascotExpression.smile:
        return '🙂';
      case MascotExpression.crying:
        return '😢';
    }
  }
}

/// ZeroPass 럭셔리 모노그램 & 회원 사진 & 마스코트 반응형 원형 아바타
/// 
/// - 회원의 등록 사진이 존재하면 원형 프레임에 꽉 차게 표시
/// - 사진이 없으면 디폴트로 하이엔드 럭셔리 B2B 모노그램/엠블럼 (Deep Obsidian & Titanium) 렌더링
/// - 이름(name) 전달 시 이니셜 모노그램 자동 추출 표기
/// - showMascot: true 지정 시 귀여운 마스코트 펭귄 표기 지원 (출석률 연동 동적 표정 지원)
class ZeroPassMascotAvatar extends StatelessWidget {
  final double size;
  final String? photoPath;
  final String? name;
  final IconData? icon;
  final bool showMascot;
  final bool useBrandEmblem;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final bool isLightMode;
  final Widget? badge;
  final double paddingRatio;
  final MascotExpression? expression;
  final num? attendanceRate;

  const ZeroPassMascotAvatar({
    super.key,
    required this.size,
    this.photoPath,
    this.name,
    this.icon,
    this.showMascot = true,
    this.useBrandEmblem = false,
    this.border,
    this.boxShadow,
    this.isLightMode = true,
    this.badge,
    this.paddingRatio = 0.0,
    this.expression,
    this.attendanceRate,
  });

  @override
  Widget build(BuildContext context) {
    final hasValidPhoto = photoPath != null &&
        photoPath!.trim().isNotEmpty &&
        File(photoPath!).existsSync();

    Widget avatarContent;

    if (hasValidPhoto) {
      avatarContent = Image.file(
        File(photoPath!),
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    } else if (useBrandEmblem || (name != null && name!.trim().isNotEmpty) || icon != null || !showMascot) {
      // 하이엔드 럭셔리 B2B 미니멀 모노그램 / 엠블럼 (Obsidian Navy & Royal Titanium)
      final effectiveBorder = border ??
          Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1.0,
          );

      Widget innerGraphic;

      if (name != null && name!.trim().isNotEmpty) {
        // 이름의 첫 글자(이니셜) 모노그램
        final initial = name!.trim().characters.first.toUpperCase();
        innerGraphic = Center(
          child: Text(
            initial,
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.42,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.0,
            ),
          ),
        );
      } else if (icon != null) {
        innerGraphic = Center(
          child: Icon(
            icon,
            size: size * 0.46,
            color: Colors.white,
          ),
        );
      } else {
        // 디폴트 ZeroPass 시그니처 럭셔리 엠블럼 "ZP"
        innerGraphic = Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Z',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                  height: 1.0,
                ),
              ),
              Text(
                'P',
                style: TextStyle(
                  color: const Color(0xFF93C5FD), // Subtle soft blue accent
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                  height: 1.0,
                ),
              ),
            ],
          ),
        );
      }

      avatarContent = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: effectiveBorder,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E293B), // Slate Onyx
              Color(0xFF090D16), // Pure Deep Void
            ],
          ),
        ),
        child: innerGraphic,
      );
    } else {
      // 3D 펭귄 마스코트 렌더링 (출석률 연동 동적 감정 표정)
      final effectiveExpr = expression ??
          (attendanceRate != null
              ? MascotExpression.fromAttendanceRate(attendanceRate)
              : MascotExpression.smile);

      final profileImg = Image.asset(
        effectiveExpr.assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        errorBuilder: (_, __, ___) => Image.asset(
          'assets/icons/mascot_profile.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );

      final List<Color> bgGradientColors;
      if (isLightMode) {
        switch (effectiveExpr) {
          case MascotExpression.laughing:
            bgGradientColors = const [Color(0xFFECFDF5), Color(0xFFD1FAE5)];
            break;
          case MascotExpression.smile:
            bgGradientColors = const [Color(0xFFF0F9FF), Color(0xFFE0F2FE)];
            break;
          case MascotExpression.crying:
            bgGradientColors = const [Color(0xFFFFF1F2), Color(0xFFFFE4E6)];
            break;
        }
      } else {
        switch (effectiveExpr) {
          case MascotExpression.laughing:
            bgGradientColors = const [Color(0xFF064E3B), Color(0xFF0F172A)];
            break;
          case MascotExpression.smile:
            bgGradientColors = const [Color(0xFF1E293B), Color(0xFF0F172A)];
            break;
          case MascotExpression.crying:
            bgGradientColors = const [Color(0xFF4C0519), Color(0xFF0F172A)];
            break;
        }
      }

      avatarContent = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: bgGradientColors,
          ),
        ),
        child: paddingRatio > 0
            ? Padding(
                padding: EdgeInsets.all(size * paddingRatio),
                child: profileImg,
              )
            : profileImg,
      );
    }

    final avatarCircle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: hasValidPhoto ? border : null,
        boxShadow: boxShadow ?? [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.06).round()),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: avatarContent,
      ),
    );

    if (badge == null) {
      return avatarCircle;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatarCircle,
        Positioned(
          right: 0,
          bottom: 0,
          child: badge!,
        ),
      ],
    );
  }
}
