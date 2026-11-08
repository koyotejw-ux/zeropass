import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// ============================================================================
/// [ZeroTokens] 글로벌 핀테크 표준 디자인 시스템 토큰
/// ============================================================================
class ZeroTokens {
  // Spacing Scale (4px 기준 그리드 시스템)
  static const double space2 = 2.0;
  static const double space4 = 4.0;
  static const double space6 = 6.0;
  static const double space8 = 8.0;
  static const double space10 = 10.0;
  static const double space12 = 12.0;
  static const double space14 = 14.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;

  // Corner Radius Scale
  static const double radiusMicro = 4.0;
  static const double radiusBadge = 5.0;
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusCard = 18.0;
  static const double radiusHero = 20.0;
  static const double radiusPill = 999.0;

  // Border & Hairline Width
  static const double hairline = 0.8;
  static const double borderStandard = 1.0;
  static const double borderThick = 1.5;

  // Semantic Colors (High-Contrast & Low-Saturation Micro Pastels Harmonized with Passy Mascot)
  static const Color successBg = Color(0xFFECFDF5);
  static const Color successBorder = Color(0xFFA7F3D0);
  static const Color successText = Color(0xFF059669);

  static const Color dangerBg = Color(0xFFFFF1F2);
  static const Color dangerBorder = Color(0xFFFECDD3);
  static const Color dangerText = Color(0xFFE11D48);

  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color warningBorder = Color(0xFFFDE68A);
  static const Color warningText = Color(0xFFD97706);

  static const Color primaryBg = Color(0xFFEFF6FF);
  static const Color primaryBorder = Color(0xFFBFDBFE);
  static const Color primaryText = Color(0xFF2563EB);

  static const Color neutralBg = Color(0xFFF8FAFC);
  static const Color neutralBorder = Color(0xFFE2E8F0);
  static const Color neutralText = Color(0xFF475569);

  static const Color vipBg = Color(0xFFFEF3C7);
  static const Color vipBorder = Color(0xFFFCD34D);
  static const Color vipText = Color(0xFFB45309);
}

/// ============================================================================
/// [ZeroBadge] 시각적 정보 위계를 완벽히 정돈하는 표준 뱃지 컴포넌트
/// ============================================================================
enum ZeroBadgeVariant {
  success,
  danger,
  warning,
  primary,
  neutral,
  vip,
}

enum ZeroBadgeSize {
  small,  // 10.5pt, 인라인 회원 카드 태그/소속 뱃지
  medium, // 11.5pt, 출결/수납/세무 상태 뱃지
  large,  // 12.5pt, 청구서 메인 상태 뱃지
}

class ZeroBadge extends StatelessWidget {
  final String label;
  final ZeroBadgeVariant variant;
  final ZeroBadgeSize size;
  final IconData? icon;
  final Widget? customLeading;
  final VoidCallback? onTap;
  final bool showDot;
  final double? customFontSize;
  final FontWeight? customFontWeight;

  const ZeroBadge({
    super.key,
    required this.label,
    this.variant = ZeroBadgeVariant.neutral,
    this.size = ZeroBadgeSize.small,
    this.icon,
    this.customLeading,
    this.onTap,
    this.showDot = false,
    this.customFontSize,
    this.customFontWeight,
  });

  // Convenience Factory Constructors
  factory ZeroBadge.success(
    String label, {
    ZeroBadgeSize size = ZeroBadgeSize.small,
    IconData? icon,
    VoidCallback? onTap,
    bool showDot = false,
  }) =>
      ZeroBadge(
        label: label,
        variant: ZeroBadgeVariant.success,
        size: size,
        icon: icon,
        onTap: onTap,
        showDot: showDot,
      );

  factory ZeroBadge.danger(
    String label, {
    ZeroBadgeSize size = ZeroBadgeSize.small,
    IconData? icon,
    VoidCallback? onTap,
    bool showDot = false,
  }) =>
      ZeroBadge(
        label: label,
        variant: ZeroBadgeVariant.danger,
        size: size,
        icon: icon,
        onTap: onTap,
        showDot: showDot,
      );

  factory ZeroBadge.warning(
    String label, {
    ZeroBadgeSize size = ZeroBadgeSize.small,
    IconData? icon,
    VoidCallback? onTap,
    bool showDot = false,
  }) =>
      ZeroBadge(
        label: label,
        variant: ZeroBadgeVariant.warning,
        size: size,
        icon: icon,
        onTap: onTap,
        showDot: showDot,
      );

