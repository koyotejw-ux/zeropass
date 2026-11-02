import 'package:flutter/material.dart';

/// Responsive button row/column for dialogs and modal bottom sheets.
/// If available width is tight (< [breakpoint] px, default 300) or buttons cannot fit on one line,
/// it smoothly adapts into a vertical Column of full-width buttons.
/// Otherwise, it aligns them neatly side-by-side in a Row.
class ResponsiveDialogActions extends StatelessWidget {
  final Widget primary;
  final Widget? secondary;
  final Widget? tertiary;
  final double breakpoint;
  final double spacing;
  final bool primaryFirstInColumn;

  const ResponsiveDialogActions({
    super.key,
    required this.primary,
    this.secondary,
    this.tertiary,
    this.breakpoint = 300.0,
    this.spacing = 8.0,
    this.primaryFirstInColumn = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < breakpoint;

        if (isNarrow) {
          final columnChildren = <Widget>[];
          if (primaryFirstInColumn) {
            columnChildren.add(SizedBox(width: double.infinity, child: primary));
            if (secondary != null) {
              columnChildren.add(SizedBox(height: spacing));
              columnChildren.add(SizedBox(width: double.infinity, child: secondary!));
            }
            if (tertiary != null) {
              columnChildren.add(SizedBox(height: spacing));
              columnChildren.add(SizedBox(width: double.infinity, child: tertiary!));
            }
          } else {
            if (tertiary != null) {
              columnChildren.add(SizedBox(width: double.infinity, child: tertiary!));
              columnChildren.add(SizedBox(height: spacing));
            }
            if (secondary != null) {
              columnChildren.add(SizedBox(width: double.infinity, child: secondary!));
              columnChildren.add(SizedBox(height: spacing));
            }
            columnChildren.add(SizedBox(width: double.infinity, child: primary));
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: columnChildren,
          );
        }

        // Wide layout: row of buttons
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (tertiary != null) ...[
              Expanded(child: tertiary!),
              SizedBox(width: spacing),
            ],
            if (secondary != null) ...[
              Expanded(child: secondary!),
              SizedBox(width: spacing),
            ],
            Expanded(
              child: primary,
            ),
          ],
        );
      },
    );
  }
}
