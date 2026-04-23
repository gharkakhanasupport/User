import os
from supabase import create_client

url = 'https://mwnpwuxrbaousgwgoyco.supabase.co'
key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im13bnB3dXhyYmFvdXNnd2dveWNvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc5ODU2MzYsImV4cCI6MjA4MzU2MTYzNn0.dTM9rguaiuHbrr59iPUsM5znDzXhOdRXbPQ11yOfZpM'
supabase = create_client(url, key)

res = supabase.table('saved_addresses').select('*').limit(1).execute()
if res.data:
    print(f"Saved addresses columns: {list(res.data[0].keys())}")
else:
    print("No rows found in saved_addresses table")
