import os
import sys
from supabase import create_client

if len(sys.argv) < 2:
    print("Usage: python check_orders_schema.py <url>")
    exit(1)

url = sys.argv[1]
key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

if not key:
    print("Error: SUPABASE_SERVICE_ROLE_KEY not found in environment.")
    exit(1)

supabase = create_client(url, key)

print(f"Checking orders table at {url}...")
try:
    response = supabase.table("orders").select("*").limit(1).execute()
    if response.data:
        columns = list(response.data[0].keys())
        print(f"Actual columns in orders table: {columns}")
        if 'delivery_otp' in columns:
            print("[SUCCESS] delivery_otp column already exists.")
        else:
            print("[MISSING] delivery_otp column is missing.")
    else:
        print("No data in orders table.")
except Exception as e:
    print(f"Error checking schema: {e}")
