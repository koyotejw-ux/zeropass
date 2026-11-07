import 'package:flutter/material.dart';
import '../models/member.dart';
import '../theme/app_theme.dart';

/// 회원의 순수 이름을 1줄로 단단하고 명료하게 표시하고,
/// 부차적인 코스/프로그램 정보는 시각적 위계를 갖춘 서브 태그 배지로 분리하여
/// 긴 이름으로 인한 2줄 줄바꿈 현상을 원천 방지하는 UX 최적화 위젯
class MemberNameBadge extends StatelessWidget {
  final Member member;
  final TextStyle? nameStyle;
  final bool isDark;
  final bool showSecondaryTag;
  final bool showGroupName;
  final MainAxisSize mainAxisSize;
  final CrossAxisAlignment crossAxisAlignment;

  const MemberNameBadge({
    super.key,
    required this.member,
    this.nameStyle,
    this.isDark = false,
    this.showSecondaryTag = true,
    this.showGroupName = false,
    this.mainAxisSize = MainAxisSize.min,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveNameStyle = nameStyle ??
        TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white : AppTheme.textPrimary,
          letterSpacing: -0.4,
          height: 1.2,
        );

    final hasTag = showSecondaryTag &&
        member.secondaryTag != null &&
        member.secondaryTag!.isNotEmpty;

    final nameWrap = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: [
        Text(
          member.primaryName,
          softWrap: true,
          style: effectiveNameStyle,
        ),
        if (hasTag)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              member.secondaryTag!,
              softWrap: true,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                letterSpacing: -0.2,
              ),
            ),
          ),
      ],
    );

    if (!showGroupName || member.groupName.isEmpty) {
      return nameWrap;
    }

    return Column(
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: crossAxisAlignment,
      children: [
        nameWrap,
        const SizedBox(height: 3),
        Text(
          member.groupName,
          softWrap: true,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFF94A3B8) : AppTheme.textSecondary,
            letterSpacing: -0.2,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}
