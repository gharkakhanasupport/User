-- Cleanup and Consolidate saved_addresses table
-- 1. Rename full_name to name to match users table
-- 2. Rename phone_number to phone to match users table
-- 3. Drop full_address as it is redundant (concatenated in app)

DO $$ 
BEGIN
    -- Rename full_name to name
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'saved_addresses' AND column_name = 'full_name') THEN
        ALTER TABLE saved_addresses RENAME COLUMN full_name TO name;
    END IF;

    -- Rename phone_number to phone
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'saved_addresses' AND column_name = 'phone_number') THEN
        ALTER TABLE saved_addresses RENAME COLUMN phone_number TO phone;
    END IF;

    -- Drop full_address
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'saved_addresses' AND column_name = 'full_address') THEN
        ALTER TABLE saved_addresses DROP COLUMN full_address;
    END IF;

    -- Drop pincode if it's already in street_address or not needed (optional, keeping for now)
END $$;
