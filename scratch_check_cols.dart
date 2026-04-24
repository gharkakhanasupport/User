// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

void main() async {
  final url = 'https://uinictqyoycnwrnggznz.supabase.co/rest/v1/delivery_profiles?select=*&limit=1';
  final key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVpbmljdHF5b3ljbndybmdnem56Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTkwMDE3NywiZXhwIjoyMDkxNDc2MTc3fQ.xAjt2itGTh59fQbPcOo1ykO1Kh1g6TfjXXWAIJMoBVU';

  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    request.headers.add('apikey', key);
    request.headers.add('Authorization', 'Bearer $key');
    
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    
    if (response.statusCode == 200) {
      final List data = json.decode(body);
      if (data.isNotEmpty) {
        print('Columns in delivery_orders:');
        print(data.first.keys.join(', '));
      } else {
        print('No data in delivery_orders to inspect columns.');
      }
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
