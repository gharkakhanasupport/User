import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/localization.dart';

class ErrorHandler {
  /// Maps various technical error types to user-friendly localized messages.
  static String getFriendlyMessage(BuildContext context, dynamic error) {
    if (error == null) return AppLocalizations.of(context, 'error_default');

    // 1. Handle Supabase Auth Exceptions
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('invalid login credentials') || msg.contains('invalid credentials')) {
        return AppLocalizations.of(context, 'error_invalid_credentials');
      }
      if (msg.contains('email not confirmed')) {
        return AppLocalizations.of(context, 'error_auth_generic'); // Or a specific "Verify Email" string
      }
      if (msg.contains('too many requests') || msg.contains('rate limit')) {
        return AppLocalizations.of(context, 'error_db');
      }
      return error.message; // Auth messages are usually okay, but we can wrap them
    }

    // 2. Handle Network & Connection Errors
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('network') || 
        errorStr.contains('socketexception') || 
        errorStr.contains('failed host lookup') ||
        errorStr.contains('connection failed')) {
      return AppLocalizations.of(context, 'error_network');
    }

    if (errorStr.contains('timeout')) {
      return AppLocalizations.of(context, 'error_timeout');
    }

    // 3. Handle Database / Postgrest Exceptions
    if (errorStr.contains('postgrestexception')) {
      return AppLocalizations.of(context, 'error_db');
    }

    // 4. Handle Permission Errors
    if (errorStr.contains('permission') || errorStr.contains('denied')) {
      return AppLocalizations.of(context, 'error_default');
    }

    // 5. Default Fallback
    return AppLocalizations.of(context, 'error_default');
  }

  /// Displays a graceful, non-scary error snackbar.
  static void showGracefulError(BuildContext context, dynamic error) {
    final message = getFriendlyMessage(context, error);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.redAccent.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: AppLocalizations.of(context, 'confirm').toUpperCase(),
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}
