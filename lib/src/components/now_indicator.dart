import 'dart:ui';

import 'package:async/async.dart';
import 'package:black_hole_flutter/black_hole_flutter.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../date/controller.dart';
import '../theme.dart';
import '../utils.dart';

/// A widget that displays an indicator at the current date and time.
///
/// The indicator consists of two parts:
///
/// * a small [NowIndicatorShape] at the left side
/// * a horizontal line spanning the whole day
///
/// See also:
///
/// * [NowIndicatorStyle], which defines visual properties for this widget.
/// * [TimetableTheme] (and [TimetableConfig]), which provide styles to
///   descendant Timetable widgets.
class NowIndicator extends StatelessWidget {
  const NowIndicator({
    final Key? key,
    this.style,
    this.child,
  }) : super(key: key);

  final NowIndicatorStyle? style;
  final Widget? child;

  @override
  Widget build(final BuildContext context) {
    return CustomPaint(
      foregroundPainter: _NowIndicatorPainter(
        controller: DefaultDateController.of(context)!,
        style: style ?? TimetableTheme.orDefaultOf(context).nowIndicatorStyle,
        devicePixelRatio: context.mediaQuery.devicePixelRatio,
      ),
      child: child,
    );
  }
}

/// Defines visual properties for [NowIndicator].
///
/// See also:
///
/// * [TimetableThemeData], which bundles the styles for all Timetable widgets.
@immutable
class NowIndicatorStyle {
  factory NowIndicatorStyle(
    final BuildContext context, {
    final NowIndicatorShape? shape,
    final Color? lineColor,
    final double? lineWidth,
  }) {
    final defaultColor = context.theme.colorScheme.onBackground;
    return NowIndicatorStyle.raw(
      shape: shape ?? CircleNowIndicatorShape(color: defaultColor),
      lineColor: lineColor ?? defaultColor,
      lineWidth: lineWidth ?? 1,
    );
  }

  const NowIndicatorStyle.raw({
    required this.shape,
    required this.lineColor,
    required this.lineWidth,
  }) : assert(lineWidth >= 0);

  final NowIndicatorShape shape;
  final Color lineColor;
  final double lineWidth;

  NowIndicatorStyle copyWith({
    final NowIndicatorShape? shape,
    final Color? lineColor,
    final double? lineWidth,
  }) {
    return NowIndicatorStyle.raw(
      shape: shape ?? this.shape,
      lineColor: lineColor ?? this.lineColor,
      lineWidth: lineWidth ?? this.lineWidth,
    );
  }

  @override
  int get hashCode => hashValues(shape, lineColor, lineWidth);
  @override
  bool operator ==(final Object other) {
    return other is NowIndicatorStyle &&
        shape == other.shape &&
        lineColor == other.lineColor &&
        lineWidth == other.lineWidth;
  }
}

// Shapes

/// A shape that is drawn at the left side of the [NowIndicator].
///
/// See also:
///
/// * [CircleNowIndicatorShape], which draws a small circle.
/// * [TriangleNowIndicatorShape], which draws a small triangle.
/// * [EmptyNowIndicatorShape], which draws nothing.
/// * [NowIndicatorStyle], which uses this class.
@immutable
abstract class NowIndicatorShape {
  const NowIndicatorShape();

  void paint(
    final Canvas canvas,
    final Size size,
    final double dateStartOffset,
    final double dateEndOffset,
    final double timeOffset,
  );

  double interpolateSizeBasedOnVisibility(
    final double value,
    final Size size,
    final double dateStartOffset,
    final double dateEndOffset,
  ) {
    final dateWidth = dateEndOffset - dateStartOffset;
    if (dateEndOffset < dateWidth) {
      return lerpDouble(0, value, dateEndOffset / dateWidth)!;
    } else if (dateStartOffset > size.width - dateWidth) {
      return lerpDouble(0, value, (size.width - dateStartOffset) / dateWidth)!;
    } else {
      return value;
    }
  }

  NowIndicatorShape copyWith();

  @override
  int get hashCode;
  @override
  bool operator ==(final Object other);
}

/// A [NowIndicatorShape] that draws nothing.
///
/// See also:
///
/// * [CircleNowIndicatorShape], which draws a small circle.
/// * [TriangleNowIndicatorShape], which draws a small triangle.
class EmptyNowIndicatorShape extends NowIndicatorShape {
  const EmptyNowIndicatorShape();

  @override
  void paint(
    final Canvas canvas,
    final Size size,
    final double dateStartOffset,
    final double dateEndOffset,
    final double timeOffset,
  ) {}

  @override
  EmptyNowIndicatorShape copyWith() => EmptyNowIndicatorShape();

  @override
  int get hashCode => 0;
  @override
  bool operator ==(final Object other) {
    return other is EmptyNowIndicatorShape;
  }
}

/// A [NowIndicatorShape] that draws a small circle.
///
/// See also:
///
/// * [TriangleNowIndicatorShape], which draws a small triangle.
/// * [EmptyNowIndicatorShape], which draws nothing.
class CircleNowIndicatorShape extends NowIndicatorShape {
  CircleNowIndicatorShape({required this.color, this.radius = 4})
      : _paint = Paint()..color = color;

  final Color color;
  final double radius;
  final Paint _paint;

