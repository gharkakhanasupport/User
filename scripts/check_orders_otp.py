
import os
from supabase import create_client, Client

url = "https://mwnpwuxrbaousgwgoyco.supabase.co"
key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

if not key:
    print("Error: SUPABASE_SERVICE_ROLE_KEY not found in environment.")
    exit(1)

supabase: Client = create_client(url, key)

try:
    # Get columns for orders table
    res = supabase.rpc("get_table_columns", {"table_name": "orders"}).execute()
    columns = [row['column_name'] for row in res.data]
    print(f"Columns in 'orders' table: {columns}")
    
    if 'delivery_otp' in columns:
        print("[SUCCESS] 'delivery_otp' column found in 'orders' table.")
    else:
        print("[ERROR] 'delivery_otp' column MISSING from 'orders' table.")
except Exception as e:
    print(f"Error: {e}")
