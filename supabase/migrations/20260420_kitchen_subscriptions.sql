-- ============================================================
-- Migration: Add Subscription Columns to Kitchens Table
-- Date: 2026-04-20
-- Description: Allows chefs to set weekly/monthly subscription
--              prices, menu items, and benefits for meal plans.
-- Run this in BOTH databases:
--   1. Kitchen DB (yvbjnuobnxekgibfqsmq)
--   2. User DB   (mwnpwuxrbaousgwgoyco)
-- ============================================================

-- Weekly subscription price (e.g. 850 = ₹850 for 7 days)
ALTER TABLE kitchens 
ADD COLUMN IF NOT EXISTS weekly_plan_price numeric DEFAULT NULL;

-- Monthly subscription price (e.g. 3500 = ₹3500 for 30 days)
ALTER TABLE kitchens 
ADD COLUMN IF NOT EXISTS monthly_plan_price numeric DEFAULT NULL;

-- Subscription menu as JSON 
-- Format: {"breakfast": [...], "lunch": [...], "dinner": [...]}
ALTER TABLE kitchens 
ADD COLUMN IF NOT EXISTS subscription_menu jsonb DEFAULT NULL;

-- Subscription benefits as JSON array
-- Format: ["Free Delivery", "Skip anytime", ...]
ALTER TABLE kitchens 
ADD COLUMN IF NOT EXISTS subscription_benefits jsonb DEFAULT NULL;

-- ============================================================
-- KITCHEN DB ONLY: Seed existing kitchen with sample data
-- (Skip this block when running on User DB)
-- ============================================================

UPDATE kitchens 
SET 
    weekly_plan_price = 850,
    monthly_plan_price = 3500,
    subscription_menu = '{
        "breakfast": ["Aloo Paratha", "Poha", "Idli Sambhar"],
        "lunch": ["Rajma Chawal", "Roti Sabzi", "Dal Makhani"],
        "dinner": ["Paneer Bhurji", "Mixed Veg", "Khichdi"]
    }'::jsonb,
    subscription_benefits = '[
        "Free Delivery on all meals",
        "Skip or Pause anytime",
        "Weekly Menu updates",
        "Priority support"
    ]'::jsonb
WHERE kitchen_name = 'Mom''s Magic';
