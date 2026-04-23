import os
import requests
import json
from dotenv import load_dotenv

load_dotenv()

USER_DB_URL = os.getenv("USER_DB_URL")
KITCHEN_DB_URL = os.getenv("KITCHEN_DB_URL")
USER_DB_SERVICE_KEY = os.getenv("USER_DB_SERVICE_KEY")
KITCHEN_DB_SERVICE_KEY = os.getenv("KITCHEN_DB_SERVICE_KEY")

def check_active_orders(user_id):
    user_headers = {
        "apikey": USER_DB_SERVICE_KEY,
        "Authorization": f"Bearer {USER_DB_SERVICE_KEY}",
        "Content-Type": "application/json"
    }
    
    kitchen_headers = {
        "apikey": KITCHEN_DB_SERVICE_KEY,
        "Authorization": f"Bearer {KITCHEN_DB_SERVICE_KEY}",
        "Content-Type": "application/json"
    }

    print(f"Checking orders for user {user_id}...")

    # Fetch from User DB
    user_res = requests.get(
        f"{USER_DB_URL}/rest/v1/orders?customer_id=eq.{user_id}&order=created_at.desc",
        headers=user_headers
    )
    user_orders = user_res.json()

    # Fetch from Kitchen DB
    kitchen_res = requests.get(
        f"{KITCHEN_DB_URL}/rest/v1/orders?customer_id=eq.{user_id}&order=created_at.desc",
        headers=kitchen_headers
    )
    kitchen_orders = kitchen_res.json()

    if isinstance(user_orders, list):
        print(f"\nUser DB Orders: {len(user_orders)}")
        for o in user_orders:
            print(f"  ID: {o.get('id')}, Status: {o.get('status')}, Created: {o.get('created_at')}")
    else:
        print(f"\nUser DB Error: {user_orders}")

    if isinstance(kitchen_orders, list):
        print(f"\nKitchen DB Orders: {len(kitchen_orders)}")
        for o in kitchen_orders:
            print(f"  ID: {o.get('id')}, Status: {o.get('status')}, Created: {o.get('created_at')}")
    else:
        print(f"\nKitchen DB Error: {kitchen_orders}")

if __name__ == "__main__":
    # I'll try to find a user with active orders first
    headers = {
        "apikey": USER_DB_SERVICE_KEY,
        "Authorization": f"Bearer {USER_DB_SERVICE_KEY}"
    }
    res = requests.get(f"{USER_DB_URL}/rest/v1/orders?status=neq.delivered&limit=1", headers=headers)
    orders = res.json()
    if orders:
        check_active_orders(orders[0]['customer_id'])
    else:
        print("No active orders found in User DB.")