  factory ZeroBadge.primary(
    String label, {
    ZeroBadgeSize size = ZeroBadgeSize.small,
    IconData? icon,
    VoidCallback? onTap,
    bool showDot = false,
  }) =>
      ZeroBadge(
        label: label,
        variant: ZeroBadgeVariant.primary,
        size: size,
        icon: icon,
        onTap: onTap,
        showDot: showDot,
      );

  factory ZeroBadge.neutral(
    String label, {
    ZeroBadgeSize size = ZeroBadgeSize.small,
    IconData? icon,
    VoidCallback? onTap,
    bool showDot = false,
  }) =>
      ZeroBadge(
        label: label,
        variant: ZeroBadgeVariant.neutral,
        size: size,
        icon: icon,
        onTap: onTap,
        showDot: showDot,
      );

  factory ZeroBadge.vip(
    String label, {
    ZeroBadgeSize size = ZeroBadgeSize.small,
    IconData? icon,
    VoidCallback? onTap,
    bool showDot = false,
  }) =>
      ZeroBadge(
        label: label,
        variant: ZeroBadgeVariant.vip,
        size: size,
        icon: icon,
        onTap: onTap,
        showDot: showDot,
      );

  @override
  Widget build(BuildContext context) {
    final colors = _resolveColors();
    final metrics = _resolveMetrics();

    final hasLeading = showDot || customLeading != null || icon != null;

    Widget labelText = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: customFontSize ?? metrics.fontSize,
        fontWeight: customFontWeight ?? metrics.fontWeight,
        color: colors.text,
        letterSpacing: -0.2,
      ),
    );

    Widget content;
    if (!hasLeading) {
      content = labelText;
    } else {
      content = FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (showDot) ...[
              Container(
                width: metrics.dotSize,
                height: metrics.dotSize,
                decoration: BoxDecoration(
                  color: colors.text,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: metrics.iconSpacing),
            ],
            if (customLeading != null) ...[
              customLeading!,
              SizedBox(width: metrics.iconSpacing),
            ] else if (icon != null) ...[
              Icon(
                icon,
                size: metrics.iconSize,
                color: colors.text,
              ),
              SizedBox(width: metrics.iconSpacing),
            ],
            labelText,
          ],
        ),
      );
    }

    Widget badgeContainer = Container(
      padding: metrics.padding,
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(metrics.radius),
        border: Border.all(color: colors.border, width: ZeroTokens.hairline),
      ),
      child: content,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(metrics.radius),
        child: badgeContainer,
      );
    }

    return badgeContainer;
  }

  _BadgeColors _resolveColors() {
    switch (variant) {
      case ZeroBadgeVariant.success:
        return const _BadgeColors(
          bg: ZeroTokens.successBg,
          border: ZeroTokens.successBorder,
          text: ZeroTokens.successText,
        );
      case ZeroBadgeVariant.danger:
        return const _BadgeColors(
          bg: ZeroTokens.dangerBg,
          border: ZeroTokens.dangerBorder,
          text: ZeroTokens.dangerText,
        );
      case ZeroBadgeVariant.warning:
        return const _BadgeColors(
          bg: ZeroTokens.warningBg,
          border: ZeroTokens.warningBorder,
          text: ZeroTokens.warningText,
        );
      case ZeroBadgeVariant.primary:
        return const _BadgeColors(
          bg: ZeroTokens.primaryBg,
          border: ZeroTokens.primaryBorder,
          text: ZeroTokens.primaryText,
        );
      case ZeroBadgeVariant.vip:
        return const _BadgeColors(
          bg: ZeroTokens.vipBg,
          border: ZeroTokens.vipBorder,
          text: ZeroTokens.vipText,
        );
      case ZeroBadgeVariant.neutral:
        return const _BadgeColors(
          bg: ZeroTokens.neutralBg,
          border: ZeroTokens.neutralBorder,
          text: ZeroTokens.neutralText,
        );
    }
  }

  _BadgeMetrics _resolveMetrics() {
    switch (size) {
      case ZeroBadgeSize.small:
        return const _BadgeMetrics(
          padding: EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          radius: ZeroTokens.radiusBadge,
          iconSize: 11.5,
          dotSize: 5.0,
          iconSpacing: 3.0,
        );
      case ZeroBadgeSize.medium:
        return const _BadgeMetrics(
          padding: EdgeInsets.symmetric(horizontal: 7.5, vertical: 2.5),
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          radius: ZeroTokens.radiusSmall,
          iconSize: 13.0,
          dotSize: 6.0,
          iconSpacing: 4.0,
        );
      case ZeroBadgeSize.large:
        return const _BadgeMetrics(
          padding: EdgeInsets.symmetric(horizontal: 9.0, vertical: 3.5),
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          radius: ZeroTokens.radiusSmall,
          iconSize: 14.5,
          dotSize: 7.0,
          iconSpacing: 5.0,
        );
    }
  }
}

