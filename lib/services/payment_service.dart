import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PaymentService {
  late Razorpay _razorpay;
  String get _apiKey {
    try {
      return dotenv.env['RAZORPAY_KEY'] ?? 'rzp_test_SdkCZDmR693stv';
    } catch (_) {
      return 'rzp_test_SdkCZDmR693stv';
    }
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
  }) {
    var options = {
      'key': _apiKey,
      'amount': (amount * 100).toInt(), // Amount in paise
      'name': kitchenName,
      'description': description,
      'prefill': {
        'contact': userPhone,
        'email': userEmail,
      },
      'external': {
        'wallets': ['paytm']
      },
      'theme': {
        'color': '#16A34A'
      }
    };

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
