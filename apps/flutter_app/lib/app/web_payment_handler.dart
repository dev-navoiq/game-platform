// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/monetization_providers.dart';
import '../core/di/providers.dart';

/// Handles the return from Stripe Checkout on web.
///
/// Checks URL parameters for payment_success/payment_cancelled and
/// verifies the purchase if a session_id is present.
Future<void> handleStripeReturn(WidgetRef ref, BuildContext context) async {
  final uri = Uri.base;
  final sessionId = uri.queryParameters['session_id'];
  final paymentSuccess = uri.queryParameters['payment_success'] == 'true';
  final paymentCancelled = uri.queryParameters['payment_cancelled'] == 'true';

  if (paymentCancelled) {
    // Clean URL and show cancelled message
    _cleanUrl();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment was cancelled'),
        ),
      );
    }
    return;
  }

  if (paymentSuccess && sessionId != null) {
    final paymentService = ref.read(webPaymentServiceProvider);
    if (paymentService == null) return;

    // Show verifying message
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verifying purchase...'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    try {
      final result = await paymentService.verifyPurchase(sessionId);

      // Refresh balance
      ref.invalidate(userProfileProvider);

      // Show result
      if (context.mounted) {
        if (result.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Purchase successful! Gems have been added to your account.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? 'Purchase verification failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error verifying purchase: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    // Clean URL
    _cleanUrl();
  }
}

/// Removes query parameters from the URL without reloading.
void _cleanUrl() {
  final uri = Uri.base;
  final cleanUri = uri.replace(queryParameters: {});
  html.window.history.replaceState(null, '', cleanUri.toString());
}

/// Check if we need to handle a Stripe return.
bool hasStripeReturnParams() {
  final uri = Uri.base;
  return uri.queryParameters.containsKey('session_id') ||
      uri.queryParameters.containsKey('payment_success') ||
      uri.queryParameters.containsKey('payment_cancelled');
}
