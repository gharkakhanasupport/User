-- Add latitude and longitude to kitchens if they don't exist
ALTER TABLE kitchens ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE kitchens ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;

-- RPC to get kitchens within a radius
CREATE OR REPLACE FUNCTION get_nearby_kitchens(
    user_lat DOUBLE PRECISION,
    user_lng DOUBLE PRECISION,
    radius_km DOUBLE PRECISION
) RETURNS SETOF kitchens AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM kitchens
    WHERE latitude IS NOT NULL 
      AND longitude IS NOT NULL
      AND (
        6371 * acos(
          cos(radians(user_lat)) * cos(radians(latitude)) * 
          cos(radians(longitude) - radians(user_lng)) + 
          sin(radians(user_lat)) * sin(radians(latitude))
        )
      ) <= radius_km
    ORDER BY (
      6371 * acos(
        cos(radians(user_lat)) * cos(radians(latitude)) * 
        cos(radians(longitude) - radians(user_lng)) + 
        sin(radians(user_lat)) * sin(radians(latitude))
      )
    ) ASC;
END;
$$ LANGUAGE plpgsql;