class _BadgeColors {
  final Color bg;
  final Color border;
  final Color text;
  const _BadgeColors({required this.bg, required this.border, required this.text});
}

class _BadgeMetrics {
  final EdgeInsets padding;
  final double fontSize;
  final FontWeight fontWeight;
  final double radius;
  final double iconSize;
  final double dotSize;
  final double iconSpacing;

  const _BadgeMetrics({
    required this.padding,
    required this.fontSize,
    required this.fontWeight,
    required this.radius,
    required this.iconSize,
    required this.dotSize,
    required this.iconSpacing,
  });
}

/// ============================================================================
/// [ZeroButton] 표준화된 터치 타깃과 위계를 갖춘 버튼 컴포넌트
/// ============================================================================
enum ZeroButtonVariant {
  primary,    // 로얄 사파이어 블루 솔리드 CTA
  secondary,  // 헤어라인 아웃라인 버튼
  tint,       // 은은한 컬러 틴트 배경 버튼
  neutral,    // 미색 서브 액션 버튼
  danger,     // 경고/삭제 액션 버튼
  dark,       // 오닉스 블랙 다크 캡슐 액션 버튼
}

enum ZeroButtonSize {
  compact, // height 32px (상단 앱바 액션, 필터 캡슐)
  medium,  // height 38px (회원 카드 내 체크인, 출결 토글)
  large,   // height 44px (바텀시트 보조 버튼, 폼 액션)
  hero,    // height 48px (하단 전역 1순위 솔리드 CTA)
}

class ZeroButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final ZeroButtonVariant variant;
  final ZeroButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool fullWidth;
  final bool isLoading;
  final double? customHeight;
  final double? customRadius;

  const ZeroButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ZeroButtonVariant.primary,
    this.size = ZeroButtonSize.large,
    this.icon,
    this.trailingIcon,
    this.fullWidth = false,
    this.isLoading = false,
    this.customHeight,
    this.customRadius,
  });

  // Convenience Factory Constructors
  factory ZeroButton.primary({
    required String label,
    required VoidCallback? onPressed,
    ZeroButtonSize size = ZeroButtonSize.large,
    IconData? icon,
    IconData? trailingIcon,
    bool fullWidth = false,
    bool isLoading = false,
  }) =>
      ZeroButton(
        label: label,
        onPressed: onPressed,
        variant: ZeroButtonVariant.primary,
        size: size,
        icon: icon,
        trailingIcon: trailingIcon,
        fullWidth: fullWidth,
        isLoading: isLoading,
      );

  factory ZeroButton.secondary({
    required String label,
    required VoidCallback? onPressed,
    ZeroButtonSize size = ZeroButtonSize.large,
    IconData? icon,
    IconData? trailingIcon,
    bool fullWidth = false,
    bool isLoading = false,
  }) =>
      ZeroButton(
        label: label,
        onPressed: onPressed,
        variant: ZeroButtonVariant.secondary,
        size: size,
        icon: icon,
        trailingIcon: trailingIcon,
        fullWidth: fullWidth,
        isLoading: isLoading,
      );

  factory ZeroButton.tint({
    required String label,
    required VoidCallback? onPressed,
    ZeroButtonSize size = ZeroButtonSize.medium,
    IconData? icon,
    IconData? trailingIcon,
    bool fullWidth = false,
    bool isLoading = false,
  }) =>
      ZeroButton(
        label: label,
        onPressed: onPressed,
        variant: ZeroButtonVariant.tint,
        size: size,
        icon: icon,
        trailingIcon: trailingIcon,
        fullWidth: fullWidth,
        isLoading: isLoading,
      );

  factory ZeroButton.compactCapsule({
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    ZeroButtonVariant variant = ZeroButtonVariant.neutral,
  }) =>
      ZeroButton(
        label: label,
        onPressed: onPressed,
        variant: variant,
        size: ZeroButtonSize.compact,
        icon: icon,
        customRadius: ZeroTokens.radiusPill,
      );

  @override
  Widget build(BuildContext context) {
    final effectiveHeight = customHeight ?? _resolveHeight();
    final effectiveRadius = customRadius ?? _resolveRadius();
    final style = _resolveColors();
    final isInteractive = onPressed != null && !isLoading;

    Widget innerContent = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (isLoading) ...[
            SizedBox(
              width: _resolveIconSize(),
              height: _resolveIconSize(),
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                valueColor: AlwaysStoppedAnimation<Color>(style.fg),
              ),
            ),
            const SizedBox(width: 6),
          ] else if (icon != null) ...[
            Icon(icon, size: _resolveIconSize(), color: style.fg),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: _resolveFontSize(),
              fontWeight: _resolveFontWeight(),
              color: style.fg,
              letterSpacing: -0.3,
            ),
          ),
          if (trailingIcon != null && !isLoading) ...[
            const SizedBox(width: 5),
            Icon(trailingIcon, size: _resolveIconSize(), color: style.fg),
          ],
        ],
      ),
    );

    Widget button = Container(
      height: effectiveHeight,
      padding: _resolvePadding(),
      decoration: BoxDecoration(
        color: isInteractive ? style.bg : style.bg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(effectiveRadius),
        border: style.border != null ? Border.all(color: style.border!, width: ZeroTokens.hairline) : null,
        boxShadow: (variant == ZeroButtonVariant.primary && isInteractive) ? AppTheme.buttonShadow : null,
      ),
      child: Center(child: innerContent),
    );

    return InkWell(
      onTap: isInteractive ? onPressed : null,
      borderRadius: BorderRadius.circular(effectiveRadius),
      child: fullWidth ? SizedBox(width: double.infinity, child: button) : button,
    );
  }

  double _resolveHeight() {
    switch (size) {
      case ZeroButtonSize.compact:
        return 32.0;
      case ZeroButtonSize.medium:
        return 38.0;
      case ZeroButtonSize.large:
        return 44.0;
      case ZeroButtonSize.hero:
        return 48.0;
    }
  }

  double _resolveRadius() {
    switch (size) {
      case ZeroButtonSize.compact:
        return ZeroTokens.radiusSmall;
      case ZeroButtonSize.medium:
        return ZeroTokens.radiusMedium;
      case ZeroButtonSize.large:
        return ZeroTokens.radiusMedium;
      case ZeroButtonSize.hero:
        return ZeroTokens.radiusLarge;
    }
  }

  double _resolveFontSize() {
    switch (size) {
      case ZeroButtonSize.compact:
        return 12.0;
      case ZeroButtonSize.medium:
        return 13.5;
      case ZeroButtonSize.large:
        return 14.5;
      case ZeroButtonSize.hero:
        return 15.5;
    }
  }

  FontWeight _resolveFontWeight() {
    switch (size) {
      case ZeroButtonSize.compact:
        return FontWeight.w700;
      case ZeroButtonSize.medium:
        return FontWeight.w700;
      case ZeroButtonSize.large:
        return FontWeight.w700;
      case ZeroButtonSize.hero:
        return FontWeight.w800;
    }
  }

  double _resolveIconSize() {
    switch (size) {
      case ZeroButtonSize.compact:
        return 14.0;
      case ZeroButtonSize.medium:
        return 15.5;
      case ZeroButtonSize.large:
        return 17.0;
      case ZeroButtonSize.hero:
        return 18.0;
    }
  }

  EdgeInsets _resolvePadding() {
    switch (size) {
      case ZeroButtonSize.compact:
        return const EdgeInsets.symmetric(horizontal: 10);
      case ZeroButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 14);
      case ZeroButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 18);
      case ZeroButtonSize.hero:
        return const EdgeInsets.symmetric(horizontal: 22);
    }
  }

  _ButtonStyle _resolveColors() {
    switch (variant) {
      case ZeroButtonVariant.primary:
        return const _ButtonStyle(
          bg: AppTheme.primaryBlue,
          fg: Colors.white,
          border: null,
        );
      case ZeroButtonVariant.secondary:
        return const _ButtonStyle(
          bg: Colors.white,
          fg: AppTheme.textPrimary,
          border: Color(0xFFE2E8F0),
        );
      case ZeroButtonVariant.tint:
        return const _ButtonStyle(
          bg: ZeroTokens.primaryBg,
          fg: ZeroTokens.primaryText,
          border: ZeroTokens.primaryBorder,
        );
      case ZeroButtonVariant.neutral:
        return const _ButtonStyle(
          bg: ZeroTokens.neutralBg,
          fg: Color(0xFF334155),
          border: Color(0xFFE2E8F0),
        );
      case ZeroButtonVariant.danger:
        return const _ButtonStyle(
          bg: ZeroTokens.dangerBg,
          fg: ZeroTokens.dangerText,
          border: ZeroTokens.dangerBorder,
        );
      case ZeroButtonVariant.dark:
        return const _ButtonStyle(
          bg: Color(0xFF0F172A),
          fg: Colors.white,
          border: null,
        );
    }
  }
}

