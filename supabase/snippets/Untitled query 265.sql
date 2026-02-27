CREATE TABLE device_registry (
    -- PK is the deviceID (from your app/location data)
    device_id TEXT PRIMARY KEY, 
    
    -- These link to the questionnaire PKs
    whodas_id UUID UNIQUE REFERENCES whodas_responses(id),
    gcplar_id UUID UNIQUE REFERENCES gcplar_responses(id),
    
    last_seen TIMESTAMPTZ DEFAULT NOW()
);