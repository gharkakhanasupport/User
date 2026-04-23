
import os
from supabase import create_client, Client
from dotenv import load_dotenv

def get_unique_statuses():
    load_dotenv()
    
    # User DB
    user_url = os.environ.get("SUPABASE_URL") or 'https://mwnpwuxrbaousgwgoyco.supabase.co'
    user_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    
    # Kitchen DB
    kitchen_url = os.environ.get("KITCHEN_DB_URL") or 'https://yvbjnuobnxekgibfqsmq.supabase.co'
    kitchen_key = os.environ.get("KITCHEN_DB_SERVICE_KEY") or 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl2YmpudW9ibnhla2dpYmZxc21xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUzOTY1NzIsImV4cCI6MjA5MDk3MjU3Mn0.Hf5zPb8urWQq155fUxF7kQIGFb0NyWphdMyeRI83vgk'

    all_user_statuses = set()
    all_kitchen_statuses = set()

    if user_key:
        user_client: Client = create_client(user_url, user_key)
        try:
            res = user_client.from_("orders").select("status").execute()
            for row in res.data:
                all_user_statuses.add(row['status'])
        except Exception as e:
            print(f"User DB Error: {e}")

    kitchen_client: Client = create_client(kitchen_url, kitchen_key)
    try:
        res = kitchen_client.from_("orders").select("status").execute()
        for row in res.data:
            all_kitchen_statuses.add(row['status'])
    except Exception as e:
        print(f"Kitchen DB Error: {e}")

    print("Unique Statuses in User DB:", all_user_statuses)
    print("Unique Statuses in Kitchen DB:", all_kitchen_statuses)

if __name__ == "__main__":
    get_unique_statuses()
