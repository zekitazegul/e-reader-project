import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Locks to the first deliberate drag direction, then lets Flutter's scroll
/// position follow the finger and settle on a page with its native physics.
class DirectionalPager extends StatefulWidget {
  const DirectionalPager({
    super.key,
    required this.controller,
    required this.builder,
    this.onPinch,
    this.minPinchScale = .5,
    this.maxPinchScale = 2,
  });

  final PageController controller;
  final Widget Function(Axis axis) builder;
  final ValueChanged<double>? onPinch;
  final double minPinchScale;
  final double maxPinchScale;

  @override
  State<DirectionalPager> createState() => DirectionalPagerState();
}

class DirectionalPagerState extends State<DirectionalPager> {
  Axis axis = Axis.horizontal;
  Drag? drag;
  DragStartDetails? start;
  final updates = <DragUpdateDetails>[];
  DragEndDetails? end;
  bool starting = false;
  int generation = 0;
  Offset movement = Offset.zero;
  Offset origin = Offset.zero;
  bool pinching = false;
  double pinchScale = 1;
  Offset focalPoint = Offset.zero;
  Offset previewOrigin = Offset.zero;
  final pointers = <int>{};

  void alongAxis(Axis requested, VoidCallback action) {
    cancel();
    if (axis == requested) {
      action();
      return;
    }
    setState(() => axis = requested);
    final ticket = generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && generation == ticket) action();
    });
  }

  void cancel() {
    generation++;
    drag?.cancel();
    drag = null;
    start = null;
    end = null;
    updates.clear();
    starting = false;
    movement = Offset.zero;
  }

  @override
  void didUpdateWidget(DirectionalPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) cancel();
  }

  @override
  void dispose() {
    cancel();
    super.dispose();
  }

  DragUpdateDetails axisUpdate(DragUpdateDetails details) {
    final delta = axis == Axis.horizontal ? details.delta.dx : details.delta.dy;
    return DragUpdateDetails(
      sourceTimeStamp: details.sourceTimeStamp,
      delta: axis == Axis.horizontal ? Offset(delta, 0) : Offset(0, delta),
      primaryDelta: delta,
      globalPosition: details.globalPosition,
      localPosition: details.localPosition,
    );
  }

  void finish(DragEndDetails details) {
    final velocity = axis == Axis.horizontal
        ? details.velocity.pixelsPerSecond.dx
        : details.velocity.pixelsPerSecond.dy;
    drag?.end(
      DragEndDetails(
        velocity: Velocity(
          pixelsPerSecond: axis == Axis.horizontal
              ? Offset(velocity, 0)
              : Offset(0, velocity),
        ),
        primaryVelocity: velocity,
        globalPosition: details.globalPosition,
        localPosition: details.localPosition,
      ),
    );
    drag = null;
    start = null;
    end = null;
  }

  void update(DragUpdateDetails details) {
    if (drag != null) {
      drag!.update(axisUpdate(details));
      return;
    }
    if (start == null) return;
    updates.add(details);
    if (starting) return;
    movement = details.globalPosition - origin;
    final dx = movement.dx.abs();
    final dy = movement.dy.abs();
    // Judge the accumulated movement, not a single noisy pointer sample.
    // Require a clear sideways intention; slightly diagonal reading swipes
    // should keep scrolling vertically. The axis stays locked until release.
    final Axis nextAxis;
    if (dx >= 18 && dx > dy * 1.5) {
      nextAxis = Axis.horizontal;
    } else if (dy >= 18 && dy >= dx * .8) {
      nextAxis = Axis.vertical;
    } else {
      return;
    }
    starting = true;
    final ticket = generation;
    void forward() {
      if (!mounted || ticket != generation || !widget.controller.hasClients) {
        return;
      }
      drag = widget.controller.position.drag(start!, () => drag = null);
      for (final movement in updates) {
        drag?.update(axisUpdate(movement));
      }
      updates.clear();
      starting = false;
      if (end != null) finish(end!);
    }

    if (axis == nextAxis) {
      forward();
    } else {
      // Only a changed viewport axis needs a layout frame.
      setState(() => axis = nextAxis);
      WidgetsBinding.instance.addPostFrameCallback((_) => forward());
      WidgetsBinding.instance.scheduleFrame();
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (event) {
      if (pointers.isEmpty) {
        origin = event.position;
        pinching = false;
        pinchScale = 1;
      }
      pointers.add(event.pointer);
    },
    onPointerUp: (event) => pointers.remove(event.pointer),
    onPointerCancel: (event) {
      pointers.remove(event.pointer);
      cancel();
    },
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: (details) {
        cancel();
        focalPoint = details.focalPoint;
        if (details.pointerCount > 1) {
          pinching = true;
          pinchScale = 1;
          previewOrigin = details.localFocalPoint;
        } else if (!pinching) {
          start = DragStartDetails(
            globalPosition: details.focalPoint,
            localPosition: details.localFocalPoint,
            sourceTimeStamp: details.sourceTimeStamp,
          );
        }
      },
      onScaleUpdate: (details) {
        focalPoint = details.focalPoint;
        if (details.pointerCount > 1) {
          if (!pinching) {
            cancel();
            pinching = true;
          }
          setState(() {
            previewOrigin = details.localFocalPoint;
            pinchScale = details.scale.clamp(
              widget.minPinchScale,
              widget.maxPinchScale,
            );
          });
        } else if (!pinching) {
          update(
            DragUpdateDetails(
              delta: details.focalPointDelta,
              globalPosition: details.focalPoint,
              localPosition: details.localFocalPoint,
              sourceTimeStamp: details.sourceTimeStamp,
            ),
          );
        }
      },
      onScaleEnd: (details) {
        if (pinching) {
          if (details.pointerCount < 2) {
            if (details.pointerCount == 0) pinching = false;
            final scale = pinchScale;
            setState(() => pinchScale = 1);
            cancel();
            if (scale != 1) widget.onPinch?.call(scale);
          }
          return;
        }
        if (details.pointerCount > 0) {
          cancel();
          return;
        }
        final finished = DragEndDetails(
          velocity: details.velocity,
          globalPosition: focalPoint,
        );
        if (starting) {
          end = finished;
        } else {
          finish(finished);
        }
      },
      child: ClipRect(
        child: Transform.scale(
          key: const ValueKey('pinch-live-preview'),
          scale: pinchScale,
          alignment: Alignment.topLeft,
          origin: previewOrigin,
          child: widget.builder(axis),
        ),
      ),
    ),
  );
}
