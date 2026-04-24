// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

void main() async {
  final url = 'https://mwnpwuxrbaousgwgoyco.supabase.co/rest/v1/wallet_transactions?select=*&limit=1';
  final key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im13bnB3dXhyYmFvdXNnd2dveWNvIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2Nzk4NTYzNiwiZXhwIjoyMDgzNTYxNjM2fQ.fyLds3C75939r99mRBhT_YLctX8KkC2imYFGnHRSjzc';

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
        print('Columns in wallet_transactions:');
        print(data.first.keys.join(', '));
      } else {
        print('No data in wallet_transactions to inspect columns.');
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
