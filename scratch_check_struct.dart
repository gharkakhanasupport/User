// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

void main() async {
  final url = 'https://uinictqyoycnwrnggznz.supabase.co/rest/v1/delivery_orders';
  final key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVpbmljdHF5b3ljbndybmdnem56Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTkwMDE3NywiZXhwIjoyMDkxNDc2MTc3fQ.xAjt2itGTh59fQbPcOo1ykO1Kh1g6TfjXXWAIJMoBVU';

  final client = HttpClient();
  try {
    final request = await client.openUrl('OPTIONS', Uri.parse(url));
    request.headers.add('apikey', key);
    request.headers.add('Authorization', 'Bearer $key');
    
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    
    if (response.statusCode == 200) {
      print('Structure of delivery_orders:');
      print(body);
    } else {
      print('Error: ${response.statusCode}');
      print(body);
    }
  } catch (e) {
    print('Failed: $e');
  } finally {
    client.close();
  }
}
