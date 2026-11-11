import 'package:flutter/material.dart';

class AppBottomSheet {
  /// Returns responsive horizontal gutter padding for mobile/tablet sheets.
  static EdgeInsets responsiveSheetPadding(BuildContext context, {double vertical = 10.0}) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width < 360 ? 14.0 : 20.0;
    return EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
  }

  /// Returns responsive page padding that centers content up to [maxWidth] on wide screens
  /// while keeping full-viewport scrollability and scrollbar placement on the outer edge.
  static EdgeInsets responsivePagePadding(
    BuildContext context, {
    double maxWidth = 720.0,
    double top = 12.0,
    double bottom = 90.0,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    final minGutter = width < 360 ? 12.0 : 16.0;
    final horizontal = width > maxWidth + minGutter * 2
        ? (width - maxWidth) / 2
        : minGutter;
    return EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom);
  }

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    Widget Function(BuildContext)? footerBuilder,
    bool isScrollControlled = true,
    bool isDismissible = true,
    bool enableDrag = true,
    Color backgroundColor = Colors.white,
    double borderRadius = 24.0,
    double maxHeightRatio = 0.90,
    double maxWidth = 640.0,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (sheetContext) {
        final mediaQuery = MediaQuery.of(sheetContext);
        final systemBottom = mediaQuery.viewPadding.bottom;
        final keyboardBottom = mediaQuery.viewInsets.bottom;
        final effectiveBottomPadding = keyboardBottom > 0 ? keyboardBottom + 16 : systemBottom + 20;

        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: mediaQuery.size.height * maxHeightRatio,
            ),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadius)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((255 * 0.12).round()),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  // Content with optional outer sticky footer
                  if (footerBuilder != null) ...[
                    Flexible(
                      child: builder(sheetContext),
                    ),
                    StickyBottomSheetFooter(
                      backgroundColor: backgroundColor,
                      bottomPadding: effectiveBottomPadding,
                      child: footerBuilder(sheetContext),
                    ),
                  ] else
                    Flexible(
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: effectiveBottomPadding,
                        ),
                        child: builder(sheetContext),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 바텀 시트 하단 액션 버튼을 스크롤과 무관하게 항상 하단에 고정(Sticky)하기 위한 표준 푸터 컨테이너
class StickyBottomSheetFooter extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final double bottomPadding;
  final EdgeInsetsGeometry? padding;

  const StickyBottomSheetFooter({
    super.key,
    required this.child,
    this.backgroundColor = Colors.white,
    this.bottomPadding = 0,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width < 360 ? 14.0 : 20.0;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: const Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 0.9),
        ),
      ),
      padding: padding ?? EdgeInsets.fromLTRB(horizontal, 12, horizontal, bottomPadding),
      child: child,
    );
  }
}

/// 헤더(고정) · 본문(스크롤) · 하단 버튼(스티키 고정) 구조를 제공하는 표준 바텀 시트 레이아웃
class StickyBottomSheetLayout extends StatelessWidget {
  final Widget? header;
  final Widget body;
  final Widget footer;
  final bool scrollBody;
  final Color backgroundColor;
  final EdgeInsetsGeometry? bodyPadding;
  final EdgeInsetsGeometry? footerPadding;

  const StickyBottomSheetLayout({
    super.key,
    this.header,
    required this.body,
    required this.footer,
    this.scrollBody = true,
    this.backgroundColor = Colors.white,
    this.bodyPadding,
    this.footerPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null) header!,
        Flexible(
          fit: FlexFit.loose,
          child: scrollBody
              ? SingleChildScrollView(
                  padding: bodyPadding,
                  child: body,
                )
              : body,
        ),
        StickyBottomSheetFooter(
          backgroundColor: backgroundColor,
          padding: footerPadding,
          child: footer,
        ),
      ],
    );
  }
}
