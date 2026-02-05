-- Grant everything to the roles used by the API
GRANT ALL ON TABLE public.locationsvisitednew TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO postgres, anon, authenticated, service_role;

-- Force a cache reload again
NOTIFY pgrst, 'reload schema';