class _ButtonStyle {
  final Color bg;
  final Color fg;
  final Color? border;
  const _ButtonStyle({required this.bg, required this.fg, this.border});
}

/// ============================================================================
/// [ZeroIconBox] 시각적 균형과 정렬을 보장하는 규격화된 아이콘 박스
/// ============================================================================
class ZeroIconBox extends StatelessWidget {
  final IconData icon;
  final double size;
  final double? iconSize;
  final Color? backgroundColor;
  final Color? iconColor;
  final Color? borderColor;
  final double? borderRadius;
  final VoidCallback? onTap;

  const ZeroIconBox({
    super.key,
    required this.icon,
    this.size = 32.0,
    this.iconSize,
    this.backgroundColor,
    this.iconColor,
    this.borderColor,
    this.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? (size * 0.28);
    final effectiveIconSize = iconSize ?? (size * 0.52);

    Widget box = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? ZeroTokens.neutralBg,
        borderRadius: BorderRadius.circular(effectiveRadius),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: ZeroTokens.hairline)
            : null,
      ),
      child: Center(
        child: Icon(
          icon,
          size: effectiveIconSize,
          color: iconColor ?? const Color(0xFF475569),
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(effectiveRadius),
        child: box,
      );
    }
    return box;
  }
}

/// ============================================================================
/// [ZeroCard] 통일된 곡률, 헤어라인 테두리 및 그림자를 갖춘 표준 카드 컴포넌트
/// ============================================================================
class ZeroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final bool hasShadow;
  final VoidCallback? onTap;

  const ZeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(ZeroTokens.space16),
    this.margin,
    this.backgroundColor = Colors.white,
    this.borderColor,
    this.borderRadius = ZeroTokens.radiusLarge,
    this.hasShadow = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? AppTheme.borderSubtle,
          width: ZeroTokens.hairline,
        ),
        boxShadow: hasShadow ? AppTheme.cardShadow : null,
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: card,
      );
    }
    return card;
  }
}

/// ============================================================================
/// [ZeroStatItem] 핵심 비즈니스 KPI 및 출결/청구 통계 블록 컴포넌트
/// ============================================================================
class ZeroStatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? dotColor;
  final Color? valueColor;
  final CrossAxisAlignment alignment;

  const ZeroStatItem({
    super.key,
    required this.label,
    required this.value,
    this.dotColor,
    this.valueColor,
    this.alignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF94A3B8),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: valueColor ?? AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

/// ============================================================================
/// [ZeroFilterChip] 일관된 터치 영역과 선택 피드백을 제공하는 캡슐 필터 칩
/// ============================================================================
class ZeroFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int? count;
  final IconData? icon;

  const ZeroFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.count,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZeroTokens.radiusPill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF09090B) : Colors.white,
            borderRadius: BorderRadius.circular(ZeroTokens.radiusPill),
            border: Border.all(
              color: isSelected ? const Color(0xFF09090B) : const Color(0xFFE4E4E7),
              width: ZeroTokens.hairline,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 13,
                  color: isSelected ? Colors.white : const Color(0xFF71717A),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF52525B),
                  letterSpacing: -0.2,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.22)
                        : const Color(0xFFF4F4F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : const Color(0xFF71717A),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// [ZeroNoticeBanner] 케어 및 시스템 알림 표준 배너 컴포넌트
/// ============================================================================
enum ZeroBannerVariant {
  care,    // 오렌지 안심 케어
  info,    // 블루 시스템 안내
  success, // 그린 완료 안내
  danger,  // 레드 경고 안내
}

class ZeroNoticeBanner extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;
  final ZeroBannerVariant variant;
  final EdgeInsetsGeometry? margin;
  final Widget? trailing;

  const ZeroNoticeBanner({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.variant = ZeroBannerVariant.care,
    this.margin,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final style = _resolveStyle();

    Widget banner = Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: style.border, width: ZeroTokens.hairline),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: style.text),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: style.text,
                    letterSpacing: -0.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: style.text.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ] else if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionLabel!,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: style.text,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 14, color: style.text),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (onAction != null && actionLabel == null) {
      return InkWell(
        onTap: onAction,
        borderRadius: BorderRadius.circular(12),
        child: banner,
      );
    }
    return banner;
  }

  _BannerStyle _resolveStyle() {
    switch (variant) {
      case ZeroBannerVariant.care:
        return const _BannerStyle(
          bg: Color(0xFFFFF7ED),
          border: Color(0xFFFED7AA),
          text: Color(0xFFC2410C),
        );
      case ZeroBannerVariant.info:
        return const _BannerStyle(
          bg: Color(0xFFEFF6FF),
          border: Color(0xFFBFDBFE),
          text: Color(0xFF1D4ED8),
        );
      case ZeroBannerVariant.success:
        return const _BannerStyle(
          bg: Color(0xFFECFDF5),
          border: Color(0xFFA7F3D0),
          text: Color(0xFF047857),
        );
      case ZeroBannerVariant.danger:
        return const _BannerStyle(
          bg: Color(0xFFFEF2F2),
          border: Color(0xFFFECACA),
          text: Color(0xFFDC2626),
        );
    }
  }
}

