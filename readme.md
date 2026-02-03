# location-tracker

#### deployment
> you need the supabase CLI or access to a supbase project

- supabase login
#### The .xcconfig file 
The .xcconfig file is something you will have to add locally to you xcode instance  of this project and contains the variables references at build time so that the application knows what the default database endpoint, authenticate tokens and api keys etc.

#### required environment variables:
> you can put the keys in supabase console or in supabase/functions/.env for local development

- `MAPS_API`: your google maps API key with Places API enabled
