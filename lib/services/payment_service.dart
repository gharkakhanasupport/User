import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PaymentService {
  late Razorpay _razorpay;
  String get _apiKey {
    return dotenv.env['RAZORPAY_API_KEY'] ?? 'rzp_test_ScbcaPgSgcDyMe';
  }

  void Function(PaymentSuccessResponse)? onSuccess;
  void Function(PaymentFailureResponse)? onFailure;
  void Function(ExternalWalletResponse)? onExternalWallet;

  PaymentService() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    if (onSuccess != null) onSuccess!(response);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (onFailure != null) onFailure!(response);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (onExternalWallet != null) onExternalWallet!(response);
  }

  void openCheckout({
    required double amount,
    required String kitchenName,
    required String userEmail,
    required String userPhone,
    String description = 'Food Order',
    String? upiPackageName,
    Map<String, String>? notes,
  }) {
    var options = {
      'key': _apiKey,
      'amount': (amount * 100).toInt(), // Amount in paise
      'name': kitchenName,
      'currency': 'INR',
      'prefill': {
        'contact': userPhone,
        'email': userEmail,
      },
      'external': {
        'wallets': ['paytm']
      },
      'notes': notes ?? {},
      'theme': {
        'color': '#16A34A'
      }
    };

    // If upiPackageName is provided, it triggers headless UPI intent
    if (upiPackageName != null) {
      options['upi_app_package_name'] = upiPackageName;
      options['method'] = 'upi';
    }

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Razorpay Error: $e');
    }
  }

  void dispose() {
    _razorpay.clear();
  }
}
