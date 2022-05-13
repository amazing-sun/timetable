import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../utils.dart';
import 'controller.dart';
import 'scroll_physics.dart';

/// "DateTimes can represent time values that are at a distance of at most
/// 100,000,000 days from epoch […]".
const _minPage = -100000000;
const _precisionErrorTolerance = 1e-5;

/// A page view for displaying dates that supports shrink-wrapping in the cross
/// axis.
///
/// A controller has to be provided, either directly via the constructor, or via
/// a [DefaultDateController] above in the widget tree.
class DatePageView extends StatefulWidget {
  const DatePageView({
    final Key? key,
    this.controller,
    this.shrinkWrapInCrossAxis = false,
    required this.builder,
  }) : super(key: key);

  final DateController? controller;
  final bool shrinkWrapInCrossAxis;
  final DateWidgetBuilder builder;

  @override
  _DatePageViewState createState() => _DatePageViewState();
}

class _DatePageViewState extends State<DatePageView> {
  DateController? _controller;
  _MultiDateScrollController? _scrollController;
  final _heights = <int, double>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null && !_controller!.isDisposed) {
      _controller!.date.removeListener(_onDateChanged);
      _scrollController!.dispose();
    }
    _controller = widget.controller ?? DefaultDateController.of(context)!;
    _scrollController = _MultiDateScrollController(_controller!);
    _controller!.date.addListener(_onDateChanged);
  }

  @override
  void dispose() {
    _controller!.date.removeListener(_onDateChanged);
    _scrollController!.dispose();
    super.dispose();
  }

  void _onDateChanged() {
    final datePageValue = _controller!.value;
    final firstPage = datePageValue.page.round();
    final lastPage = datePageValue.page.round() + datePageValue.visibleDayCount;
    _heights.removeWhere((final key, final _) => key < firstPage - 5 || key > lastPage + 5);
  }

  @override
  Widget build(final BuildContext context) {
    Widget child = ValueListenableBuilder<bool>(
      valueListenable: _controller!.map((final it) => it.visibleRange.canScroll),
      builder: (final context, final canScroll, final _) =>
          canScroll ? _buildScrollingChild() : _buildNonScrollingChild(),
    );

    if (widget.shrinkWrapInCrossAxis) {
      child = ValueListenableBuilder<DatePageValue>(
        valueListenable: _controller!,
        builder: (final context, final pageValue, final child) => ImmediateSizedBox(
          heightGetter: () => _getHeight(pageValue),
          child: child!,
        ),
        child: child,
      );
    }
    return child;
  }

  Widget _buildScrollingChild() {
    return Scrollable(
      axisDirection: AxisDirection.right,
      physics: DateScrollPhysics(_controller!.map((final it) => it.visibleRange)),
      controller: _scrollController!,
      viewportBuilder: (final context, final position) {
        return Viewport(
          axisDirection: AxisDirection.right,
          offset: position,
          slivers: [
            ValueListenableBuilder<int>(
              valueListenable: _controller!.map((final it) => it.visibleDayCount),
              builder: (final context, final visibleDayCount, final _) => SliverFillViewport(
                padEnds: false,
                viewportFraction: 1 / visibleDayCount,
                delegate: SliverChildBuilderDelegate(
                  (final context, final index) => _buildPage(context, _minPage + index),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNonScrollingChild() {
    return ValueListenableBuilder<DatePageValue>(
      valueListenable: _controller!,
      builder: (final context, final value, final _) => Row(
        children: [
          for (var i = 0; i < value.visibleDayCount; i++)
            Expanded(child: _buildPage(context, value.page.toInt() + i)),
        ],
      ),
    );
  }

  double _getHeight(final DatePageValue pageValue) {
    double maxHeightFrom(final int page) {
      return page
          .until(page + pageValue.visibleDayCount)
          .map((final it) => _heights[it] ?? 0)
          .max()!;
    }

    final oldMaxHeight = maxHeightFrom(pageValue.page.floor());
    final newMaxHeight = maxHeightFrom(pageValue.page.ceil());
    final t = pageValue.page - pageValue.page.floorToDouble();
    return lerpDouble(oldMaxHeight, newMaxHeight, t)!;
  }

  Widget _buildPage(final BuildContext context, final int page) {
    var child = widget.builder(context, DateTimeTimetable.dateFromPage(page));
    if (widget.shrinkWrapInCrossAxis) {
      child = ImmediateSizeReportingOverflowPage(
        onSizeChanged: (final size) {
          if (_heights[page] == size.height) return;
          _heights[page] = size.height;
          WidgetsBinding.instance.addPostFrameCallback((final _) => setState(() {}));
        },
        child: child,
      );
    }
    return child;
  }
}

class _MultiDateScrollController extends ScrollController {
  _MultiDateScrollController(this.controller)
      : super(initialScrollOffset: controller.value.page) {
    controller.addListener(_listenToController);
  }

  final DateController controller;
  int get visibleDayCount => controller.value.visibleDayCount;

  double get page => position.page;

  void _listenToController() {
    if (hasClients) position.forcePage(controller.value.page);
  }

  @override
  void dispose() {
    controller.removeListener(_listenToController);
    super.dispose();
  }

  @override
  void attach(final ScrollPosition position) {
    assert(
      position is MultiDateScrollPosition,
      '_MultiDateScrollControllers can only be used with '
      'MultiDateScrollPositions.',
    );
    final linkedPosition = position as MultiDateScrollPosition;
    assert(
      linkedPosition.owner == this,
      'MultiDateScrollPosition cannot change controllers once created.',
    );
    super.attach(position);
  }

  @override
  MultiDateScrollPosition createScrollPosition(
    final ScrollPhysics physics,
    final ScrollContext context,
    final ScrollPosition? oldPosition,
  ) {
    return MultiDateScrollPosition(
      this,
      physics: physics,
      context: context,
      initialPage: initialScrollOffset,
      oldPosition: oldPosition,
    );
  }

  @override
  MultiDateScrollPosition get position =>
      super.position as MultiDateScrollPosition;
}

class MultiDateScrollPosition extends ScrollPositionWithSingleContext {
  MultiDateScrollPosition(
    this.owner, {
    required final ScrollPhysics physics,
    required final ScrollContext context,
    required this.initialPage,
    final ScrollPosition? oldPosition,
  }) : super(
          physics: physics,
          context: context,
          initialPixels: null,
          oldPosition: oldPosition,
        );

  final _MultiDateScrollController owner;
  DateController get controller => owner.controller;
  double initialPage;

  double get page => pixelsToPage(pixels);

  @override
  bool applyViewportDimension(final double viewportDimension) {
    final hadViewportDimension = hasViewportDimension;
    final isInitialLayout = !hasPixels || !hadViewportDimension;
    final oldPixels = hasPixels ? pixels : null;
    final page = isInitialLayout ? initialPage : this.page;

    final result = super.applyViewportDimension(viewportDimension);
    final newPixels = pageToPixels(page);
    if (newPixels != oldPixels) {
      correctPixels(newPixels);
      return false;
    }
    return result;
  }

  bool _isApplyingNewDimensions = false;
  @override
  void applyNewDimensions() {
    _isApplyingNewDimensions = true;
    super.applyNewDimensions();
    _isApplyingNewDimensions = false;
  }

  @override
  void goBallistic(final double velocity) {
    if (_isApplyingNewDimensions) {
      assert(velocity == 0);
      return;
    }
    super.goBallistic(velocity);
  }

  @override
  double setPixels(final double newPixels) {
    if (newPixels == pixels) return 0;

    _updateUserScrollDirectionFromDelta(newPixels - pixels);
    final overscroll = super.setPixels(newPixels);
    controller.value = controller.value.copyWith(page: pixelsToPage(pixels));
    return overscroll;
  }

  void forcePage(final double page) => forcePixels(pageToPixels(page));
  @override
  void forcePixels(final double value) {
    if (value == pixels) return;

    _updateUserScrollDirectionFromDelta(value - pixels);
    super.forcePixels(value);
  }

  void _updateUserScrollDirectionFromDelta(final double delta) {
    final direction =
        delta > 0 ? ScrollDirection.forward : ScrollDirection.reverse;
    updateUserScrollDirection(direction);
  }

  double pixelsToPage(final double pixels) =>
      _minPage + pixelDeltaToPageDelta(pixels);
  double pageToPixels(final double page) => pageDeltaToPixelDelta(page - _minPage);

  double pixelDeltaToPageDelta(final double pixels) {
    final result = pixels * owner.visibleDayCount / viewportDimension;
    final closestWholeNumber = result.roundToDouble();
    if ((result - closestWholeNumber).abs() <= _precisionErrorTolerance) {
      return closestWholeNumber;
    }
    return result;
  }

  double pageDeltaToPixelDelta(final double page) =>
      page / owner.visibleDayCount * viewportDimension;

  @override
  void debugFillDescription(final List<String> description) {
    super.debugFillDescription(description);
    description.add('owner: $owner');
  }
}
