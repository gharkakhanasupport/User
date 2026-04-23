-- Migration: Add is_veg column to menu_items and daily_menus
-- This resolves the "column menu_items.is_veg does not exist" error.

-- 1. Update menu_items table
ALTER TABLE menu_items 
ADD COLUMN IF NOT EXISTS is_veg BOOLEAN DEFAULT true;

-- 2. Update daily_menus table
ALTER TABLE daily_menus 
ADD COLUMN IF NOT EXISTS is_veg BOOLEAN DEFAULT true;

-- 3. Update existing records if any
-- (Default value already handles this for new columns, but good to be explicit)
UPDATE menu_items SET is_veg = true WHERE is_veg IS NULL;
UPDATE daily_menus SET is_veg = true WHERE is_veg IS NULL;