class _BannerStyle {
  final Color bg;
  final Color border;
  final Color text;
  const _BannerStyle({required this.bg, required this.border, required this.text});
}

/// ============================================================================
/// [ZeroAvatar] 통일된 이니셜 및 색상 위계를 갖춘 표준 아바타 컴포넌트
/// ============================================================================
enum ZeroAvatarSize { small, medium, large }

class ZeroAvatar extends StatelessWidget {
  final String name;
  final ZeroAvatarSize size;
  final Color? backgroundColor;
  final Color? textColor;
  final VoidCallback? onTap;

  const ZeroAvatar({
    super.key,
    required this.name,
    this.size = ZeroAvatarSize.medium,
    this.backgroundColor,
    this.textColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double dimension = _resolveDimension();
    final double fontSize = _resolveFontSize();
    final initial = name.isNotEmpty ? name.substring(0, 1) : '?';

    Widget avatar = Container(
      width: dimension,
      height: dimension,
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0xFFF1F5F9),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE2E8F0), width: ZeroTokens.hairline),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: textColor ?? const Color(0xFF334155),
          ),
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: avatar,
      );
    }
    return avatar;
  }

  double _resolveDimension() {
    switch (size) {
      case ZeroAvatarSize.small:
        return 34.0;
      case ZeroAvatarSize.medium:
        return 42.0;
      case ZeroAvatarSize.large:
        return 52.0;
    }
  }

  double _resolveFontSize() {
    switch (size) {
      case ZeroAvatarSize.small:
        return 13.0;
      case ZeroAvatarSize.medium:
        return 16.0;
      case ZeroAvatarSize.large:
        return 20.0;
    }
  }
}

/// ============================================================================
/// [ZeroAdUtilityBar] 광고 제거 및 오늘 하루 끄기 표준 유틸리티 바
/// ============================================================================
class ZeroAdUtilityBar extends StatelessWidget {
  final VoidCallback onFreeAdDismiss;
  final VoidCallback onRemoveAds;

  const ZeroAdUtilityBar({
    super.key,
    required this.onFreeAdDismiss,
    required this.onRemoveAds,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFF1F5F9), width: ZeroTokens.hairline),
          bottom: BorderSide(color: Color(0xFFF1F5F9), width: ZeroTokens.hairline),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: onFreeAdDismiss,
            borderRadius: BorderRadius.circular(4),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle_fill_rounded, size: 14, color: Color(0xFF2563EB)),
                  SizedBox(width: 4),
                  Text(
                    '오늘 하루 광고 끄기 (무료)',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: onRemoveAds,
            borderRadius: BorderRadius.circular(4),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.workspace_premium_rounded, size: 14, color: Color(0xFFD97706)),
                  SizedBox(width: 4),
                  Text(
                    '광고 제거 월 1,900원 >',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

