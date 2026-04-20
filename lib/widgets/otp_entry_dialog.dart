import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 4-digit OTP entry dialog.
/// Returns entered OTP string or null on cancel.
class OtpEntryDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color accent;

  const OtpEntryDialog({
    super.key,
    required this.title,
    required this.subtitle,
    this.accent = const Color(0xFF16A34A),
  });

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    Color accent = const Color(0xFF16A34A),
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => OtpEntryDialog(
        title: title,
        subtitle: subtitle,
        accent: accent,
      ),
    );
  }

  @override
  State<OtpEntryDialog> createState() => _OtpEntryDialogState();
}

class _OtpEntryDialogState extends State<OtpEntryDialog> {
  final _controllers = List.generate(4, (_) => TextEditingController());
  final _nodes = List.generate(4, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();

  void _submit() {
    if (_otp.length == 4) {
      Navigator.of(context).pop(_otp);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.subtitle, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: SizedBox(
                  width: 48,
                  height: 60,
                  child: TextField(
                    controller: _controllers[i],
                    focusNode: _nodes[i],
                    autofocus: i == 0,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: widget.accent,
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: widget.accent.withValues(alpha: 0.05),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: widget.accent.withValues(alpha: 0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: widget.accent, width: 2),
                      ),
                    ),
                    onChanged: (v) {
                      if (v.isNotEmpty && i < 3) {
                        _nodes[i + 1].requestFocus();
                      } else if (v.isEmpty && i > 0) {
                        _nodes[i - 1].requestFocus();
                      }
                      if (_otp.length == 4) {
                        FocusScope.of(context).unfocus();
                      }
                    },
                  ),
                ),
              );
            }),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(backgroundColor: widget.accent),
          child: const Text('Verify', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
