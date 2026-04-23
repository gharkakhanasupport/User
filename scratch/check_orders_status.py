
import os
from supabase import create_client, Client
from dotenv import load_dotenv

def check_orders():
    load_dotenv()
    
    # User DB
    user_url = os.environ.get("SUPABASE_URL") or 'https://mwnpwuxrbaousgwgoyco.supabase.co'
    user_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    
    # Kitchen DB
    kitchen_url = os.environ.get("KITCHEN_DB_URL") or 'https://yvbjnuobnxekgibfqsmq.supabase.co'
    kitchen_key = os.environ.get("KITCHEN_DB_SERVICE_KEY") or 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl2YmpudW9ibnhla2dpYmZxc21xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUzOTY1NzIsImV4cCI6MjA5MDk3MjU3Mn0.Hf5zPb8urWQq155fUxF7kQIGFb0NyWphdMyeRI83vgk'

    print(f"Checking User DB: {user_url}")
    if user_key:
        user_client: Client = create_client(user_url, user_key)
        try:
            res = user_client.from_("orders").select("id, status, created_at").order("created_at", desc=True).limit(5).execute()
            print("Recent orders in User DB:")
            for row in res.data:
                print(f"  ID: {row['id']}, Status: {row['status']}, Created: {row['created_at']}")
        except Exception as e:
            print(f"  Error: {e}")
    else:
        print("  User service key missing.")

    print(f"\nChecking Kitchen DB: {kitchen_url}")
    kitchen_client: Client = create_client(kitchen_url, kitchen_key)
    try:
        res = kitchen_client.from_("orders").select("id, status, created_at").order("created_at", desc=True).limit(5).execute()
        print("Recent orders in Kitchen DB:")
        for row in res.data:
            print(f"  ID: {row['id']}, Status: {row['status']}, Created: {row['created_at']}")
    except Exception as e:
        print(f"  Error: {e}")

if __name__ == "__main__":
    check_orders()
