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
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white : AppTheme.textPrimary,
          letterSpacing: -0.4,
          height: 1.2,
        );

    final hasTag = showSecondaryTag &&
        member.secondaryTag != null &&
        member.secondaryTag!.isNotEmpty;

    final nameRow = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            member.primaryName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: effectiveNameStyle,
          ),
        ),
        if (hasTag) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFF4F4F5),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              member.secondaryTag!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : AppTheme.textSecondary,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ],
    );

    if (!showGroupName || member.groupName.isEmpty) {
      return nameRow;
    }

    return Column(
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: crossAxisAlignment,
      children: [
        nameRow,
        const SizedBox(height: 3),
        Text(
          member.groupName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFF94A3B8) : AppTheme.textSecondary,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}
