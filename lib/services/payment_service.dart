import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class PaymentService {
  late Razorpay _razorpay;
  
  String get _apiKey {
    return dotenv.env['RAZORPAY_API_KEY'] ?? 'rzp_test_SdkCZDmR693stv';
  }

  String get _apiSecret {
    return dotenv.env['RAZORPAY_KEY_SECRET'] ?? 'atQy0HNI07RAP2pRe21aaMHs';
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
    debugPrint('Razorpay SUCCESS: paymentId=${response.paymentId}, orderId=${response.orderId}');
    if (onSuccess != null) onSuccess!(response);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('Razorpay ERROR: code=${response.code}, message=${response.message}');
    if (onFailure != null) onFailure!(response);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('Razorpay EXTERNAL WALLET: ${response.walletName}');
    if (onExternalWallet != null) onExternalWallet!(response);
  }

  /// Creates an order via Razorpay Orders API (test mode only - for production, use backend)
  Future<String?> _createOrder(int amountInPaise) async {
    try {
      final credentials = base64Encode(utf8.encode('$_apiKey:$_apiSecret'));
      final response = await http.post(
        Uri.parse('https://api.razorpay.com/v1/orders'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $credentials',
        },
        body: jsonEncode({
          'amount': amountInPaise,
          'currency': 'INR',
          'receipt': 'receipt_${DateTime.now().millisecondsSinceEpoch}',
        }),
      ).timeout(const Duration(seconds: 15));

      debugPrint('Razorpay Create Order: status=${response.statusCode}, body=${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['id'] as String?;
      } else {
        debugPrint('Razorpay Order Creation Failed: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Razorpay Order Creation Error: $e');
      return null;
    }
  }

  /// Opens Razorpay standard checkout. This shows the full payment UI with
  /// all available methods (Cards, UPI, Netbanking, Wallets).
  /// The SDK handles UPI app detection and intent internally.
  Future<void> openCheckout({
    required double amount,
    required String kitchenName,
    required String userEmail,
    required String userPhone,
    String description = 'Food Order',
    String? upiPackageName, // Ignored — standard checkout handles UPI internally
    Map<String, String>? notes,
  }) async {
    final amountInPaise = (amount * 100).toInt();
    
    // Create an order first (required for proper payment tracking)
    final orderId = await _createOrder(amountInPaise);
    debugPrint('Razorpay: orderId=$orderId, amount=$amountInPaise paise, key=${_apiKey.substring(0, 12)}...');

    var options = <String, dynamic>{
      'key': _apiKey,
      'amount': amountInPaise,
      'name': kitchenName,
      'currency': 'INR',
      'description': description,
      'prefill': {
        'contact': userPhone,
        'email': userEmail,
      },
      'notes': notes ?? {},
      'theme': {
        'color': '#16A34A',
      },
    };

    // Add order_id if successfully created
    if (orderId != null) {
      options['order_id'] = orderId;
    }

    debugPrint('Razorpay options: $options');

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Razorpay open error: $e');
    }
  }

  void dispose() {
    _razorpay.clear();
  }
}
