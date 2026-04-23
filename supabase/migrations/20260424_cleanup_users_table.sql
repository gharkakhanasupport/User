-- Cleanup users table: Remove 16 redundant columns and consolidate naming.
-- Consolidates profile image URLs to 'profile_image_url' for consistency with kitchens table.

DO $$ 
BEGIN
    -- 1. Ensure 'name' and 'profile_image_url' columns exist if they don't already
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'name') THEN
        ALTER TABLE users ADD COLUMN name TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'profile_image_url') THEN
        ALTER TABLE users ADD COLUMN profile_image_url TEXT;
    END IF;

    -- 2. Data Migration: Consolidate names and photos
    -- Migrate names from legacy columns using dynamic SQL to prevent parser errors if columns are missing
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'full_name') THEN
        EXECUTE 'UPDATE users SET name = COALESCE(name, full_name) WHERE name IS NULL OR name = ''''';
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'first_name') AND 
       EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'last_name') THEN
        EXECUTE 'UPDATE users SET name = COALESCE(name, first_name || '' '' || last_name) WHERE name IS NULL OR name = ''''';
    END IF;

    -- Fix any remaining empty names
    UPDATE users SET name = 'Customer' WHERE name IS NULL OR name = '';

    -- Migrate profile images from avatar_url to profile_image_url
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'avatar_url') THEN
        EXECUTE 'UPDATE users SET profile_image_url = COALESCE(profile_image_url, avatar_url) WHERE profile_image_url IS NULL OR profile_image_url = ''''';
    END IF;

    -- 3. Add required management columns for the new User App features
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'role') THEN
        ALTER TABLE users ADD COLUMN role TEXT DEFAULT 'customer';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'last_name_change') THEN
        ALTER TABLE users ADD COLUMN last_name_change TIMESTAMPTZ;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'last_phone_change') THEN
        ALTER TABLE users ADD COLUMN last_phone_change TIMESTAMPTZ;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'last_photo_change') THEN
        ALTER TABLE users ADD COLUMN last_photo_change TIMESTAMPTZ;
    END IF;

    -- 4. Drop redundant columns
    -- We keep profile_image_url and name as the sources of truth.
    -- avatar_url is dropped in favor of profile_image_url for consistency with Kitchen DB.
    ALTER TABLE users 
    DROP COLUMN IF EXISTS first_name,
    DROP COLUMN IF EXISTS last_name,
    DROP COLUMN IF EXISTS full_name,
    DROP COLUMN IF EXISTS avatar_url,
    DROP COLUMN IF EXISTS latitude,
    DROP COLUMN IF EXISTS longitude,
    DROP COLUMN IF EXISTS address_id,
    DROP COLUMN IF EXISTS date_of_birth,
    DROP COLUMN IF EXISTS gender,
    DROP COLUMN IF EXISTS notification_preference,
    DROP COLUMN IF EXISTS verification_method,
    DROP COLUMN IF EXISTS temp_otp,
    DROP COLUMN IF EXISTS otp_expires_at,
    DROP COLUMN IF EXISTS preferred_cuisine,
    DROP COLUMN IF EXISTS dietary_preferences,
    DROP COLUMN IF EXISTS language;

END $$;
