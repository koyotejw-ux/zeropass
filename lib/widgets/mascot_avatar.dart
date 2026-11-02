import 'dart:io';
import 'package:flutter/material.dart';

/// ZeroPass 공식 3D 펭귄 마스코트(패시) & 회원 사진 겸용 반응형 원형 아바타
/// 
/// - 회원의 등록 사진이 존재하면 원형 프레임에 꽉 차게 표시
/// - 사진이 없으면 투명 배경의 3D 펭귄 마스코트가 몸까지 자연스럽게 원형 안에 마스킹되어 렌더링
/// - 사각 아이콘의 잘림 현상(가로 줄 잘림) 없이 부드러운 곡면 마스킹 보장
class ZeroPassMascotAvatar extends StatelessWidget {
  final double size;
  final String? photoPath;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final bool isLightMode;
  final Widget? badge;
  final double paddingRatio;

  const ZeroPassMascotAvatar({
    super.key,
    required this.size,
    this.photoPath,
    this.border,
    this.boxShadow,
    this.isLightMode = true,
    this.badge,
    this.paddingRatio = 0.0,
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
    } else {
      // 3D 펭귄 마스코트 (얼굴과 상체 프로필이 자연스럽게 원형 안에 마스킹되는 라운드 렌더링)
      final profileImg = Image.asset(
        'assets/icons/mascot_profile.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        alignment: Alignment.center,
      );

      avatarContent = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isLightMode
                ? const [Color(0xFFF0F9FF), Color(0xFFE0F2FE)]
                : const [Color(0xFF1E293B), Color(0xFF0F172A)],
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
        border: border,
        boxShadow: boxShadow,
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
