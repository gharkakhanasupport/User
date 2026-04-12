import 'package:supabase/supabase.dart';
import 'dart:io';

Future<void> main() async {
  final supabase = SupabaseClient('https://juzwzpspsflljnjqpske.supabase.co', 'YOUR_KEY_HERE'); // Oops, I can't easily hardcode the key. I will use the app's env.
}
