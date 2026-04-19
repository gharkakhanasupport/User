import requests
import json

KITCHEN_DB_URL = "https://yvbjnuobnxekgibfqsmq.supabase.co"
KITCHEN_DB_SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl2YmpudW9ibnhla2dpYmZxc21xIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTM5NjU3MiwiZXhwIjoyMDkwOTcyNTcyfQ.hSn6Z9Ct1kv6UqoFeTeaMhktKLs_6kns1AEaVN-T9hA"

headers = {
    "apikey": KITCHEN_DB_SERVICE_KEY,
    "Authorization": f"Bearer {KITCHEN_DB_SERVICE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation"
}

# Step 1: Get all kitchens to see current state
print("=== Step 1: Checking current kitchens ===")
r = requests.get(
    f"{KITCHEN_DB_URL}/rest/v1/kitchens?select=id,kitchen_name&limit=5",
    headers=headers
)
print(f"Status: {r.status_code}")
kitchens = r.json()
for k in kitchens:
    print(f"  Kitchen: {k['kitchen_name']} (id: {k['id']})")

# Step 2: Try to add the columns via PATCH on first kitchen (to test if they exist)
# If the columns don't exist, we need to use SQL editor manually
# But we can try using the REST API to update with new fields - if it fails we know columns don't exist
if kitchens:
    test_id = kitchens[0]['id']
    print(f"\n=== Step 2: Testing if subscription columns exist on kitchen {test_id} ===")
    r = requests.get(
        f"{KITCHEN_DB_URL}/rest/v1/kitchens?select=weekly_plan_price&id=eq.{test_id}",
        headers=headers
    )
    if r.status_code == 200:
        print("Columns already exist! No migration needed.")
    else:
        print(f"Columns don't exist yet. Status: {r.status_code}")
        print(f"Error: {r.text}")
        print("\n*** YOU NEED TO RUN THIS SQL IN YOUR SUPABASE DASHBOARD (Kitchen DB) ***")
        print("Go to: https://supabase.com/dashboard -> Kitchen Project -> SQL Editor")
        print("Paste and run this SQL:\n")
        sql = """
ALTER TABLE kitchens ADD COLUMN IF NOT EXISTS weekly_plan_price numeric DEFAULT NULL;
ALTER TABLE kitchens ADD COLUMN IF NOT EXISTS monthly_plan_price numeric DEFAULT NULL;
ALTER TABLE kitchens ADD COLUMN IF NOT EXISTS subscription_menu jsonb DEFAULT NULL;
ALTER TABLE kitchens ADD COLUMN IF NOT EXISTS subscription_benefits jsonb DEFAULT NULL;
"""
        print(sql)
        
        # Also provide SQL for seeding test data
        print("\n-- After adding columns, seed test data for the first kitchen:")
        seed_sql = f"""
UPDATE kitchens 
SET 
    weekly_plan_price = 850,
    monthly_plan_price = 3500,
    subscription_menu = '{{"breakfast": ["Aloo Paratha", "Poha", "Idli Sambhar"], "lunch": ["Rajma Chawal", "Roti Sabzi", "Dal Makhani"], "dinner": ["Paneer Bhurji", "Mixed Veg", "Khichdi"]}}'::jsonb,
    subscription_benefits = '["Free Delivery on all meals", "Skip or Pause anytime", "Weekly Menu updates", "Priority support"]'::jsonb
WHERE id = '{test_id}';
"""
        print(seed_sql)

print("\nDone!")
