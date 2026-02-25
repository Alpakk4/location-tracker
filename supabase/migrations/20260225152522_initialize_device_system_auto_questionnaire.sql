
  create table "public"."device_registry" (
    "device_id" text not null,
    "whodas_id" uuid,
    "gcplar_id" uuid,
    "last_seen" timestamp with time zone default now()
      );


alter table "public"."device_registry" enable row level security;


  create table "public"."gcplar_responses" (
    "id" uuid not null default gen_random_uuid(),
    "simple_score_total" integer,
    "completed_at" timestamp with time zone default now(),
    "complex_score_total" double precision
      );


alter table "public"."gcplar_responses" enable row level security;


  create table "public"."whodas_responses" (
    "id" uuid not null default gen_random_uuid(),
    "score_total" integer,
    "completed_at" timestamp with time zone default now()
      );


alter table "public"."whodas_responses" enable row level security;

alter table "public"."locationsvisitednew" drop column "possible_places_distances";

CREATE UNIQUE INDEX device_registry_gcplar_id_key ON public.device_registry USING btree (gcplar_id);

CREATE UNIQUE INDEX device_registry_pkey ON public.device_registry USING btree (device_id);

CREATE UNIQUE INDEX device_registry_whodas_id_key ON public.device_registry USING btree (whodas_id);

CREATE UNIQUE INDEX gcplar_responses_pkey ON public.gcplar_responses USING btree (id);

CREATE UNIQUE INDEX whodas_responses_pkey ON public.whodas_responses USING btree (id);

alter table "public"."device_registry" add constraint "device_registry_pkey" PRIMARY KEY using index "device_registry_pkey";

alter table "public"."gcplar_responses" add constraint "gcplar_responses_pkey" PRIMARY KEY using index "gcplar_responses_pkey";

alter table "public"."whodas_responses" add constraint "whodas_responses_pkey" PRIMARY KEY using index "whodas_responses_pkey";

alter table "public"."device_registry" add constraint "device_registry_gcplar_id_fkey" FOREIGN KEY (gcplar_id) REFERENCES public.gcplar_responses(id) not valid;

alter table "public"."device_registry" validate constraint "device_registry_gcplar_id_fkey";

alter table "public"."device_registry" add constraint "device_registry_gcplar_id_key" UNIQUE using index "device_registry_gcplar_id_key";

alter table "public"."device_registry" add constraint "device_registry_whodas_id_fkey" FOREIGN KEY (whodas_id) REFERENCES public.whodas_responses(id) not valid;

alter table "public"."device_registry" validate constraint "device_registry_whodas_id_fkey";

alter table "public"."device_registry" add constraint "device_registry_whodas_id_key" UNIQUE using index "device_registry_whodas_id_key";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.initialize_new_device()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$DECLARE
    new_whodas_id UUID;
    new_gcplar_id UUID;
BEGIN
    INSERT INTO whodas_responses DEFAULT VALUES 
    RETURNING id INTO new_whodas_id;

    INSERT INTO gcplar_responses DEFAULT VALUES 
    RETURNING id INTO new_gcplar_id;

    NEW.whodas_id := new_whodas_id;
    NEW.gcplar_id := new_gcplar_id;

    RETURN NEW;
END;$function$
;

grant delete on table "public"."device_registry" to "anon";

grant insert on table "public"."device_registry" to "anon";

grant references on table "public"."device_registry" to "anon";

grant select on table "public"."device_registry" to "anon";

grant trigger on table "public"."device_registry" to "anon";

grant truncate on table "public"."device_registry" to "anon";

grant update on table "public"."device_registry" to "anon";

grant delete on table "public"."device_registry" to "authenticated";

grant insert on table "public"."device_registry" to "authenticated";

grant references on table "public"."device_registry" to "authenticated";

grant select on table "public"."device_registry" to "authenticated";

grant trigger on table "public"."device_registry" to "authenticated";

grant truncate on table "public"."device_registry" to "authenticated";

grant update on table "public"."device_registry" to "authenticated";

grant delete on table "public"."device_registry" to "postgres";

grant insert on table "public"."device_registry" to "postgres";

grant references on table "public"."device_registry" to "postgres";

grant select on table "public"."device_registry" to "postgres";

grant trigger on table "public"."device_registry" to "postgres";

grant truncate on table "public"."device_registry" to "postgres";

grant update on table "public"."device_registry" to "postgres";

