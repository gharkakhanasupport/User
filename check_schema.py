import urllib.request
import json

# User DB
USER_URL = "https://mwnpwuxrbaousgwgoyco.supabase.co"
USER_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im13bnB3dXhyYmFvdXNnd2dveWNvIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2Nzk4NTYzNiwiZXhwIjoyMDgzNTYxNjM2fQ.fyLds3C75939r99mRBhT_YLctX8KkC2imYFGnHRSjzc"

# Kitchen DB
KITCHEN_URL = "https://yvbjnuobnxekgibfqsmq.supabase.co"
KITCHEN_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl2YmpudW9ibnhla2dpYmZxc21xIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTM5NjU3MiwiZXhwIjoyMDkwOTcyNTcyfQ.hSn6Z9Ct1kv6UqoFeTeaMhktKLs_6kns1AEaVN-T9hA"

def get_openapi(url, key):
    req = urllib.request.Request(f"{url}/rest/v1/", headers={
        "apikey": key,
        "Authorization": f"Bearer {key}",
    })
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())

print("="*60)
print("USER DB - subscriptions table schema")
print("="*60)
try:
    spec = get_openapi(USER_URL, USER_KEY)
    defs = spec.get("definitions", {})
    
    if "subscriptions" in defs:
        props = defs["subscriptions"].get("properties", {})
        req = defs["subscriptions"].get("required", [])
        print(f"Columns ({len(props)}):")
        for col, info in props.items():
            typ = info.get("type", info.get("format", "unknown"))
            fmt = info.get("format", "")
            desc = info.get("description", "")
            is_req = "REQUIRED" if col in req else "nullable"
            print(f"  - {col}: {typ} ({fmt}) [{is_req}] {desc}")
    else:
        print("NO 'subscriptions' table found!")
        print("Available tables:", list(defs.keys()))
except Exception as e:
    print(f"Error: {e}")

print()
print("="*60)
print("KITCHEN DB - kitchens table schema")
print("="*60)
try:
    spec = get_openapi(KITCHEN_URL, KITCHEN_KEY)
    defs = spec.get("definitions", {})
    
    if "kitchens" in defs:
        props = defs["kitchens"].get("properties", {})
        req = defs["kitchens"].get("required", [])
        print(f"Columns ({len(props)}):")
        for col, info in props.items():
            typ = info.get("type", info.get("format", "unknown"))
            fmt = info.get("format", "")
            desc = info.get("description", "")
            is_req = "REQUIRED" if col in req else "nullable"
            print(f"  - {col}: {typ} ({fmt}) [{is_req}] {desc}")
    else:
        print("NO 'kitchens' table found!")
        
    # Also check for subscription-related tables
    sub_tables = [t for t in defs.keys() if 'sub' in t.lower() or 'plan' in t.lower()]
    if sub_tables:
        print(f"\nSubscription/Plan related tables: {sub_tables}")
        for t in sub_tables:
            props = defs[t].get("properties", {})
            print(f"\n  {t} columns ({len(props)}):")
            for col, info in props.items():
                typ = info.get("type", info.get("format", "unknown"))
                fmt = info.get("format", "")
                print(f"    - {col}: {typ} ({fmt})")
    
    # Show all tables
    print(f"\nAll Kitchen DB tables: {list(defs.keys())}")
except Exception as e:
    print(f"Error: {e}")

print()
print("="*60)
print("USER DB - All tables")
print("="*60)
try:
    spec = get_openapi(USER_URL, USER_KEY)
    defs = spec.get("definitions", {})
    print(f"Tables: {list(defs.keys())}")
except Exception as e:
    print(f"Error: {e}")
