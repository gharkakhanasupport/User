import os
import requests
import json
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

USER_DB_URL = os.getenv("USER_DB_URL")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

REDUNDANT_COLUMNS = [
    'first_name', 'last_name', 'address', 'full_name', 'latitude', 'longitude', 
    'address_id', 'avatar_url', 'date_of_birth', 'gender', 
    'notification_preference', 'verification_method', 'temp_otp', 
    'otp_expires_at', 'preferred_cuisine', 'dietary_preferences', 'language'
]

REQUIRED_COLUMNS = [
    'id', 'email', 'name', 'phone', 'profile_image_url', 'role', 'status', 
    'last_name_change', 'last_phone_change', 'last_photo_change', 'updated_at', 'preferred_language', 'default_address_id'
]

def check_users_table():
    print(f"Checking users table at {USER_DB_URL}...")
    
    headers = {
        "apikey": SUPABASE_SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_ROLE_KEY}",
        "Content-Type": "application/json"
    }
    
    # Fetch data to determine schema
    response = requests.get(
        f"{USER_DB_URL}/rest/v1/users?limit=1",
        headers=headers
    )
    
    if response.status_code != 200:
        print(f"Error fetching user data: {response.status_code}")
        print(response.text)
        return

    users = response.json()
    if not users:
        print("No users found in table. Cannot determine schema from data.")
        return

    actual_columns = list(users[0].keys())
    print(f"\nActual columns in users table: {actual_columns}")
    
    # Check for redundant columns
    found_redundant = [col for col in REDUNDANT_COLUMNS if col in actual_columns]
    if found_redundant:
        print(f"\n[WARNING] Found {len(found_redundant)} redundant columns that should be removed:")
        for col in found_redundant:
            print(f"  - {col}")
    else:
        print("\n[SUCCESS] No redundant columns found.")
        
    # Check for required columns
    missing_required = [col for col in REQUIRED_COLUMNS if col not in actual_columns]
    if missing_required:
        print(f"\n[ERROR] Missing {len(missing_required)} required columns:")
        for col in missing_required:
            print(f"  - {col}")
    else:
        print("[SUCCESS] All required columns are present.")

    # Integrity Check: Check for data consistency
    print("\nPerforming Integrity Check...")
    
    # Check NULL names
    if 'name' in actual_columns:
        null_names = requests.get(f"{USER_DB_URL}/rest/v1/users?name=is.null", headers=headers).json()
        if null_names:
            print(f"  - [INFO] Found {len(null_names)} users with NULL names.")
        else:
            print("  - [SUCCESS] No users have NULL names.")

    # Check NULL phones
    if 'phone' in actual_columns:
        null_phones = requests.get(f"{USER_DB_URL}/rest/v1/users?phone=is.null", headers=headers).json()
        if null_phones:
            print(f"  - [INFO] Found {len(null_phones)} users with NULL phones.")
        else:
            print("  - [SUCCESS] No users have NULL phones.")

    # Check NULL photos
    if 'profile_image_url' in actual_columns:
        null_photos = requests.get(f"{USER_DB_URL}/rest/v1/users?profile_image_url=is.null", headers=headers).json()
        if null_photos:
            print(f"  - [INFO] Found {len(null_photos)} users with NULL profile photos.")
        else:
            print("  - [SUCCESS] All users have profile photos.")

    # Check for cross-sync: compare auth.users (via metadata) with public.users
    # This is harder via REST without admin access to auth schema, but we can check if metadata fields exist in public.users
    print("\n[INFO] Schema cleanup will ensure 'name' is the source of truth for display.")

if __name__ == "__main__":
    check_users_table()
