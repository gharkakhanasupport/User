import os
import requests
from dotenv import load_dotenv

load_dotenv()

USER_DB_URL = os.getenv("USER_DB_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

def get_table_schema(table_name):
    url = f"{USER_DB_URL}/rest/v1/"
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}"
    }
    try:
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            schema = response.json()
            table_info = schema.get('definitions', {}).get(table_name, {})
            properties = table_info.get('properties', {})
            return list(properties.keys())
        else:
            print(f"Error: {response.status_code}")
            print(response.text)
            return None
    except Exception as e:
        print(f"Exception: {e}")
        return None

if __name__ == "__main__":
    columns = get_table_schema('saved_addresses')
    if columns:
        print(f"Columns in saved_addresses: {columns}")
    else:
        print("Failed to get columns.")
