-- Add missing 'role' column to users table
-- Required for the User App's profile management and signup flows.

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'role') THEN
        ALTER TABLE users ADD COLUMN role TEXT DEFAULT 'customer';
        COMMENT ON COLUMN users.role IS 'User role (e.g., customer, guest)';
    END IF;

    -- Ensure 'name' is initialized for all users if it was missed
    UPDATE users SET name = 'Customer' WHERE name IS NULL OR name = '';
    
    -- Ensure 'role' is initialized for existing users
    UPDATE users SET role = 'customer' WHERE role IS NULL OR role = '';
END $$;
