"""
Update Kitchen DB: Add subscription columns to the kitchens table.
Tries multiple Supabase SQL execution methods.
"""
import requests
import json

KITCHEN_DB_URL = "https://yvbjnuobnxekgibfqsmq.supabase.co"
KITCHEN_DB_SERVICE_KEY = "<YOUR_KITCHEN_DB_SERVICE_KEY>"
PROJECT_REF = "yvbjnuobnxekgibfqsmq"

headers = {
    "apikey": KITCHEN_DB_SERVICE_KEY,
    "Authorization": f"Bearer {KITCHEN_DB_SERVICE_KEY}",
    "Content-Type": "application/json",
}

SQL_STATEMENTS = [
    "ALTER TABLE kitchens ADD COLUMN IF NOT EXISTS weekly_plan_price numeric DEFAULT NULL",
    "ALTER TABLE kitchens ADD COLUMN IF NOT EXISTS monthly_plan_price numeric DEFAULT NULL",
    "ALTER TABLE kitchens ADD COLUMN IF NOT EXISTS subscription_menu jsonb DEFAULT NULL",
    "ALTER TABLE kitchens ADD COLUMN IF NOT EXISTS subscription_benefits jsonb DEFAULT NULL",
]

def try_method_1():
    """Try using /pg/query endpoint (Supabase v2+)"""
    print("Method 1: Trying /pg/query endpoint...")
    for sql in SQL_STATEMENTS:
        r = requests.post(
            f"{KITCHEN_DB_URL}/pg/query",
            json={"query": sql},
            headers=headers,
        )
        if r.status_code == 200:
            print(f"  OK: {sql[:60]}...")
        else:
            print(f"  Failed ({r.status_code}): {r.text[:100]}")
            return False
    return True

def try_method_2():
    """Try using SQL RPC call"""
    print("Method 2: Trying RPC exec_sql...")
    full_sql = "; ".join(SQL_STATEMENTS)
    r = requests.post(
        f"{KITCHEN_DB_URL}/rest/v1/rpc/exec_sql",
        json={"query": full_sql},
        headers=headers,
    )
    if r.status_code == 200:
        print(f"  OK!")
        return True
    else:
        print(f"  Failed ({r.status_code}): {r.text[:200]}")
        return False

def try_method_3():
    """Try using the dashboard API SQL endpoint"""
    print("Method 3: Trying dashboard SQL query endpoint...")
    full_sql = ";\n".join(SQL_STATEMENTS) + ";"
    
    # Try the Supabase SQL API used by the dashboard
    endpoints = [
        f"{KITCHEN_DB_URL}/rest/v1/rpc/",
        f"https://api.supabase.com/v1/projects/{PROJECT_REF}/database/query",
    ]
    
    for endpoint in endpoints:
        r = requests.post(
            endpoint,
            json={"query": full_sql},
            headers=headers,
        )
        if r.status_code == 200:
            print(f"  OK via {endpoint}!")
            return True
        else:
            print(f"  Failed at {endpoint}: {r.status_code}")
    return False

def try_method_4_patch():
    """Try PATCH with the new columns - if they exist, this will work"""
    print("Method 4: Testing if columns already exist via SELECT...")
    r = requests.get(
        f"{KITCHEN_DB_URL}/rest/v1/kitchens?select=weekly_plan_price&limit=1",
        headers=headers,
    )
    if r.status_code == 200:
        print("  Columns ALREADY EXIST! No migration needed.")
        return True
    else:
        print(f"  Columns do NOT exist yet. Status: {r.status_code}")
        return False

# Try all methods
print("=" * 60)
print("Kitchen DB Schema Update: Adding Subscription Columns")
print("=" * 60)

if try_method_4_patch():
    print("\n>>> SUCCESS: Columns already exist.")
elif try_method_1():
    print("\n>>> SUCCESS via Method 1")
elif try_method_2():
    print("\n>>> SUCCESS via Method 2")
elif try_method_3():
    print("\n>>> SUCCESS via Method 3")
else:
    print("\n" + "=" * 60)
    print("MANUAL ACTION REQUIRED!")
    print("=" * 60)
    print()
    print("None of the automated methods worked.")
    print("Please go to your Supabase Dashboard for the Kitchen DB:")
    print(f"  https://supabase.com/dashboard/project/{PROJECT_REF}/sql/new")
    print()
    print("Copy and paste the following SQL, then click 'Run':")
    print()
    print("-" * 60)
    sql = """
-- Add subscription columns to kitchens table
-- These allow chefs to set their own subscription pricing

ALTER TABLE kitchens 
ADD COLUMN IF NOT EXISTS weekly_plan_price numeric DEFAULT NULL;

ALTER TABLE kitchens 
ADD COLUMN IF NOT EXISTS monthly_plan_price numeric DEFAULT NULL;

ALTER TABLE kitchens 
ADD COLUMN IF NOT EXISTS subscription_menu jsonb DEFAULT NULL;

ALTER TABLE kitchens 
ADD COLUMN IF NOT EXISTS subscription_benefits jsonb DEFAULT NULL;

-- Seed test data for the existing kitchen (Mom's Magic)
UPDATE kitchens 
SET 
    weekly_plan_price = 850,
    monthly_plan_price = 3500,
    subscription_menu = '{"breakfast": ["Aloo Paratha", "Poha", "Idli Sambhar"], "lunch": ["Rajma Chawal", "Roti Sabzi", "Dal Makhani"], "dinner": ["Paneer Bhurji", "Mixed Veg", "Khichdi"]}'::jsonb,
    subscription_benefits = '["Free Delivery on all meals", "Skip or Pause anytime", "Weekly Menu updates", "Priority support"]'::jsonb
WHERE kitchen_name = 'Mom''s Magic';
"""
    print(sql)
    print("-" * 60)

# Also check if we also need to update the User DB kitchens table (mirror)
print("\n--- Checking User DB kitchens table ---")
USER_DB_URL = "https://mwnpwuxrbaousgwgoyco.supabase.co"
USER_DB_SERVICE_KEY = "<YOUR_USER_DB_SERVICE_KEY>"

user_headers = {
    "apikey": USER_DB_SERVICE_KEY,
    "Authorization": f"Bearer {USER_DB_SERVICE_KEY}",
    "Content-Type": "application/json",
}

r = requests.get(
    f"{USER_DB_URL}/rest/v1/kitchens?select=weekly_plan_price&limit=1",
    headers=user_headers,
)
if r.status_code == 200:
    print("  User DB kitchens table already has subscription columns.")
else:
    print(f"  User DB kitchens table also needs the same columns.")
    print(f"  Go to: https://supabase.com/dashboard/project/mwnpwuxrbaousgwgoyco/sql/new")
    print(f"  And run the same ALTER TABLE statements above.")

print("\nDone!")
