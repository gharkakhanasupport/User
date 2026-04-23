-- Add Industry-Level Columns to users table
-- 1. preferred_language: For localization support
-- 2. default_address_id: For faster checkout/one-click order

DO $$ 
BEGIN
    -- Add preferred_language
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'preferred_language') THEN
        ALTER TABLE users ADD COLUMN preferred_language TEXT DEFAULT 'en';
        COMMENT ON COLUMN users.preferred_language IS 'User preferred language (e.g., en, hi)';
    END IF;

    -- Add default_address_id
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'default_address_id') THEN
        ALTER TABLE users ADD COLUMN default_address_id UUID;
        COMMENT ON COLUMN users.default_address_id IS 'ID of the primary address in saved_addresses table';
    END IF;

    -- Add primary_address (consolidated text for quick access)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'primary_address') THEN
        ALTER TABLE users ADD COLUMN primary_address TEXT;
        COMMENT ON COLUMN users.primary_address IS 'Consolidated text of the primary delivery address';
    END IF;

    -- Initialize existing users
    UPDATE users SET preferred_language = 'en' WHERE preferred_language IS NULL;
END $$;
