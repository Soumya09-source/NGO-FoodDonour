-- ============================================================
-- Akshaya Ahar Database Schema Migration for Supabase
-- Run this in your Supabase SQL Editor
-- ============================================================

-- Enable pgcrypto extension for secure password hashing and UUID generation
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Donors Table
CREATE TABLE IF NOT EXISTS public.donors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    phone VARCHAR(20) UNIQUE NOT NULL,
    address TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Function Halls Table
CREATE TABLE IF NOT EXISTS public.function_halls (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID REFERENCES public.donors(id) ON DELETE CASCADE,
    hall_name TEXT NOT NULL,
    hall_address TEXT NOT NULL,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. Donations Table
CREATE TABLE IF NOT EXISTS public.donations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donor_id UUID REFERENCES public.donors(id) ON DELETE CASCADE,
    hall_id UUID REFERENCES public.function_halls(id) ON DELETE SET NULL,
    prepared_time TIMESTAMPTZ,
    feeds_count INTEGER DEFAULT 0,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'picked_up', 'delivered', 'cancelled')),
    status_message TEXT DEFAULT 'Waiting for pickup team to accept',
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. Donation Items Table
CREATE TABLE IF NOT EXISTS public.donation_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    donation_id UUID REFERENCES public.donations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    food_type TEXT NOT NULL CHECK (food_type IN ('VEG', 'SWEETS', 'PACKAGED')),
    quantity NUMERIC(10,2) NOT NULL,
    unit VARCHAR(10) NOT NULL CHECK (unit IN ('kg', 'pcs')),
    people_fed INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Indexes for optimal lookup performance
CREATE INDEX IF NOT EXISTS idx_donors_phone ON public.donors(phone);
CREATE INDEX IF NOT EXISTS idx_donations_donor_id ON public.donations(donor_id);
CREATE INDEX IF NOT EXISTS idx_donations_status ON public.donations(status);
CREATE INDEX IF NOT EXISTS idx_donation_items_donation_id ON public.donation_items(donation_id);
CREATE INDEX IF NOT EXISTS idx_function_halls_donor_id ON public.function_halls(donor_id);

-- Enable Row Level Security (RLS)
ALTER TABLE public.donors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.function_halls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.donations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.donation_items ENABLE ROW LEVEL SECURITY;

-- Security Policies (Allow operations via anon / authenticated roles)
DROP POLICY IF EXISTS "Allow anon insert to donors" ON public.donors;
CREATE POLICY "Allow anon insert to donors" ON public.donors
    FOR INSERT TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Allow anon select to donors" ON public.donors;
CREATE POLICY "Allow anon select to donors" ON public.donors
    FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "Allow public insert to function_halls" ON public.function_halls;
CREATE POLICY "Allow public insert to function_halls" ON public.function_halls
    FOR INSERT TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public select to function_halls" ON public.function_halls;
CREATE POLICY "Allow public select to function_halls" ON public.function_halls
    FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "Allow public insert to donations" ON public.donations;
CREATE POLICY "Allow public insert to donations" ON public.donations
    FOR INSERT TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public select to donations" ON public.donations;
CREATE POLICY "Allow public select to donations" ON public.donations
    FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "Allow public update to donations" ON public.donations;
CREATE POLICY "Allow public update to donations" ON public.donations
    FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public insert to donation_items" ON public.donation_items;
CREATE POLICY "Allow public insert to donation_items" ON public.donation_items
    FOR INSERT TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public select to donation_items" ON public.donation_items;
CREATE POLICY "Allow public select to donation_items" ON public.donation_items
    FOR SELECT TO anon, authenticated USING (true);

-- Optional Database Authentication Helper Functions
-- Hashes password using crypt() and blowfish ($2a$)
CREATE OR REPLACE FUNCTION public.register_donor(
    p_name TEXT,
    p_phone TEXT,
    p_address TEXT,
    p_password TEXT
) RETURNS json AS $$
DECLARE
    new_donor public.donors%ROWTYPE;
BEGIN
    INSERT INTO public.donors (name, phone, address, password_hash)
    VALUES (p_name, p_phone, p_address, crypt(p_password, gen_salt('bf', 8)))
    RETURNING * INTO new_donor;

    RETURN json_build_object(
        'id', new_donor.id,
        'name', new_donor.name,
        'phone', new_donor.phone,
        'address', new_donor.address
    );
EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'A donor with this phone number is already registered';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.login_donor(
    p_phone TEXT,
    p_password TEXT
) RETURNS json AS $$
DECLARE
    found_donor public.donors%ROWTYPE;
BEGIN
    SELECT * INTO found_donor
    FROM public.donors
    WHERE phone = p_phone
      AND password_hash = crypt(p_password, password_hash);

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    RETURN json_build_object(
        'id', found_donor.id,
        'name', found_donor.name,
        'phone', found_donor.phone,
        'address', found_donor.address
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Explicit Permissions for Supabase Roles (anon, authenticated, service_role)
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.donors, public.function_halls, public.donations, public.donation_items TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.register_donor TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.login_donor TO anon, authenticated, service_role;

-- 6. Reload PostgREST schema cache so tables are immediately available via REST API
NOTIFY pgrst, 'reload schema';

