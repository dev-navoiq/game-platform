import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stub implementation for non-web platforms.
/// Does nothing since Stripe web payments only apply to web.
Future<void> handleStripeReturn(WidgetRef ref, BuildContext context) async {
  // No-op on native platforms
}

/// Stub - always returns false on native platforms.
bool hasStripeReturnParams() => false;
