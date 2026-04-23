
import os
from supabase import create_client, Client

url = "https://mwnpwuxrbaousgwgoyco.supabase.co"
key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im13bnB3dXhyYmFvdXNnd2dveWNvIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2Nzk4NTYzNiwiZXhwIjoyMDgzNTYxNjM2fQ.fyLds3C75939r99mRBhT_YLctX8KkC2imYFGnHRSjzc"

supabase: Client = create_client(url, key)

try:
    # Query one row from orders table
    res = supabase.from_("orders").select("*").limit(1).execute()
    if res.data:
        columns = list(res.data[0].keys())
        print(f"Columns in 'orders' table: {columns}")
        if 'delivery_otp' in columns:
            print("[SUCCESS] 'delivery_otp' column found in 'orders' table.")
        else:
            print("[ERROR] 'delivery_otp' column MISSING from 'orders' table.")
    else:
        print("[INFO] No data in 'orders' table to inspect columns. Trying an alternative method...")
        # If no data, we can try to insert and rollback or just use a different approach.
        # But usually there's data. Let's try to get one row even if it's old.
        res = supabase.from_("orders").select("*").limit(1).execute()
        if not res.data:
             print("[ERROR] Could not retrieve any rows to check columns.")
except Exception as e:
    print(f"Error: {e}")