grant delete on table "public"."device_registry" to "service_role";

grant insert on table "public"."device_registry" to "service_role";

grant references on table "public"."device_registry" to "service_role";

grant select on table "public"."device_registry" to "service_role";

grant trigger on table "public"."device_registry" to "service_role";

grant truncate on table "public"."device_registry" to "service_role";

grant update on table "public"."device_registry" to "service_role";

grant delete on table "public"."gcplar_responses" to "anon";

grant insert on table "public"."gcplar_responses" to "anon";

grant references on table "public"."gcplar_responses" to "anon";

grant select on table "public"."gcplar_responses" to "anon";

grant trigger on table "public"."gcplar_responses" to "anon";

grant truncate on table "public"."gcplar_responses" to "anon";

grant update on table "public"."gcplar_responses" to "anon";

grant delete on table "public"."gcplar_responses" to "authenticated";

grant insert on table "public"."gcplar_responses" to "authenticated";

grant references on table "public"."gcplar_responses" to "authenticated";

grant select on table "public"."gcplar_responses" to "authenticated";

grant trigger on table "public"."gcplar_responses" to "authenticated";

grant truncate on table "public"."gcplar_responses" to "authenticated";

grant update on table "public"."gcplar_responses" to "authenticated";

grant delete on table "public"."gcplar_responses" to "postgres";

grant insert on table "public"."gcplar_responses" to "postgres";

grant references on table "public"."gcplar_responses" to "postgres";

grant select on table "public"."gcplar_responses" to "postgres";

grant trigger on table "public"."gcplar_responses" to "postgres";

grant truncate on table "public"."gcplar_responses" to "postgres";

grant update on table "public"."gcplar_responses" to "postgres";

grant delete on table "public"."gcplar_responses" to "service_role";

grant insert on table "public"."gcplar_responses" to "service_role";

grant references on table "public"."gcplar_responses" to "service_role";

grant select on table "public"."gcplar_responses" to "service_role";

grant trigger on table "public"."gcplar_responses" to "service_role";

grant truncate on table "public"."gcplar_responses" to "service_role";

grant update on table "public"."gcplar_responses" to "service_role";

grant delete on table "public"."whodas_responses" to "anon";

grant insert on table "public"."whodas_responses" to "anon";

grant references on table "public"."whodas_responses" to "anon";

grant select on table "public"."whodas_responses" to "anon";

grant trigger on table "public"."whodas_responses" to "anon";

grant truncate on table "public"."whodas_responses" to "anon";

grant update on table "public"."whodas_responses" to "anon";

grant delete on table "public"."whodas_responses" to "authenticated";

grant insert on table "public"."whodas_responses" to "authenticated";

grant references on table "public"."whodas_responses" to "authenticated";

grant select on table "public"."whodas_responses" to "authenticated";

grant trigger on table "public"."whodas_responses" to "authenticated";

grant truncate on table "public"."whodas_responses" to "authenticated";

grant update on table "public"."whodas_responses" to "authenticated";

grant delete on table "public"."whodas_responses" to "postgres";

grant insert on table "public"."whodas_responses" to "postgres";

grant references on table "public"."whodas_responses" to "postgres";

grant select on table "public"."whodas_responses" to "postgres";

grant trigger on table "public"."whodas_responses" to "postgres";

grant truncate on table "public"."whodas_responses" to "postgres";

grant update on table "public"."whodas_responses" to "postgres";

grant delete on table "public"."whodas_responses" to "service_role";

grant insert on table "public"."whodas_responses" to "service_role";

grant references on table "public"."whodas_responses" to "service_role";

grant select on table "public"."whodas_responses" to "service_role";

grant trigger on table "public"."whodas_responses" to "service_role";

grant truncate on table "public"."whodas_responses" to "service_role";

grant update on table "public"."whodas_responses" to "service_role";


  create policy "allow anonymous inserts"
  on "public"."device_registry"
  as permissive
  for insert
  to public
with check (true);



  create policy "gcplar_policy"
  on "public"."gcplar_responses"
  as permissive
  for select
  to public
using (true);



  create policy "whodas_table_policy"
  on "public"."whodas_responses"
  as permissive
  for select
  to public
using (true);


CREATE TRIGGER auto_generate_questionnaires BEFORE INSERT ON public.device_registry FOR EACH ROW EXECUTE FUNCTION public.initialize_new_device();