  @override
  void paint(
    final Canvas canvas,
    final Size size,
    final double dateStartOffset,
    final double dateEndOffset,
    final double timeOffset,
  ) {
    canvas.drawCircle(
      Offset(dateStartOffset.coerceAtLeast(0), timeOffset),
      interpolateSizeBasedOnVisibility(
        radius,
        size,
        dateStartOffset,
        dateEndOffset,
      ),
      _paint,
    );
  }

  @override
  CircleNowIndicatorShape copyWith({final Color? color, final double? radius}) {
    return CircleNowIndicatorShape(
      color: color ?? this.color,
      radius: radius ?? this.radius,
    );
  }

  @override
  int get hashCode => hashValues(color, radius);
  @override
  bool operator ==(final Object other) {
    return other is CircleNowIndicatorShape &&
        color == other.color &&
        radius == other.radius;
  }
}

/// A [NowIndicatorShape] that draws a small triangle.
///
/// See also:
///
/// * [TriangleNowIndicatorShape], which draws a small triangle.
/// * [EmptyNowIndicatorShape], which draws nothing.
class TriangleNowIndicatorShape extends NowIndicatorShape {
  TriangleNowIndicatorShape({required this.color, this.size = 8})
      : _paint = Paint()..color = color;

  final Color color;
  final double size;
  final Paint _paint;

  @override
  void paint(
    final Canvas canvas,
    final Size size,
    final double dateStartOffset,
    final double dateEndOffset,
    final double timeOffset,
  ) {
    final actualSize = interpolateSizeBasedOnVisibility(
      this.size,
      size,
      dateStartOffset,
      dateEndOffset,
    );
    final left = dateStartOffset.coerceAtLeast(0);
    canvas.drawPath(
      Path()
        ..moveTo(left, timeOffset - actualSize / 2)
        ..lineTo(left + actualSize, timeOffset)
        ..lineTo(left, timeOffset + actualSize / 2)
        ..close(),
      _paint,
    );
  }

  @override
  TriangleNowIndicatorShape copyWith({final Color? color, final double? size}) {
    return TriangleNowIndicatorShape(
      color: color ?? this.color,
      size: size ?? this.size,
    );
  }

  @override
  int get hashCode => hashValues(color, size);
  @override
  bool operator ==(final Object other) {
    return other is TriangleNowIndicatorShape &&
        color == other.color &&
        size == other.size;
  }
}

// Painter

class _NowIndicatorPainter extends CustomPainter {
  factory _NowIndicatorPainter({
    required final DateController controller,
    required final NowIndicatorStyle style,
    required final double devicePixelRatio,
  }) =>
      _NowIndicatorPainter._(
        controller: controller,
        style: style,
        devicePixelRatio: devicePixelRatio,
        repaintNotifier: ValueNotifier<DateTime>(DateTimeTimetable.now()),
      );
  _NowIndicatorPainter._({
    required this.controller,
    required this.style,
    required this.devicePixelRatio,
    required final ValueNotifier<DateTime> repaintNotifier,
  })  : _paint = Paint()
          ..color = style.lineColor
          ..strokeWidth = style.lineWidth,
        _repaintNotifier = repaintNotifier,
        super(repaint: Listenable.merge([controller, repaintNotifier]));

  final DateController controller;
  final Paint _paint;
  final NowIndicatorStyle style;
  final double devicePixelRatio;

  @override
  void paint(final Canvas canvas, final Size size) {
    _repaint?.cancel();
    _repaint = null;

    final pageValue = controller.value;
    final dateWidth = size.width / pageValue.visibleDayCount;
    final now = DateTimeTimetable.now();
    final temporalXOffset =
        now.copyWith(isUtc: true).atStartOfDay.page - pageValue.page;
    final left = temporalXOffset * dateWidth;
    final right = left + dateWidth;

    // The current date isn't visible so we don't have to paint anything.
    if (right < 0 || left > size.width) return;

    final actualLeft = left.coerceAtLeast(0);
    final actualRight = right.coerceAtMost(size.width);

    final y = now.timeOfDay / 1.days * size.height;
    canvas.drawLine(Offset(actualLeft, y), Offset(actualRight, y), _paint);
    style.shape.paint(canvas, size, left, right, y);

    // Schedule the repaint so that our position has moved at most half a device
    // pixel.
    final maxDistance = 0.5 / devicePixelRatio;
    final delay = 1.days * (maxDistance / size.height);
    _repaint = CancelableOperation.fromFuture(
      Future<void>.delayed(delay).then((final _) {
        // [ChangeNotifier.notifyListeners] is protected, so we use a
        // [ValueNotifier] and always set a different time.
        _repaintNotifier.value = DateTimeTimetable.now();
      }),
    );
  }

  int _activeListenerCount = 0;
  final ValueNotifier<DateTime> _repaintNotifier;
  CancelableOperation<void>? _repaint;

  @override
  void addListener(final VoidCallback listener) {
    super.addListener(listener);
    _activeListenerCount++;
  }

  @override
  void removeListener(final VoidCallback listener) {
    _activeListenerCount--;
    if (_activeListenerCount == 0) {
      _repaint?.cancel();
      _repaint = null;
    }
    super.removeListener(listener);
  }

  @override
  bool shouldRepaint(final _NowIndicatorPainter oldDelegate) =>
      style != oldDelegate.style ||
      devicePixelRatio != oldDelegate.devicePixelRatio;
}
