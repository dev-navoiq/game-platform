import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di/monetization_providers.dart';

/// Web-only: create a Stripe Checkout session for [productKey] and navigate
/// the browser to it. Shared by the gem shop and the subscription screen.
///
/// The loading dialog is intentionally left open on success — the page is
/// about to navigate away, so popping it would race the redirect.
Future<void> startStripeCheckout(
  BuildContext context,
  WidgetRef ref,
  String productKey,
) async {
  final paymentService = ref.read(webPaymentServiceProvider);
  if (paymentService == null) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final currentUrl = Uri.base.toString().split('?').first;
    final successUrl =
        '$currentUrl?payment_success=true&session_id={CHECKOUT_SESSION_ID}';
    final cancelUrl = '$currentUrl?payment_cancelled=true';

    final session = await paymentService.createCheckoutSession(
      productKey: productKey,
      successUrl: successUrl,
      cancelUrl: cancelUrl,
    );

    await launchUrl(Uri.parse(session.url), mode: LaunchMode.externalApplication);
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Purchase failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
