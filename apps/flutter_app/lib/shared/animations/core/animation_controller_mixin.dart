import 'package:flutter/material.dart';

/// Mixin that simplifies [AnimationController] lifecycle management.
///
/// Provides a primary controller and helper to create additional controllers.
/// All controllers are automatically disposed.
mixin GameAnimationMixin<T extends StatefulWidget> on State<T>, TickerProviderStateMixin<T> {
  final List<AnimationController> _controllers = [];

  /// Creates an [AnimationController] whose lifecycle is managed by this mixin.
  ///
  /// The controller is automatically disposed when the [State] is disposed.
  AnimationController createController({
    required Duration duration,
    Duration? reverseDuration,
    double? value,
    double lowerBound = 0.0,
    double upperBound = 1.0,
  }) {
    final controller = AnimationController(
      duration: duration,
      reverseDuration: reverseDuration,
      value: value,
      lowerBound: lowerBound,
      upperBound: upperBound,
      vsync: this,
    );
    _controllers.add(controller);
    return controller;
  }

  /// Forwards [controller] and returns a [Future] that completes when done.
  Future<void> playForward(AnimationController controller, {double? from}) {
    return controller.forward(from: from);
  }

  /// Reverses [controller] and returns a [Future] that completes when done.
  Future<void> playReverse(AnimationController controller, {double? from}) {
    return controller.reverse(from: from);
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    _controllers.clear();
    super.dispose();
  }
}
