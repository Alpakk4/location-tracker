SET session_replication_role = replica;

--
-- PostgreSQL database dump
--

-- \restrict LTbopz0pI2wZpNsgfDVRZk9sdgbLMdZ4LKoJpzuU2hoqEpbO6nymEB908QAoFUN

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Data for Name: audit_log_entries; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: custom_oauth_providers; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: flow_state; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: users; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: identities; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: instances; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: oauth_clients; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: sessions; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: mfa_amr_claims; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: mfa_factors; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: mfa_challenges; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: oauth_authorizations; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: oauth_client_states; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: oauth_consents; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: one_time_tokens; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: refresh_tokens; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: sso_providers; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: saml_providers; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: saml_relay_states; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: sso_domains; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: device_registry; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."device_registry" ("device_id", "whodas_id", "gcplar_id", "last_seen", "auth_uid") VALUES
	('A001', 'ae18d3e2-b745-4d25-aee1-6d005039abbd', 'e77076d8-33cf-4b6c-b81f-7b4290d598ab', '2026-03-16 10:49:59.762346+00', NULL);


--
-- Data for Name: diaries; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: diary_journeys; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: locationsvisitednew; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."locationsvisitednew" ("entryid", "created_at", "latitude", "longitude", "deviceid", "placeid", "closest_place", "primary_type", "other_types", "position_from_home", "motion_type", "horizontal_accuracy", "possible_primary_types", "distance_user_to_place", "possible_places_distances", "place_category") VALUES
	('aeb0adc0-ed30-45f7-9d46-2cd4e3da2f63', '2026-02-06 13:32:36.40137+00', 51.53224, -0.10581, 'test-MAC', '5095b3d00470f57ffc9801d8442335f3f5958731b487aa3c98588b172b17b779', 'Angel Station', 'Unknown', '{point_of_interest,establishment}', '{"bearing": 19.43, "distance": 2846.6}', '{"motion": "cycling", "confidence": "medium"}', NULL, '{}', NULL, NULL, NULL),
	('8b085e63-d10f-40be-a27b-1156fab70c28', '2026-02-06 13:32:43.661549+00', 51.53227, -0.10586, 'test-MAC', '5095b3d00470f57ffc9801d8442335f3f5958731b487aa3c98588b172b17b779', 'Angel Station', 'Unknown', '{point_of_interest,establishment}', '{"bearing": 19.34, "distance": 2848.59}', '{"motion": "cycling", "confidence": "medium"}', NULL, '{}', NULL, NULL, NULL),
	('10a95590-e518-41ba-a544-c7594b8167aa', '2026-02-06 13:33:08.132168+00', 51.53227, -0.10594, 'test-MAC', '5095b3d00470f57ffc9801d8442335f3f5958731b487aa3c98588b172b17b779', 'Angel Station', 'Unknown', '{point_of_interest,establishment}', '{"bearing": 19.24, "distance": 2846.76}', '{"motion": "cycling", "confidence": "high"}', NULL, '{}', NULL, NULL, NULL),
	('74418800-f3f2-4a3a-81e3-f8daa08100da', '2026-02-06 13:34:28.76573+00', 51.53287107874267, -0.10588393177048537, 'test-MAC', '5095b3d00470f57ffc9801d8442335f3f5958731b487aa3c98588b172b17b779', 'Angel Station', 'Unknown', '{point_of_interest,establishment}', '{"bearing": 18.88, "distance": 2911.2}', '{"motion": "cycling", "confidence": "high"}', NULL, '{}', NULL, NULL, NULL),
	('3a2932c6-18d0-4f5e-afe5-c41ff2f00e2c', '2026-02-06 13:36:37.760741+00', 51.532377197168394, -0.10606632197454202, 'test-MAC', '5095b3d00470f57ffc9801d8442335f3f5958731b487aa3c98588b172b17b779', 'Angel Station', 'Unknown', '{point_of_interest,establishment}', '{"bearing": 18.99, "distance": 2855.16}', '{"motion": "cycling", "confidence": "high"}', NULL, '{}', NULL, NULL, NULL),
	('acc6d74d-0a71-4315-a982-e20701da20be', '2026-02-06 13:39:45.871436+00', 51.532377197168394, -0.10606632197454202, 'test-MAC', '5095b3d00470f57ffc9801d8442335f3f5958731b487aa3c98588b172b17b779', 'Angel Station', 'Unknown', '{point_of_interest,establishment}', '{"bearing": 18.99, "distance": 2855.16}', '{"motion": "cycling", "confidence": "high"}', NULL, '{}', NULL, NULL, NULL),
	('2bbd920e-acce-4553-a73e-e39e499ddd58', '2026-02-06 13:47:29.403305+00', 51.510056, 0.134194, 'test-MAC', 'Unknown', 'Unknown', 'Unknown', '{}', '{"bearing": 89.19, "distance": 17558.73}', '{"motion": "cycling", "confidence": "high"}', NULL, '{}', NULL, NULL, NULL),
	('df1101f2-e5b3-4a70-a1af-b9c285807022', '2026-02-06 13:52:36.131288+00', 51.51019903049816, -0.13416029155694922, 'test-MAC', '9c842c55b9076cc04f4eeffb3a61407be6b7d0981f0b42d6dc87108ba0735bea', 'Piccadilly Circus', 'subway_station', '{subway_station,transit_station,point_of_interest,establishment}', '{"bearing": 282.97, "distance": 1041.05}', '{"motion": "still", "confidence": "high"}', NULL, '{}', NULL, NULL, NULL),
	('a40905a2-52bc-4f61-bfee-d98911a16f6c', '2026-02-09 13:24:39.975127+00', 19.435478, -99.1364789, 'Test-MAC', '1294c40f99dc319b954f4f8bf7d70996a6dd844e167ae6ab337e2056e569eb4e', 'Metro Allende', 'Unknown', '{point_of_interest,establishment}', '{"bearing": 289.67, "distance": 10965128.97}', '{"motion": "STILL", "confidence": "unknown"}', NULL, '{}', NULL, NULL, NULL),
	('e8d8ee75-0be6-4917-b6b3-844e883c7ec7', '2026-02-09 15:36:03.260741+00', 19.435478, -99.1364789, 'Test-MAC', '1294c40f99dc319b954f4f8bf7d70996a6dd844e167ae6ab337e2056e569eb4e', 'Metro Allende', 'Unknown', '{point_of_interest,establishment}', '{"bearing": 289.67, "distance": 10965128.97}', '{"motion": "STILL", "confidence": "unknown"}', NULL, '{}', NULL, NULL, NULL),
	('079c16a2-e475-4511-91c9-bf9ed6703b3f', '2026-02-09 15:37:06.805971+00', 19.435478, -99.1364789, 'test-MAC', '1294c40f99dc319b954f4f8bf7d70996a6dd844e167ae6ab337e2056e569eb4e', 'Metro Allende', 'Unknown', '{point_of_interest,establishment}', '{"bearing": 0, "distance": 0}', '{"motion": "STILL", "confidence": "unknown"}', NULL, '{}', NULL, NULL, NULL),
	('77048b2a-592b-4863-930d-9523f3b58087', '2026-02-06 13:30:25.838777+00', 51.5007, -0.1246, 'test-MAC', '805c59277730708d1090f237a0af6a2e43bdd673315c88e70619ae29a0cbb213', 'Big Ben', 'cultural_landmark', '{cultural_landmark,tourist_attraction,point_of_interest,establishment}', '{"bearing": 203.22, "distance": 895.23}', '{"motion": "walking", "confidence": "high"}', 5, '{}', NULL, NULL, NULL),
	('8e62831e-315f-42e7-a08c-5e9c102f0de2', '2026-02-06 13:30:11.360599+00', 51.5007, -0.1246, 'test-MAC', '805c59277730708d1090f237a0af6a2e43bdd673315c88e70619ae29a0cbb213', 'Big Ben', 'cultural_landmark', '{cultural_landmark,tourist_attraction,point_of_interest,establishment}', '{"bearing": 203.5, "distance": 885.15}', '{"motion": "walking", "confidence": "high"}', 5, '{}', NULL, NULL, NULL),
	('fe868c39-7d7f-4df0-81da-9a06ba720963', '2026-02-06 13:30:17.187394+00', 51.5007, -0.1246, 'test-MAC', '805c59277730708d1090f237a0af6a2e43bdd673315c88e70619ae29a0cbb213', 'Big Ben', 'cultural_landmark', '{cultural_landmark,tourist_attraction,point_of_interest,establishment}', '{"bearing": 203.5, "distance": 885.13}', '{"motion": "walking", "confidence": "high"}', 5, '{}', NULL, NULL, NULL),
	('4f7f5e98-8414-4d1b-b87b-cd933fb09aa9', '2026-02-06 13:32:30.385424+00', 51.5322, -0.10581, 'test-MAC', '5095b3d00470f57ffc9801d8442335f3f5958731b487aa3c98588b172b17b779', 'Angel Station', 'Unknown', '{point_of_interest,establishment}', '{"bearing": 19.46, "distance": 2842.4}', '{"motion": "cycling", "confidence": "medium"}', 5, '{}', NULL, NULL, NULL),
	('613b4391-0775-4911-8a3c-21f96acec0db', '2026-02-15 14:43:04.864559+00', 19.435478, -99.1364789, 'test-MAC', '1294c40f99dc319b954f4f8bf7d70996a6dd844e167ae6ab337e2056e569eb4e', 'Metro Allende', 'transportation_service', '{transportation_service,point_of_interest,establishment}', NULL, '{"motion": "STILL", "confidence": "unknown"}', NULL, '{}', NULL, NULL, NULL),
	('f3896417-1f94-43e4-ad97-b4076e231f8a', '2026-02-15 15:21:56.991963+00', 19.435478, -99.1364789, 'test-MAC', '1294c40f99dc319b954f4f8bf7d70996a6dd844e167ae6ab337e2056e569eb4e', 'Metro Allende', 'transportation_service', '{transportation_service,point_of_interest,establishment}', NULL, '{"motion": "STILL", "confidence": "unknown"}', NULL, '{}', NULL, NULL, NULL),
	('38226c1d-0226-4182-9719-a8e84e4c2a84', '2026-02-15 18:43:50.418963+00', 19.435478, -99.1364789, 'test-MAC', '1294c40f99dc319b954f4f8bf7d70996a6dd844e167ae6ab337e2056e569eb4e', 'Metro Allende', 'transportation_service', '{transportation_service,point_of_interest,establishment}', NULL, '{"motion": "STILL", "confidence": "unknown"}', 5, '{}', NULL, NULL, NULL),
	('4346098f-15c0-4b7d-b117-dfa8f4360c04', '2026-02-15 18:44:19.281213+00', 19.435478, -97.136479, 'test-MAC', 'Unknown', 'Unknown', 'Unknown', '{}', '{"x_m": 209712.64, "y_m": 1218.03, "bearing": 89.6672, "distance": 209716.18}', '{"motion": "STILL", "confidence": "unknown"}', 5, '{}', NULL, NULL, NULL),
	('d83d81bb-7451-4e59-9d99-e7c2b7caa4c1', '2026-02-16 09:52:25.017297+00', 19.435478, -97.136479, 'test-MAC', 'Unknown', 'Unknown', 'Unknown', '{}', NULL, '{"motion": "STILL", "confidence": "unknown"}', 5, '{}', NULL, NULL, NULL),
	('94578313-5b40-4de4-ae8d-f3d6790eefb3', '2026-02-19 18:40:26.23015+00', 51.584627338370304, -0.024396562974015015, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": -5.96, "y_m": -11.45, "bearing": 207.5104, "distance": 12.91}', '{"motion": "UNKNOWN", "confidence": "high"}', 26.761960323517865, '{}', 21.93, '{}', NULL),
	('7651a36b-10f0-456c-b5d4-92cce7c9df78', '2026-02-16 09:56:48.162714+00', 51.59098012227747, -0.04083802923047337, 'test-MAC', '07b4d8f7a5fbab605aebcbca83aea4e0ed5d76e648e5b8cc3db78cd2d1a33342', 'Big Penny Social', 'pub', '{pub,brewery,bar,event_venue,point_of_interest,food,manufacturer,service,establishment}', '{"x_m": 5524356.96, "y_m": 6850234.93, "bearing": 38.8844, "distance": 8800240.82}', '{"motion": "STILL", "confidence": "unknown"}', 5, '{}', NULL, NULL, NULL),
	('7c7f411b-c053-4513-89ec-d72a9433ae1e', '2026-02-17 11:33:43.393692+00', 51.59098012227747, -0.04083802923047337, 'test-MAC', '019b34da75acc6ba83d5f45cde1db84ca6431f962db0905b6386ff0cf6f031b5', 'Toolstation Walthamstow', 'Unknown', '{point_of_interest,establishment}', NULL, '{"motion": "STILL", "confidence": "unknown"}', 5, '{}', NULL, NULL, NULL),
	('b68316cf-c6b5-4989-b4ad-78ff8d7aa03f', '2026-02-17 11:34:56.502925+00', 51.59098012227747, -0.04083802923047337, 'test-MAC', '019b34da75acc6ba83d5f45cde1db84ca6431f962db0905b6386ff0cf6f031b5', 'Toolstation Walthamstow', 'Unknown', '{point_of_interest,establishment}', NULL, '{"motion": "STILL", "confidence": "unknown"}', 5, '{}', NULL, NULL, NULL),
	('ec4a0de4-ce23-4783-b8ea-d884fa16a6be', '2026-02-17 11:36:00.833456+00', 51.59098012227747, -0.04083802923047337, 'test-MAC', '07b4d8f7a5fbab605aebcbca83aea4e0ed5d76e648e5b8cc3db78cd2d1a33342', 'Big Penny Social', 'pub', '{pub,brewery,event_venue,bar,food,point_of_interest,service,manufacturer,establishment}', NULL, '{"motion": "STILL", "confidence": "unknown"}', 5, '{brewery,sports_activity_location,government_office,brewery}', NULL, NULL, NULL),
	('5e86e465-906f-4326-8c81-5a84022f54a1', '2026-02-17 12:32:18.072084+00', 51.59098012227747, -0.04083802923047337, 'test-MAC', '019b34da75acc6ba83d5f45cde1db84ca6431f962db0905b6386ff0cf6f031b5', 'Toolstation Walthamstow', 'Unknown', '{point_of_interest,establishment}', NULL, '{"motion": "STILL", "confidence": "unknown"}', 5, '{}', 4.21, '{}', NULL),
	('2f6e5f44-5660-4131-8126-970f11c55fb3', '2026-02-17 12:34:55.597411+00', 51.59098012227747, -0.04083802923047337, 'test-MAC', '07b4d8f7a5fbab605aebcbca83aea4e0ed5d76e648e5b8cc3db78cd2d1a33342', 'Big Penny Social', 'Home', '{pub,brewery,bar,event_venue,manufacturer,food,service,point_of_interest,establishment}', '{"x_m": 0, "y_m": 0, "bearing": 0, "distance": 0}', '{"motion": "STILL", "confidence": "unknown"}', 5, '{brewery,sports_activity_location,government_office,brewery}', 35.96, '{158.3,155.54,161.85,109.59}', NULL),
	('92abf4b5-ac3c-49e2-8d1c-33dd7495bf86', '2026-02-17 12:41:26.689255+00', 51.59098012227747, -0.04083802923047337, 'test-MAC', '07b4d8f7a5fbab605aebcbca83aea4e0ed5d76e648e5b8cc3db78cd2d1a33342', 'Big Penny Social', 'Home', '{pub,brewery,event_venue,manufacturer,bar,food,point_of_interest,service,establishment}', '{"x_m": 0, "y_m": 0, "bearing": 0, "distance": 0}', '{"motion": "STILL", "confidence": "unknown"}', 5, '{brewery,sports_activity_location,government_office,brewery}', 35.96, '{158.3,155.54,161.85,109.59}', NULL),
	('0434d364-3648-4f4e-9134-2e45891cae57', '2026-02-17 13:01:40.179654+00', 51.59098012227747, -0.04083802923047337, 'test-MAC', '07b4d8f7a5fbab605aebcbca83aea4e0ed5d76e648e5b8cc3db78cd2d1a33342', 'Big Penny Social', 'pub', '{pub,brewery,event_venue,bar,food,point_of_interest,service,manufacturer,establishment}', NULL, '{"motion": "STILL", "confidence": "unknown"}', 5, '{brewery,sports_activity_location,government_office,brewery}', 35.96, '{158.3,155.54,161.85,109.59}', NULL),
	('675e49b0-3cd1-4aaf-84a3-e9ab763c2479', '2026-02-17 13:02:38.598876+00', 37.33067599, -122.03021599, 'test-MAC', '74b72cdc5910e7902847f78bc9490b13fc34809078d98940bcca0b8883086fa3', 'Mariani Three', 'parking_lot', '{parking_lot,parking,transportation_service,service,point_of_interest,establishment}', NULL, '{"motion": "STILL", "confidence": "unknown"}', 10, '{restaurant,manufacturer,corporate_office,parking_lot}', 97.56, '{159.01,137.35,144.71,124.46}', NULL),
	('299dd9b3-bcf3-43bf-aa7a-02b9ea75dbbc', '2026-02-17 13:03:40.399328+00', 37.33025622, -122.02763446, 'test-MAC', '74b72cdc5910e7902847f78bc9490b13fc34809078d98940bcca0b8883086fa3', 'Mariani Three', 'parking_lot', '{parking_lot,parking,transportation_service,service,point_of_interest,establishment}', NULL, '{"motion": "STILL", "confidence": "unknown"}', 10, '{school,tennis_court,school,parking_lot}', 204.22, '{64.39,222.38,161.37,205.25}', NULL),
	('1c05d245-2f08-4dd1-a9c1-737654227b1a', '2026-02-17 14:04:31.199472+00', 37.33069778, -122.03035543, 'test-MAC', 'Unknown', 'Unknown', 'Unknown', '{}', NULL, '{"motion": "STILL", "confidence": "unknown"}', 10, '{}', NULL, '{}', NULL),
	('1a6d16c7-496a-4916-9ff1-a88abbfec0bc', '2026-02-17 14:05:31.735155+00', 37.33026525, -122.02778504, 'test-MAC', 'Unknown', 'Unknown', 'Unknown', '{}', '{"x_m": 198.43, "y_m": -45.21, "bearing": 102.8354, "distance": 203.51}', '{"motion": "STILL", "confidence": "unknown"}', 10, '{}', NULL, '{}', NULL),
	('63c54f7a-8f4d-4bb2-87be-f2d4abb5d080', '2026-02-17 14:06:34.972581+00', 37.3302024, -122.02488379, 'test-MAC', 'Unknown', 'Unknown', 'Unknown', '{}', '{"x_m": 454.95, "y_m": -52.19, "bearing": 96.5441, "distance": 457.93}', '{"motion": "STILL", "confidence": "unknown"}', 10, '{}', NULL, '{}', NULL),
	('2c10c40b-e202-4663-9bbd-6106e132fffc', '2026-02-17 14:08:40.729927+00', 37.33070248, -122.02957434, 'test-MAC', 'Unknown', 'Unknown', 'Unknown', '{}', NULL, '{"motion": "STILL", "confidence": "unknown"}', 10, '{}', NULL, '{}', NULL),
	('c7e63810-2fa7-4c53-bb2c-57ece085de12', '2026-02-17 14:24:10.967631+00', 37.3314643, -122.03072069, 'test-MAC', 'Unknown', 'Unknown', 'Unknown', '{}', NULL, '{"motion": "STILL", "confidence": "unknown"}', 10, '{}', NULL, '{}', NULL),
	('2e524a6b-e5ab-40aa-bd1e-3da6ff5b9477', '2026-02-17 14:24:46.609403+00', 37.33067784, -122.02998825, 'test-MAC', 'Unknown', 'Unknown', 'Unknown', '{}', NULL, '{"motion": "STILL", "confidence": "unknown"}', 10, '{}', NULL, '{}', NULL),
	('770da291-6643-4384-a304-0f1e5617a4b7', '2026-02-18 15:31:57.858328+00', 51.50351957929333, -0.08635432726178946, 'Altest1', 'b0bfd172372dd593f7ccd26b4f9e74dbea69e9ad507eb2a1db701b58da1797e6', 'Sherman Education Centre', 'Home', '{corporate_office,point_of_interest,establishment}', '{"x_m": 0, "y_m": 0, "bearing": 305.6569, "distance": 0}', '{"motion": "STILL", "confidence": "low"}', 13.080023366806298, '{NULL,doctor,NULL}', 13.65, '{26.06,27.2,9.34}', NULL),
	('4e390ffc-085d-4fdd-9572-c5e363af73a6', '2026-02-18 15:31:59.538336+00', 51.50351957929333, -0.08635432726178946, 'Altest1', 'b0bfd172372dd593f7ccd26b4f9e74dbea69e9ad507eb2a1db701b58da1797e6', 'Sherman Education Centre', 'Home', '{corporate_office,point_of_interest,establishment}', '{"x_m": 0, "y_m": 0, "bearing": 305.6569, "distance": 0}', '{"motion": "UNKNOWN", "confidence": "high"}', 13.295014, '{NULL,doctor,NULL}', 13.65, '{26.06,27.2,9.34}', NULL),
	('134ddf48-801c-4253-ab23-7cbc114e604e', '2026-02-18 15:32:19.24959+00', 51.50351783067581, -0.08639259510638979, 'Tamtest1', 'b0bfd172372dd593f7ccd26b4f9e74dbea69e9ad507eb2a1db701b58da1797e6', 'Sherman Education Centre', 'corporate_office', '{corporate_office,point_of_interest,establishment}', NULL, '{"motion": "STILL", "confidence": "unknown"}', 14.296628674127508, '{doctor,NULL,NULL}', 11.09, '{24.61,9.85,26.54}', NULL),
	('74237712-64be-4f37-9303-216c30feda70', '2026-02-18 15:32:22.043677+00', 51.50351783067581, -0.08639259510638979, 'Tamtest1', 'b0bfd172372dd593f7ccd26b4f9e74dbea69e9ad507eb2a1db701b58da1797e6', 'Sherman Education Centre', 'corporate_office', '{corporate_office,point_of_interest,establishment}', NULL, '{"motion": "UNKNOWN", "confidence": "high"}', 14.296628674127508, '{doctor,NULL,NULL}', 11.09, '{24.61,9.85,26.54}', NULL),
	('7d93938f-d426-4289-b08f-5141a4821996', '2026-02-18 15:36:10.016638+00', 51.50351958583934, -0.08635433503386175, 'Altest1', 'b0bfd172372dd593f7ccd26b4f9e74dbea69e9ad507eb2a1db701b58da1797e6', 'Sherman Education Centre', 'Home', '{corporate_office,point_of_interest,establishment}', '{"x_m": 0, "y_m": 0, "bearing": 308.8481, "distance": 0}', '{"motion": "UNKNOWN", "confidence": "high"}', 17.061434823750723, '{NULL,doctor,NULL}', 13.65, '{26.06,27.2,9.34}', NULL),
	('a6223a8a-2631-407e-860a-dad45580ba0c', '2026-02-18 15:37:49.956587+00', 51.50369178876731, -0.08617022220926496, 'Altest1', '2af2f4737851ec00f2b2a1a6fe81661b8de35bbe98016509b2a9dc4f3532802b', 'Mr Sam Gidwani', 'Home', '{doctor,point_of_interest,health,establishment}', '{"x_m": 12.74, "y_m": 19.15, "bearing": 33.632, "distance": 23}', '{"motion": "UNKNOWN", "confidence": "high"}', 28.495013999999998, '{doctor,NULL,doctor,doctor}', 12.62, '{12.19,12.58,12.19,28.72}', NULL),
	('b4ec6832-7865-40e9-937d-04b2000c0d5a', '2026-02-18 15:38:01.160436+00', 51.50385226767494, -0.08608307246545892, 'Tamtest1', '163b7ca71e5b0a4ddb18e12e42896322c0a73111526d12090172cd37a24d61d3', 'ACE-FX', 'service', '{finance,point_of_interest,service,establishment}', NULL, '{"motion": "UNKNOWN", "confidence": "high"}', 21.232177022323352, '{pharmacy,doctor,doctor,consultant}', 28.57, '{30.16,23.64,7.22,17.15}', NULL),
	('f3407a3d-1637-4680-91c5-7274d6d92bf3', '2026-02-18 15:39:04.590906+00', 51.50430399185225, -0.08693886889412662, 'Tamtest1', '1128b6e72903fd6a6792cebcf30e4410f3aaa6a3947df517f6f5e01830df3988', 'Shangri-La The Shard, London', 'hotel', '{hotel,lodging,point_of_interest,establishment}', NULL, '{"motion": "WALKING", "confidence": "high"}', 14.24595454245209, '{scenic_spot,british_restaurant,chinese_restaurant,restaurant}', 10.71, '{30.16,27.29,10.57,27.32}', NULL),
	('b8a5805f-ae10-4c52-83f3-2fd98dc654a0', '2026-02-18 15:53:12.880467+00', 51.50409673050129, -0.0879839417824989, 'Tamtest1', '11d683091fcbfdf44bc564ebe446003e3c347042b85886f8a5ded843254f240f', 'Guy''s Bar', 'bar', '{bar,pub,point_of_interest,establishment}', NULL, '{"motion": "UNKNOWN", "confidence": "high"}', 8.606000971039403, '{church,cafe,sculpture,sculpture}', 11.63, '{25.2,7.28,22.06,21.37}', NULL),
	('bd9bb298-c548-4774-86c8-95026dc6b9bb', '2026-02-18 16:26:52.095232+00', 51.502693525646954, -0.08624325397674346, 'Tamtest1', '55c24529bd0bf54cd094cb1e7dd328d0ef4a43997fa19b55b0e08ba010f29439', 'Greenwood Theatre', 'performing_arts_theater', '{performing_arts_theater,event_venue,point_of_interest,establishment}', NULL, '{"motion": "WALKING", "confidence": "high"}', 14.245954589907289, '{health,school,point_of_interest}', 27.74, '{17.33,28.41,27.75}', NULL),
	('a6122afb-01ae-4ef1-bfc6-144f1427c1d7', '2026-02-18 16:27:52.653804+00', 51.503263757835576, -0.0873593728241286, 'Tamtest1', '65507d3b33c2580ba9f2c76e15d6072186365c61752db4c119169b71d363a649', 'Guy''s and St Thomas'' Hospital Urgent Care Centre', 'medical_clinic', '{point_of_interest,service,medical_clinic,health,establishment}', NULL, '{"motion": "WALKING", "confidence": "high"}', 22.221499618633743, '{pharmacy,medical_clinic,coffee_shop,preschool}', 20.04, '{22.94,23.81,13.42,13.41}', NULL),
	('7e67e381-eb91-4447-b9ec-ae3ac20e7d85', '2026-02-18 16:28:55.212737+00', 51.503565822642905, -0.08668129026147155, 'Tamtest1', 'f205c5ecd5779e6cc4e7b4a9b8422b1b54cc791d141ce82eda0ff8d2fb2a757d', 'Cell and Gene Therapy Catapult - London', 'Unknown', '{research_institute,point_of_interest,establishment}', NULL, '{"motion": "WALKING", "confidence": "high"}', 25.143232074198885, '{university,corporate_office,NULL,doctor}', 26.02, '{12.47,9.61,26.88,13.3}', NULL),
	('d1585938-dcfd-45ad-aed3-1632da4c1c07', '2026-02-18 16:29:36.917717+00', 51.5035069018934, -0.08636737175831977, 'Altest1', 'b0bfd172372dd593f7ccd26b4f9e74dbea69e9ad507eb2a1db701b58da1797e6', 'Sherman Education Centre', 'Home', '{corporate_office,point_of_interest,establishment}', '{"x_m": -0.91, "y_m": -1.41, "bearing": 212.7801, "distance": 1.67}', '{"motion": "UNKNOWN", "confidence": "high"}', 22.505059666858806, '{doctor,NULL,NULL}', 13.09, '{25.96,10.77,27.53}', NULL),
	('50b809e9-393a-4c9d-a3ff-15d8f8b9e9cf', '2026-02-18 16:35:45.554033+00', 51.503534981009075, -0.08634432660956301, 'Altest1', 'b0bfd172372dd593f7ccd26b4f9e74dbea69e9ad507eb2a1db701b58da1797e6', 'Sherman Education Centre', 'Home', '{corporate_office,point_of_interest,establishment}', '{"x_m": 0.69, "y_m": 1.71, "bearing": 21.8834, "distance": 1.85}', '{"motion": "UNKNOWN", "confidence": "high"}', 14.640856227267982, '{NULL,doctor,NULL}', 14.16, '{24.31,28.38,7.68}', NULL),
	('6e9563e9-e406-4211-ae60-d0c0161c7f20', '2026-02-18 17:09:43.035804+00', 51.50401402920508, -0.0857840850179147, 'Altest1', 'bb6e436b1ee2dfb362fc43a5190a34da27870e1e05b197656040b9a73ee7ed5e', 'Redwood', 'pub', '{pub,sports_bar,beer_garden,bar,restaurant,food,point_of_interest,establishment}', '{"x_m": 39.47, "y_m": 54.98, "bearing": 35.67, "distance": 67.68}', '{"motion": "WALKING", "confidence": "high"}', 32.2449896002106, '{store,service,clothing_store,coffee_shop}', 11.16, '{27.09,27.2,27.09,27.08}', NULL),
	('69d23965-a918-4649-a491-60d5c2649b54', '2026-02-18 17:14:04.778272+00', 51.50468613726033, -0.08367172295721326, 'Altest1', 'ded2be6f7ecec186bbd19886d2901dba87af306fd8692846a051f36787bec65e', 'Comptoir Libanais London Bridge', 'lebanese_restaurant', '{lebanese_restaurant,restaurant,food,point_of_interest,establishment}', '{"x_m": 185.67, "y_m": 129.72, "bearing": 55.0592, "distance": 226.5}', '{"motion": "WALKING", "confidence": "high"}', 14.245954593059103, '{pub,public_bathroom,grocery_store,hotel}', 21.46, '{12.04,30.76,14.19,23.02}', NULL),
	('2e307717-15dc-4126-925d-e9cebb5efddb', '2026-02-18 17:55:49.944235+00', 51.50237968711328, -0.08750161560710795, 'Altest1', 'c48cf9f43a3c04eb88d4793b2b624196b21a04af4fc86f463922e336322e497e', 'Guy''s NHS Cancer Centre', 'medical_clinic', '{medical_clinic,health,point_of_interest,establishment}', '{"x_m": -79.42, "y_m": -126.75, "bearing": 212.0697, "distance": 149.57}', '{"motion": "UNKNOWN", "confidence": "high"}', 29.25789801714835, '{pub,comedy_club,point_of_interest,comedy_club}', 26.53, '{22.39,25.6,25.6,25.6}', NULL),
	('2a5d1a8d-3623-4a2d-b478-1252e5fb527e', '2026-02-18 18:00:32.236467+00', 51.50222884119275, -0.0877264201147588, 'Altest1', 'c48cf9f43a3c04eb88d4793b2b624196b21a04af4fc86f463922e336322e497e', 'Guy''s NHS Cancer Centre', 'medical_clinic', '{medical_clinic,health,point_of_interest,establishment}', '{"x_m": -94.98, "y_m": -143.52, "bearing": 213.4949, "distance": 172.1}', '{"motion": "UNKNOWN", "confidence": "high"}', 21.9999968284787, '{pub,comedy_club,hospital,indian_restaurant}', 25.11, '{19.22,18.67,20.43,23.69}', NULL),
	('407edbf4-680b-42e0-86ec-589d4c1b660c', '2026-02-18 19:03:45.82513+00', 51.50222594482287, -0.08767030622230415, 'Altest1', '79844dda13d6ca3df12733151f2a083d18776466b23d2881dd6b3021553b9ccd', 'The Miller', 'pub', '{pub,comedy_club,bar,event_venue,service,restaurant,point_of_interest,food,establishment}', '{"x_m": -91.09, "y_m": -143.84, "bearing": 212.345, "distance": 170.26}', '{"motion": "UNKNOWN", "confidence": "high"}', 23.130306237646334, '{medical_clinic,comedy_club,hospital,indian_restaurant}', 15.43, '{27.21,15.17,24.26,26.57}', NULL),
	('0a6766c8-9746-4f3f-8784-e172048fa3cc', '2026-02-18 19:03:49.036564+00', 51.502330324465426, -0.0876037267648607, 'Altest1', 'c48cf9f43a3c04eb88d4793b2b624196b21a04af4fc86f463922e336322e497e', 'Guy''s NHS Cancer Centre', 'medical_clinic', '{point_of_interest,medical_clinic,health,establishment}', '{"x_m": -86.48, "y_m": -132.24, "bearing": 213.1849, "distance": 158.01}', '{"motion": "UNKNOWN", "confidence": "high"}', 37.940519315415344, '{pub,comedy_club,hospital,hair_salon}', 22.06, '{19.45,21.62,28.65,25.08}', NULL),
	('20e89eee-157d-470a-84fc-538bcc759799', '2026-02-18 19:16:11.255485+00', 51.50222892198414, -0.08771038529561215, 'Altest1', 'c48cf9f43a3c04eb88d4793b2b624196b21a04af4fc86f463922e336322e497e', 'Guy''s NHS Cancer Centre', 'medical_clinic', '{medical_clinic,health,point_of_interest,establishment}', '{"x_m": -93.87, "y_m": -143.51, "bearing": 213.1873, "distance": 171.48}', '{"motion": "UNKNOWN", "confidence": "high"}', 12.560721257340347, '{pub,comedy_club,hospital,indian_restaurant}', 25.58, '{18.16,17.7,21.49,24.54}', NULL),
	('cc9302bd-64b3-41e1-b568-8a9ef16c1d9c', '2026-02-19 08:42:14.930781+00', 51.50300850051697, -0.091124290963658, 'Altest1', '04d49e8c3c559308305e6f83fb1271196093f3165a8fe3f1031d2e74cbc6e353', 'Crol and Co London Bridge', 'coffee_shop', '{coffee_shop,cocktail_bar,cafe,bar,food_store,point_of_interest,food,store,establishment}', '{"x_m": -330.16, "y_m": -56.82, "bearing": 260.2358, "distance": 335.01}', '{"motion": "WALKING", "confidence": "high"}', 24.24079302067009, '{pub,service,apartment_building,lodging}', 6.91, '{18.12,21.65,25.91,14.62}', NULL),
	('c78e267e-6968-481d-af27-b5c9e801e63b', '2026-02-19 12:44:04.7693+00', 37.33050097, -122.02892179, 'Altest1', 'Unknown', 'Unknown', 'Unknown', '{}', NULL, '{"motion": "STILL", "confidence": "unknown"}', 10, '{}', NULL, '{}', NULL),
	('b5083c3c-43b6-41a1-b3b2-22cc9a5a9eca', '2026-02-19 12:44:25.399982+00', 37.33064656, -122.02973332, 'Altest1', 'Unknown', 'Unknown', 'Unknown', '{}', '{"x_m": -52.64, "y_m": 9.35, "bearing": 280.0695, "distance": 53.46}', '{"motion": "STILL", "confidence": "unknown"}', 10, '{}', NULL, '{}', NULL),
	('e1f4830d-2af1-4e05-b2dc-86e342fe7ce3', '2026-02-19 12:50:13.034439+00', 37.32952569, -122.01982409, 'Altest1', '7a58f638af37bbbd9a05fadeeedb3edb2e749fda6565e51764d263bdff46025b', 'Brand New Private One Bedroom Cottage with a Wet Bar /Kitchenette', 'lodging', '{lodging,point_of_interest,establishment}', '{"x_m": 823.52, "y_m": -115.25, "bearing": 97.9666, "distance": 831.54}', '{"motion": "STILL", "confidence": "unknown"}', 10, '{lodging}', 36.49, '{37.08}', NULL),
	('3e01e408-74ed-4e1f-bed2-629cd847d12c', '2026-02-19 12:50:16.326458+00', 37.32943421, -122.01980636, 'Altest1', '7a58f638af37bbbd9a05fadeeedb3edb2e749fda6565e51764d263bdff46025b', 'Brand New Private One Bedroom Cottage with a Wet Bar /Kitchenette', 'lodging', '{lodging,point_of_interest,establishment}', '{"x_m": 825.08, "y_m": -125.42, "bearing": 98.6433, "distance": 834.56}', '{"motion": "STILL", "confidence": "unknown"}', 10, '{lodging}', 43.48, '{44}', NULL),
	('cdeb93d0-f836-4d6a-b457-dc7c671ca1a1', '2026-02-19 15:44:58.658691+00', 51.58473029931, -0.02431026517730936, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'apartment_building', '{apartment_building,service,point_of_interest,establishment}', NULL, '{"motion": "STILL", "confidence": "unknown"}', 16.143224134482196, '{corporate_office}', 9.62, '{48.05}', NULL),
	('9bd34934-f2d3-492d-b030-11fc80dca045', '2026-02-19 15:45:56.795091+00', 51.58461386971867, -0.024278889136929015, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,service,point_of_interest,establishment}', '{"x_m": 2.17, "y_m": -12.95, "bearing": 170.4942, "distance": 13.13}', '{"motion": "UNKNOWN", "confidence": "high"}', 22.551332824368465, '{}', 19.42, '{}', NULL),
	('867d1e4a-3436-4794-85a0-1612431754d7', '2026-02-19 15:51:19.568783+00', 51.58468662062979, -0.02427260061254987, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,service,point_of_interest,establishment}', '{"x_m": 2.6, "y_m": -4.86, "bearing": 151.8175, "distance": 5.51}', '{"motion": "STILL", "confidence": "high"}', 2, '{}', 11.71, '{}', NULL),
	('ac01288b-d40e-4f87-be14-483f8b3ea5d7', '2026-02-19 16:21:29.222102+00', 51.584695197702096, -0.024120183022835747, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 13.13, "y_m": -3.9, "bearing": 106.5517, "distance": 13.7}', '{"motion": "STILL", "confidence": "high"}', 4.8998828535967585, '{}', 10.93, '{}', NULL),
	('08ba4aee-5c1b-4c9e-ad48-bec40f83a5d7', '2026-02-19 16:26:50.742396+00', 51.58462266119132, -0.024271809969500503, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,service,point_of_interest,establishment}', '{"x_m": 2.66, "y_m": -11.97, "bearing": 167.4839, "distance": 12.26}', '{"motion": "STILL", "confidence": "low"}', 19.743411491159087, '{}', 18.34, '{}', NULL),
	('a9e003cc-f75e-4682-b555-fc6b2ec51ce9', '2026-02-19 17:49:29.472248+00', 51.584651925436475, -0.02425251175449673, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,service,point_of_interest,establishment}', '{"x_m": 3.99, "y_m": -8.71, "bearing": 155.3981, "distance": 9.58}', '{"motion": "UNKNOWN", "confidence": "high"}', 9.479684433115164, '{}', 14.85, '{}', NULL),
	('7608185a-bc7c-4451-af27-d372a32a2fdd', '2026-02-19 19:31:46.65788+00', 51.58473029931, -0.02431026517730936, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 0, "y_m": 0, "bearing": 0, "distance": 0}', '{"motion": "UNKNOWN", "confidence": "high"}', 16.143224134482196, '{corporate_office}', 9.62, '{48.05}', NULL),
	('4ea42b1f-d3f6-48a1-b855-88155ac9e9ac', '2026-02-19 19:32:55.481908+00', 51.58462089993187, -0.024267564696072934, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 2.95, "y_m": -12.16, "bearing": 166.3674, "distance": 12.52}', '{"motion": "UNKNOWN", "confidence": "high"}', 14.338629854245415, '{}', 18.45, '{}', NULL),
	('40ceab38-7895-4b55-a622-3bbed47da39f', '2026-02-19 19:33:57.813662+00', 51.584496003458, -0.024050729974313532, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'apartment_building', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 17.93, "y_m": -26.05, "bearing": 145.4605, "distance": 31.63}', '{"motion": "STILL", "confidence": "low"}', 10.788026442269201, '{warehouse_store,bank,finance,service}', 33.27, '{33.77,34.13,36.12,36.12}', NULL),
	('68d64e87-1cf7-4769-9364-9c169c715c65', '2026-02-19 19:36:15.632276+00', 51.58461164180831, -0.024135020883960703, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 12.11, "y_m": -13.19, "bearing": 137.458, "distance": 17.91}', '{"motion": "UNKNOWN", "confidence": "high"}', 6.67298771105491, '{warehouse_store}', 19.32, '{47.53}', NULL),
	('6aa0a698-b4b1-428d-a1bb-bbe7b20fb547', '2026-02-19 19:38:58.545679+00', 51.584564610841305, -0.024125274526603287, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,service,point_of_interest,establishment}', '{"x_m": 12.78, "y_m": -18.42, "bearing": 145.2492, "distance": 22.42}', '{"motion": "UNKNOWN", "confidence": "high"}', 16.836255992382725, '{warehouse_store,bank,finance,service}', 24.57, '{42.29,43.01,44.68,44.68}', NULL),
	('0c66640c-8834-4720-8f5a-ef8fb1891566', '2026-02-19 19:40:28.446257+00', 51.58456098071766, -0.02410091809767969, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,service,point_of_interest,establishment}', '{"x_m": 14.46, "y_m": -18.83, "bearing": 142.4666, "distance": 23.74}', '{"motion": "STILL", "confidence": "low"}', 15.064034581272953, '{warehouse_store,bank,finance,service}', 25.36, '{41.51,42.07,43.89,43.89}', NULL),
	('bde4bfeb-6a41-41a7-85c3-5216ff42e491', '2026-02-19 19:41:45.678966+00', 51.58450853601414, -0.02427026558302486, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 2.76, "y_m": -24.66, "bearing": 173.6053, "distance": 24.81}', '{"motion": "STILL", "confidence": "low"}', 10.099154840831183, '{warehouse_store,finance,bank,finance}', 30.71, '{40.33,41.73,42.29,42.72}', NULL),
	('1f895b82-14f3-4656-9bf4-38494b5f2c73', '2026-02-19 19:46:20.751167+00', 51.58461524235805, -0.024170813749568844, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,service,point_of_interest,establishment}', '{"x_m": 9.63, "y_m": -12.79, "bearing": 143.0166, "distance": 16.02}', '{"motion": "UNKNOWN", "confidence": "high"}', 56.41216638216091, '{}', 18.52, '{}', NULL),
	('8e0203bd-c1be-4319-b2e3-13c9fe5f1a66', '2026-02-19 19:47:43.723159+00', 51.58473029931, -0.02431026517730936, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,service,point_of_interest,establishment}', '{"x_m": 0, "y_m": 0, "bearing": 0, "distance": 0}', '{"motion": "UNKNOWN", "confidence": "high"}', 16.143224134482196, '{corporate_office}', 9.62, '{48.05}', NULL),
	('934c14a8-8cc6-4640-8898-1b8bc68c183d', '2026-02-19 19:49:03.554917+00', 51.58473029931, -0.02431026517730936, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 0, "y_m": 0, "bearing": 0, "distance": 0}', '{"motion": "UNKNOWN", "confidence": "high"}', 16.143224134482196, '{corporate_office}', 9.62, '{48.05}', NULL),
	('2338f1e9-fd33-4de8-bbcc-e8f91431b4fa', '2026-02-19 19:50:22.596437+00', 51.58473029931, -0.02431026517730936, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 0, "y_m": 0, "bearing": 0, "distance": 0}', '{"motion": "UNKNOWN", "confidence": "high"}', 16.143224134482196, '{corporate_office}', 9.62, '{48.05}', NULL),
	('d2155490-19bd-4980-8ee8-405bba8e0218', '2026-02-19 19:51:22.770831+00', 51.58461465504898, -0.024277100581155422, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 2.29, "y_m": -12.86, "bearing": 169.8963, "distance": 13.06}', '{"motion": "UNKNOWN", "confidence": "high"}', 14.912235325782188, '{}', 19.3, '{}', NULL),
	('58750be9-21f7-45f5-affc-391fc9dcffa0', '2026-02-19 19:53:16.87891+00', 51.58473029931, -0.02431026517730936, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,service,point_of_interest,establishment}', '{"x_m": 0, "y_m": 0, "bearing": 0, "distance": 0}', '{"motion": "UNKNOWN", "confidence": "high"}', 16.143224134482196, '{corporate_office}', 9.62, '{48.05}', NULL),
	('4e62e538-ab07-4e88-9bd4-04acd263ef5e', '2026-02-19 19:54:17.036163+00', 51.58473029931, -0.02431026517730936, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 0, "y_m": 0, "bearing": 0, "distance": 0}', '{"motion": "UNKNOWN", "confidence": "high"}', 16.143224134482196, '{corporate_office}', 9.62, '{48.05}', NULL),
	('aa911ba3-bcb1-40c6-a87f-7cfceea7b3f9', '2026-02-19 19:55:18.352545+00', 51.58473029931, -0.02431026517730936, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 0, "y_m": 0, "bearing": 0, "distance": 0}', '{"motion": "UNKNOWN", "confidence": "high"}', 16.143224134482196, '{corporate_office}', 9.62, '{48.05}', NULL),
	('533d6621-bf8c-4adb-bc5d-baef70764c0e', '2026-02-19 19:56:18.445102+00', 51.58461465501826, -0.024277098598996457, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,service,point_of_interest,establishment}', '{"x_m": 2.29, "y_m": -12.86, "bearing": 169.8957, "distance": 13.06}', '{"motion": "UNKNOWN", "confidence": "high"}', 13.654283736210127, '{}', 19.3, '{}', NULL),
	('07c8a6d5-212e-4ffc-8020-31f821c86994', '2026-02-19 19:57:27.556601+00', 51.58473029931, -0.02431026517730936, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 0, "y_m": 0, "bearing": 0, "distance": 0}', '{"motion": "UNKNOWN", "confidence": "high"}', 16.143224134482196, '{corporate_office}', 9.62, '{48.05}', NULL),
	('825b5925-e191-4e6f-b857-fd3dd683e1d1', '2026-02-19 19:58:40.388355+00', 51.58462813685218, -0.02426563581744206, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 3.08, "y_m": -11.36, "bearing": 164.8136, "distance": 11.77}', '{"motion": "UNKNOWN", "confidence": "high"}', 14.309126229142747, '{}', 17.64, '{}', NULL),
	('86811be7-7625-44c4-bff5-4967ccec4cb7', '2026-02-19 20:00:34.642018+00', 51.58473029931, -0.02431026517730936, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,service,point_of_interest,establishment}', '{"x_m": 0, "y_m": 0, "bearing": 0, "distance": 0}', '{"motion": "UNKNOWN", "confidence": "high"}', 16.143224134482196, '{corporate_office}', 9.62, '{48.05}', NULL),
	('173f7b15-d7f0-4d61-a1f1-2ab8b57f1ea0', '2026-02-19 20:02:34.072893+00', 51.58473029931, -0.02431026517730936, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 0, "y_m": 0, "bearing": 0, "distance": 0}', '{"motion": "UNKNOWN", "confidence": "high"}', 16.143224134482196, '{corporate_office}', 9.62, '{48.05}', NULL),
	('a2ca8926-dc7c-4c41-be4c-bddf7910c97c', '2026-02-19 20:04:15.809163+00', 51.58473029931, -0.02431026517730936, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 0, "y_m": 0, "bearing": 0, "distance": 0}', '{"motion": "UNKNOWN", "confidence": "high"}', 16.143224134482196, '{corporate_office}', 9.62, '{48.05}', NULL),
	('aa7961e7-dfac-4270-8f25-12bcaa824fa6', '2026-02-19 20:05:15.994201+00', 51.58461598077744, -0.024275488391853044, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,service,point_of_interest,establishment}', '{"x_m": 2.4, "y_m": -12.71, "bearing": 169.2961, "distance": 12.94}', '{"motion": "STILL", "confidence": "low"}', 14.68615793235894, '{}', 19.12, '{}', NULL),
	('5cf0ae37-58cc-413d-9d18-7c52bfd7692f', '2026-02-19 20:11:03.136431+00', 51.58461753941533, -0.024260999239828045, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 3.4, "y_m": -12.54, "bearing": 164.8115, "distance": 12.99}', '{"motion": "STILL", "confidence": "high"}', 4.5757816670482985, '{}', 18.7, '{}', NULL),
	('bf9bcac3-2761-435e-99ba-4ffc548b82f1', '2026-02-19 20:32:50.9927+00', 51.58473029931, -0.02431026517730936, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 0, "y_m": 0, "bearing": 0, "distance": 0}', '{"motion": "STILL", "confidence": "low"}', 16.143224134482196, '{corporate_office}', 9.62, '{48.05}', NULL),
	('8ff607f6-72bc-44d1-b549-1d5f32703ea5', '2026-02-19 20:39:03.753313+00', 51.58461598176328, -0.02427550689816009, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,service,point_of_interest,establishment}', '{"x_m": 2.4, "y_m": -12.71, "bearing": 169.3015, "distance": 12.94}', '{"motion": "STILL", "confidence": "high"}', 3.3017451750020537, '{}', 19.12, '{}', NULL),
	('7dc30148-3ca8-4803-84d9-ba4cbb78b538', '2026-02-19 20:52:18.676199+00', 51.58473029931, -0.02431026517730936, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 0, "y_m": 0, "bearing": 0, "distance": 0}', '{"motion": "UNKNOWN", "confidence": "high"}', 16.143224134482196, '{corporate_office}', 9.62, '{48.05}', NULL),
	('6f577414-5495-4ba1-be58-1cfe2f92f992', '2026-02-19 20:54:08.95492+00', 51.58473029931, -0.02431026517730936, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,service,point_of_interest,establishment}', '{"x_m": 0, "y_m": 0, "bearing": 0, "distance": 0}', '{"motion": "UNKNOWN", "confidence": "high"}', 16.143224134482196, '{corporate_office}', 9.62, '{48.05}', NULL),
	('afff3eef-55b7-483e-806c-61303f6d51e6', '2026-02-19 20:55:25.703696+00', 51.58473029931, -0.02431026517730936, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,service,point_of_interest,establishment}', '{"x_m": 0, "y_m": 0, "bearing": 0, "distance": 0}', '{"motion": "UNKNOWN", "confidence": "high"}', 16.143224134482196, '{corporate_office}', 9.62, '{48.05}', NULL),
	('729cc9bc-e6e9-47ed-bc61-9b98ebcc1761', '2026-02-19 20:56:55.88142+00', 51.58473029931, -0.02431026517730936, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,service,point_of_interest,establishment}', '{"x_m": 0, "y_m": 0, "bearing": 0, "distance": 0}', '{"motion": "UNKNOWN", "confidence": "high"}', 16.143224134482196, '{corporate_office}', 9.62, '{48.05}', NULL),
	('258cb684-9ffc-4548-9a91-15b5af154376', '2026-02-19 20:58:05.275712+00', 51.58473029931, -0.02431026517730936, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 0, "y_m": 0, "bearing": 0, "distance": 0}', '{"motion": "UNKNOWN", "confidence": "high"}', 16.143224134482196, '{corporate_office}', 9.62, '{48.05}', NULL),
	('5fe3d72c-54c2-4a8f-b4e6-a27c94ff9f4b', '2026-02-19 21:03:42.861301+00', 51.58471789118152, -0.02434687576313904, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": -2.53, "y_m": -1.38, "bearing": 241.3896, "distance": 2.88}', '{"motion": "UNKNOWN", "confidence": "high"}', 13.306993061222688, '{corporate_office}', 12.48, '{48.37}', NULL),
	('a75722d1-4c52-4df0-9a19-ac657b0d2060', '2026-02-19 21:05:35.487752+00', 51.584628451976826, -0.024283167372757725, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,service,point_of_interest,establishment}', '{"x_m": 1.87, "y_m": -11.32, "bearing": 170.6127, "distance": 11.48}', '{"motion": "UNKNOWN", "confidence": "high"}', 13.542812460855508, '{}', 17.97, '{}', NULL),
	('6ee1571a-c3ee-473c-97ac-27251edf1c58', '2026-02-19 21:07:48.607311+00', 51.58478257413866, -0.02450385380830004, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": -13.38, "y_m": 5.81, "bearing": 293.489, "distance": 14.58}', '{"motion": "UNKNOWN", "confidence": "high"}', 48.40186564543778, '{employment_agency,corporate_office}', 21.17, '{38.17,38.62}', NULL),
	('cc045643-757f-4164-a4c6-46063f1be003', '2026-02-19 21:09:02.726894+00', 51.58461980812685, -0.024267931225592378, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 2.92, "y_m": -12.29, "bearing": 166.6089, "distance": 12.63}', '{"motion": "UNKNOWN", "confidence": "high"}', 5.171504641572246, '{}', 18.57, '{}', NULL),
	('3731dcf1-59ac-493d-a6a2-2f237128b079', '2026-02-19 21:11:02.661628+00', 51.584594907921065, -0.02432327169580049, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,service,point_of_interest,establishment}', '{"x_m": -0.9, "y_m": -15.05, "bearing": 183.416, "distance": 15.08}', '{"motion": "UNKNOWN", "confidence": "high"}', 5.2134590253399224, '{warehouse_store}', 22.44, '{50.49}', NULL),
	('8e757010-b0bf-4eb0-9a16-391479bc30ff', '2026-02-19 21:12:08.593127+00', 51.584677534035215, -0.024381132331834667, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": -4.9, "y_m": -5.87, "bearing": 219.8458, "distance": 7.64}', '{"motion": "UNKNOWN", "confidence": "high"}', 7.014564391144264, '{}', 17.13, '{}', NULL),
	('00920740-c938-47af-a32c-80e80f9fba39', '2026-02-19 21:14:20.683049+00', 51.58460910881223, -0.02428362480861769, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,service,point_of_interest,establishment}', '{"x_m": 1.84, "y_m": -13.48, "bearing": 172.2222, "distance": 13.6}', '{"motion": "UNKNOWN", "confidence": "high"}', 3.5183266173109646, '{}', 20.02, '{}', NULL),
	('63466fab-538b-49ec-8449-2a11217c2be0', '2026-02-19 21:22:41.747063+00', 51.58455461726159, -0.02415996127983899, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,service,point_of_interest,establishment}', '{"x_m": 10.38, "y_m": -19.53, "bearing": 152.0048, "distance": 22.12}', '{"motion": "UNKNOWN", "confidence": "high"}', 17.984244976599516, '{warehouse_store,bank,finance,service}', 25.31, '{41.89,42.89,44.29,44.29}', NULL),
	('abde7a7d-05ee-45e6-9db0-949ccde7d7c5', '2026-02-19 21:24:10.513133+00', 51.58459049417117, -0.02429060708336646, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 1.36, "y_m": -15.55, "bearing": 175.0068, "distance": 15.6}', '{"motion": "UNKNOWN", "confidence": "high"}', 11.69633468814424, '{warehouse_store}', 22.14, '{49.01}', NULL),
	('4be751ce-c364-4f6d-b8c3-f9abdb78ecab', '2026-02-19 21:25:13.348987+00', 51.584614977739136, -0.024248596484901068, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 4.26, "y_m": -12.82, "bearing": 161.6197, "distance": 13.51}', '{"motion": "UNKNOWN", "confidence": "high"}', 5.220714753768431, '{}', 18.8, '{}', NULL),
	('512fece4-80aa-4713-aea0-57a6f3fabd73', '2026-02-19 21:26:21.616753+00', 51.58460701823233, -0.024287614915697312, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,service,point_of_interest,establishment}', '{"x_m": 1.56, "y_m": -13.71, "bearing": 173.4872, "distance": 13.8}', '{"motion": "UNKNOWN", "confidence": "high"}', 8.755926536340155, '{warehouse_store}', 20.32, '{50.57}', NULL),
	('226db534-8840-4595-9491-976ef7cca76d', '2026-02-19 21:28:45.579371+00', 51.58462421276511, -0.02458216881453929, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": -18.79, "y_m": -11.8, "bearing": 237.8746, "distance": 22.18}', '{"motion": "UNKNOWN", "confidence": "high"}', 48.537829394723715, '{finance}', 31.79, '{38.88}', NULL),
	('5d5f27c9-70fd-4881-be7a-b64ded75300a', '2026-02-19 21:29:50.541609+00', 51.584631930067474, -0.02405531562926134, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 17.61, "y_m": -10.94, "bearing": 121.8385, "distance": 20.73}', '{"motion": "UNKNOWN", "confidence": "high"}', 50.923927592527306, '{warehouse_store,bank}', 19.27, '{48.79,48.86}', NULL),
	('cfc64d74-2dd9-41fa-a031-2e591ec5b74a', '2026-02-19 21:30:56.690092+00', 51.58473029931, -0.02431026517730936, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 0, "y_m": 0, "bearing": 0, "distance": 0}', '{"motion": "UNKNOWN", "confidence": "high"}', 16.143224134482196, '{corporate_office}', 9.62, '{48.05}', NULL),
	('487b95d7-173d-44ca-9924-68c2f057fadc', '2026-02-19 21:33:01.141771+00', 51.58473029931, -0.02431026517730936, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 0, "y_m": 0, "bearing": 0, "distance": 0}', '{"motion": "STILL", "confidence": "low"}', 16.143224134482196, '{corporate_office}', 9.62, '{48.05}', NULL),
	('5d1f76da-2bb1-4057-b3ba-ab9cfe1cfdff', '2026-02-19 21:39:14.810691+00', 51.58473029931, -0.02431026517730936, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 0, "y_m": 0, "bearing": 0, "distance": 0}', '{"motion": "UNKNOWN", "confidence": "high"}', 16.143224134482196, '{corporate_office}', 9.62, '{48.05}', NULL),
	('5d1da196-9527-41d3-bff1-45a989c9c8ba', '2026-02-19 21:40:27.118968+00', 51.58473029931, -0.02431026517730936, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,service,point_of_interest,establishment}', '{"x_m": 0, "y_m": 0, "bearing": 0, "distance": 0}', '{"motion": "UNKNOWN", "confidence": "high"}', 16.143224134482196, '{corporate_office}', 9.62, '{48.05}', NULL),
	('4750221d-d52f-42bc-98f3-0fd419b41872', '2026-02-19 21:41:34.915853+00', 51.58473029931, -0.02431026517730936, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 0, "y_m": 0, "bearing": 0, "distance": 0}', '{"motion": "UNKNOWN", "confidence": "high"}', 16.143224134482196, '{corporate_office}', 9.62, '{48.05}', NULL),
	('a524c083-33b4-4f9b-834d-317a5c704739', '2026-02-19 21:43:44.444958+00', 51.58473029931, -0.02431026517730936, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 0, "y_m": 0, "bearing": 0, "distance": 0}', '{"motion": "UNKNOWN", "confidence": "high"}', 16.143224134482196, '{corporate_office}', 9.62, '{48.05}', NULL),
	('a824bfa6-a74c-4d44-9acd-8a1cb062fc7f', '2026-02-19 21:44:44.980207+00', 51.58473029931, -0.02431026517730936, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 0, "y_m": 0, "bearing": 0, "distance": 0}', '{"motion": "STILL", "confidence": "high"}', 16.143224134482196, '{corporate_office}', 9.62, '{48.05}', NULL),
	('eb26cdec-6050-4e81-90c9-fb1d1722ca7d', '2026-02-19 21:46:25.161902+00', 51.58473029931, -0.02431026517730936, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 0, "y_m": 0, "bearing": 0, "distance": 0}', '{"motion": "UNKNOWN", "confidence": "high"}', 16.143224134482196, '{corporate_office}', 9.62, '{48.05}', NULL),
	('95fd191a-e38c-44ce-90e5-8952239bbd62', '2026-02-19 21:47:36.080712+00', 51.58473029931, -0.02431026517730936, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 0, "y_m": 0, "bearing": 0, "distance": 0}', '{"motion": "STILL", "confidence": "low"}', 16.143224134482196, '{corporate_office}', 9.62, '{48.05}', NULL),
	('49b98772-d357-425e-a242-2ae9fb2e7385', '2026-02-19 21:48:43.353574+00', 51.58465163865173, -0.024362773350431594, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": -3.63, "y_m": -8.75, "bearing": 202.5274, "distance": 9.47}', '{"motion": "UNKNOWN", "confidence": "high"}', 41.19072964564468, '{}', 18.37, '{}', NULL),
	('4516cb51-d40d-4293-a770-0b5f46e3f03d', '2026-02-19 21:50:58.412243+00', 51.58469119965752, -0.02423207500440219, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 5.4, "y_m": -4.35, "bearing": 128.8265, "distance": 6.93}', '{"motion": "STILL", "confidence": "low"}', 22.44060623807498, '{}', 10.27, '{}', NULL),
	('fa83d105-2dca-4c04-9535-b6e025c37abc', '2026-02-19 21:52:43.437674+00', 51.58473029931, -0.02431026517730936, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 0, "y_m": 0, "bearing": 0, "distance": 0}', '{"motion": "STILL", "confidence": "low"}', 16.143224134482196, '{corporate_office}', 9.62, '{48.05}', NULL),
	('a544509f-d3d0-414f-a015-1a9d72307396', '2026-02-19 21:53:34.208381+00', 51.58462029149936, -0.024274867687795926, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 2.45, "y_m": -12.23, "bearing": 168.6936, "distance": 12.47}', '{"motion": "STILL", "confidence": "unknown"}', 18.546798063704685, '{}', 18.65, '{}', NULL),
	('053bcbec-7983-4e3c-b702-45d48f9c648f', '2026-02-19 22:15:59.930241+00', 51.58473029931, -0.02431026517730936, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 0, "y_m": 0, "bearing": 0, "distance": 0}', '{"motion": "UNKNOWN", "confidence": "high"}', 16.143224134482196, '{corporate_office}', 9.62, '{48.05}', NULL),
	('95645962-c93f-4f9a-ac08-f840c33c498c', '2026-02-19 22:18:58.576099+00', 51.584705143503, -0.024238119123818697, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 4.98, "y_m": -2.8, "bearing": 119.2993, "distance": 5.72}', '{"motion": "UNKNOWN", "confidence": "high"}', 20.168192908316843, '{}', 8.89, '{}', NULL),
	('4c9fa675-b813-4543-b89b-448af70a6862', '2026-02-19 22:21:18.1182+00', 51.58473029931, -0.02431026517730936, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,point_of_interest,service,establishment}', '{"x_m": 0, "y_m": 0, "bearing": 0, "distance": 0}', '{"motion": "UNKNOWN", "confidence": "high"}', 16.143224134482196, '{corporate_office}', 9.62, '{48.05}', NULL),
	('26239a19-5ba1-4c84-9c91-9d4d5ad91b37', '2026-02-19 22:22:59.5482+00', 51.58465378032593, -0.024371146335283794, 'Altest1', '5d6092606f848ec5a5b49265601405591a89d992dc8fe52113d144f3b99b291a', 'Thomas Jacomb', 'Home', '{apartment_building,service,point_of_interest,establishment}', '{"x_m": -4.21, "y_m": -8.51, "bearing": 206.3066, "distance": 9.49}', '{"motion": "STILL", "confidence": "high"}', 2.502327358945497, '{}', 18.55, '{}', NULL),
	('9a5f97a2-7dea-4139-8e12-0b4e0ab1e870', '2026-02-20 08:15:42.417809+00', 51.58456716507093, -0.024937729217063775, 'Altest1', 'a9fdcf321855dbdc79e7eff54a0a1ef18163e325670fbea5748d05d9f7ba6dda', 'Western Union', 'finance', '{finance,point_of_interest,service,establishment}', '{"x_m": -43.35, "y_m": -18.14, "bearing": 247.2947, "distance": 46.99}', '{"motion": "STILL", "confidence": "unknown"}', 17.928125838803965, '{}', 21.25, '{}', NULL),
	('fed569da-a3bf-4063-b9de-af814ce57897', '2026-02-20 08:16:42.719932+00', 51.583891195682554, -0.02469843003941293, 'Altest1', '692c8096dad726ed55a031516814ca59ec5e1cc33747c750cedf4e6e3f9e6bee', 'MOBILE SOLUTIONS', 'point_of_interest', '{point_of_interest,establishment}', '{"x_m": -26.82, "y_m": -93.3, "bearing": 196.0369, "distance": 97.08}', '{"motion": "WALKING", "confidence": "high"}', 4.991124014878407, '{restaurant,astrologer,grocery_store,astrologer}', 9.14, '{9.95,9.95,10.64,10.01}', NULL),
	('3d6742b3-f46c-4b2e-a242-5baa5094c0dd', '2026-02-20 08:17:55.747304+00', 51.5841266373496, -0.02334739291039108, 'Altest1', '659b55d260dcce03fd855200be8a5da93d7803d33a24ab02d8df5470761c9fdc', 'Shop from Crisis Walthamstow', 'store', '{store,point_of_interest,establishment}', '{"x_m": 66.53, "y_m": -67.12, "bearing": 135.2556, "distance": 94.51}', '{"motion": "WALKING", "confidence": "high"}', 6.399168928423313, '{service,food_store,market,kebab_shop}', 13.65, '{13.9,14.47,17.01,17.24}', NULL),
	('264ff704-01b4-4295-ab10-13cfd434c9c2', '2026-02-20 08:18:52.629337+00', 51.58440849459541, -0.022213973900260708, 'Altest1', '63c12f773534021e9bd598c636c4617b5793f4470bf6e3a93ebcc26d21dbb9e3', 'Las Fierbinti Shisha & Vapes', 'point_of_interest', '{point_of_interest,establishment}', '{"x_m": 144.84, "y_m": -35.78, "bearing": 103.8766, "distance": 149.19}', '{"motion": "WALKING", "confidence": "high"}', 8.317883277247395, '{chinese_restaurant,meal_takeaway,service,finance}', 6.49, '{8.51,8.46,8.46,11.34}', NULL),
	('cb2a1a6f-efea-465b-8f8e-910d049d4d6f', '2026-02-20 08:20:04.967097+00', 51.58377411433474, -0.021076565009289398, 'Altest1', '95ff77d5a868dc522506b23e3bea908e157ba8099389c21cfc7070e1034f4ea8', 'Walthamstow Town Square Gardens', 'park', '{park,point_of_interest,establishment}', '{"x_m": 223.43, "y_m": -106.32, "bearing": 115.4475, "distance": 247.43}', '{"motion": "WALKING", "confidence": "high"}', 5.903431611483938, '{bus_station,bus_station}', 39.3, '{46.37,49.08}', NULL),
	('39ac0678-953e-4e5d-b06b-325ab60029bf', '2026-02-20 08:21:15.341106+00', 51.58342427578934, -0.020479252561945917, 'Altest1', '7f0130b2ae4755a1e117f7a8c475f26b777348c54f04b7e9dcd303e796281768', 'Walthamstow Bus Station (Stop A)', 'bus_station', '{bus_station,transit_station,transportation_service,point_of_interest,establishment}', '{"x_m": 264.7, "y_m": -145.22, "bearing": 118.7496, "distance": 301.92}', '{"motion": "WALKING", "confidence": "high"}', 32.955199695682225, '{transit_station,transportation_service,bus_station,bus_station}', 3.31, '{10.4,24.88,30.29,32.43}', NULL),
	('fd9c218c-58f2-4c37-a81f-046d48b17f8a', '2026-02-20 08:40:43.935789+00', 51.53672878435037, -0.11584050221857758, 'Altest1', '4aa79c27b92992f10ea37dcbb000a7a6032319784a7f78d807250d59dc6085d9', 'Still Life King''s Cross Two Bedroom Apartment', 'lodging', '{lodging,point_of_interest,establishment}', '{"x_m": -6330.66, "y_m": -5333.56, "bearing": 229.8859, "distance": 8277.93}', '{"motion": "AUTOMOTIVE", "confidence": "high"}', 3000, '{apartment_complex,general_contractor,service,corporate_office}', 20.23, '{21.44,31.03,34,34.54}', NULL),
	('3768987e-ecc5-4817-b7a6-2b423d5695cb', '2026-02-20 08:42:02.124403+00', 51.53059835179841, -0.1236473559323346, 'Altest1', '8a697049ed6a85850286f21be7de4e558a74f6db4b87fa5c4b8d57d75c148a18', '250 City Road 2 Bollinder Place EC1V 2AH 2bed LUXURY apartments-this is full address - Two-Bedroom Apartment', 'lodging', '{lodging,point_of_interest,establishment}', '{"x_m": -6871.54, "y_m": -6014.53, "bearing": 228.8049, "distance": 9131.96}', '{"motion": "AUTOMOTIVE", "confidence": "high"}', 2153.156903989403, '{NULL,juice_shop,restaurant,sandwich_shop}', 9.32, '{12.77,15.97,13.77,15.87}', NULL),
	('5d92fb6c-a577-410c-9c36-82f1e891473d', '2026-02-20 08:42:58.575643+00', 51.5245950468745, -0.1308455048625835, 'Altest1', 'e521aec9d8da5107b136b60fa57d5962ef1166007333da28911db54e06c7d39e', 'School of Arts, Birkbeck College', 'educational_institution', '{educational_institution,service,point_of_interest,establishment}', '{"x_m": -7370.44, "y_m": -6681.37, "bearing": 227.8074, "distance": 9948.07}', '{"motion": "WALKING", "confidence": "high"}', 2224.5472905899114, '{sculpture,garden,art_gallery,academic_department}', 32.73, '{33.5,34.6,39.71,43.26}', NULL),
	('9a0a0014-cab0-4a9f-9bf0-4b74a972b339', '2026-02-20 08:44:19.333697+00', 51.51376410650065, -0.13549836294988307, 'Altest1', '0378025aad8238a9569098bbfef974769419b6202d867fb24b948f698d2a5204', 'Exadev Global Group', 'corporate_office', '{corporate_office,point_of_interest,establishment}', '{"x_m": -7694.17, "y_m": -7885.23, "bearing": 224.2974, "distance": 11017.13}', '{"motion": "UNKNOWN", "confidence": "high"}', 2235.0580486130266, '{corporate_office,service,service,finance}', 5.9, '{5.9,5.9,5.9,6.52}', NULL),
	('ffc4f398-53de-4f9d-9bc8-9ea2975b9fb0', '2026-02-20 08:45:31.306978+00', 51.498789391228314, -0.14193134315797507, 'Altest1', '92bf2db3e2a41ed304844ea13be4a8039edecd8566db887c6e2594d783607de9', 'Palace theater', 'tourist_attraction', '{tourist_attraction,point_of_interest,establishment}', '{"x_m": -8142, "y_m": -9549.65, "bearing": 220.4508, "distance": 12549.42}', '{"motion": "UNKNOWN", "confidence": "high"}', 2512.9112320581644, '{post_office,medical_clinic,astrologer,pub}', 14.4, '{14.75,15.39,15.39,15.39}', NULL),
	('5ee8dbf9-bda8-44fd-b10f-f3193c35be36', '2026-02-20 08:46:53.028457+00', 51.52414669405861, -0.12946440259246358, 'Altest1', '3194c0fea2bd54b5e8c57940c2102db39896645a0d32c64685bacd2569c9d051', 'Doctoral School, SOAS University of London', 'educational_institution', '{educational_institution,point_of_interest,establishment}', '{"x_m": -7274.96, "y_m": -6731.36, "bearing": 227.2226, "distance": 9911.42}', '{"motion": "UNKNOWN", "confidence": "high"}', 3450.055123607735, '{preschool,university,lodging,research_institute}', 13.87, '{22.83,22.83,25.99,34.44}', NULL),
	('ec57ff6c-9ff0-48ed-9941-6c53bb4851a2', '2026-02-20 08:48:05.535759+00', 51.52566133561376, -0.09872741974568144, 'Altest1', '9e65e534eeb06ccb1544c9aeefec5b3c0cf4b7073f33cd54749f7630506f2907', 'The Springwell Apartment', 'lodging', '{lodging,point_of_interest,establishment}', '{"x_m": -5148.29, "y_m": -6565.55, "bearing": 218.1013, "distance": 8343.34}', '{"motion": "UNKNOWN", "confidence": "high"}', 2000, '{lodging,lodging,playground,lodging}', 25.75, '{25.78,25.9,36.51,36.72}', NULL),
	('9ef9e429-ed49-45e5-8fb0-51ec785bd34c', '2026-02-20 08:48:59.06465+00', 51.53262065359866, -0.10568879676231202, 'Altest1', '964035406021e6776ba7c6d15fdf233341278558cd673fb6dc5352c0a74798cf', 'Atacama Ltd', 'service', '{point_of_interest,service,establishment}', '{"x_m": -5629.03, "y_m": -5791.2, "bearing": 224.1864, "distance": 8076.13}', '{"motion": "AUTOMOTIVE", "confidence": "high"}', 2000, '{consultant,service,transit_station,coffee_stand}', 6.81, '{6.82,18.35,18.75,19.99}', NULL),
	('0acae6c6-9a1b-4dd3-8b73-c6f155c5657e', '2026-02-20 08:50:23.808197+00', 51.53080368566303, -0.10268965206772133, 'Altest1', '2507ba0d40752fb6dac3234d4703e2a76d9720ea4d9e5f16cde980827fa300eb', 'Cranstoun City Roads', 'association_or_organization', '{non_profit_organization,association_or_organization,point_of_interest,service,establishment}', '{"x_m": -5421.79, "y_m": -5993.46, "bearing": 222.133, "distance": 8081.92}', '{"motion": "AUTOMOTIVE", "confidence": "high"}', 1251.0398044963827, '{lodging,association_or_organization,lodging,lodging}', 7.35, '{9.92,12.65,14.11,16.14}', NULL),
	('f855d36e-fef5-42e9-99d7-7a74f95ace02', '2026-02-20 08:51:54.40002+00', 51.52575927973997, -0.08790015946914426, 'Altest1', '58a8b3a43466c8521463efe0e8db03a62136b9e767b7b38b0f896ec6e525196f', 'Pivotal- The Warehouse P2', 'corporate_office', '{corporate_office,point_of_interest,establishment}', '{"x_m": -4399.23, "y_m": -6555.37, "bearing": 213.8651, "distance": 7894.69}', '{"motion": "AUTOMOTIVE", "confidence": "high"}', 307.0760924551558, '{sandwich_shop,service,school,transit_station}', 23.69, '{25.46,26.27,24.28,27.71}', NULL),
	('2a9f6997-b6dd-4056-87c6-05427fed5400', '2026-02-20 08:53:00.98867+00', 51.525675472969226, -0.08755160876105568, 'Altest1', 'f6dc6db3dbead3a4b83d91a5d43f8da4ce7594010caed63481ba7a7ce2742e56', 'Lennies Sandwich Bar', 'sandwich_shop', '{sandwich_shop,restaurant,food,point_of_interest,establishment}', '{"x_m": -4375.13, "y_m": -6564.71, "bearing": 213.682, "distance": 7889.05}', '{"motion": "AUTOMOTIVE", "confidence": "high"}', 70.65485315583344, '{transit_station,service,corporate_office,service}', 1.84, '{1.96,4.77,12.99,18}', NULL),
	('ffc6c5b1-517c-40b4-b9f1-501ae13c0511', '2026-02-20 08:54:06.232165+00', 51.5251275085658, -0.0877490047630835, 'Altest1', '0ee3236644a2a30458753b46e456906cb1f743ae590275248fda2373c16c8f6f', 'Seeking Perfection Marketing Ltd', 'service', '{point_of_interest,service,establishment}', '{"x_m": -4388.84, "y_m": -6625.62, "bearing": 213.5206, "distance": 7947.38}', '{"motion": "AUTOMOTIVE", "confidence": "high"}', 849.7964512894699, '{NULL,service,NULL,corporate_office}', 1.55, '{1.55,1.55,1.55,1.87}', NULL),
	('8b5df448-f49a-447f-a048-b5cc70242a91', '2026-02-20 08:55:27.116815+00', 51.51972903816084, -0.08868594053841426, 'Altest1', '1b414b76e8342776738d669c321c4f19b29c58c5a28ec2ce87c39efb6a69859e', '20-22 Ropemaker Street Loading Bay', 'service', '{point_of_interest,service,establishment}', '{"x_m": -4454.19, "y_m": -7225.85, "bearing": 211.6507, "distance": 8488.39}', '{"motion": "AUTOMOTIVE", "confidence": "high"}', 932.4035797074182, '{corporate_office,dental_clinic,service,finance}', 10.31, '{13.68,19.83,21.2,21.2}', NULL),
	('10b921df-1ac8-47c9-a4c5-55e3e5e37d57', '2026-02-20 09:01:26.354284+00', 51.505079477818626, -0.08970931349026201, 'Altest1', '818fd7bf30cc9815b954a300fff41ad601f3f37c4699106b5dc708b2be589b34', 'Barclays Bank', 'bank', '{bank,atm,finance,point_of_interest,establishment}', '{"x_m": -4526.45, "y_m": -8854.74, "bearing": 207.0756, "distance": 9944.61}', '{"motion": "WALKING", "confidence": "high"}', 17.02539758492925, '{chocolate_shop,consultant,restaurant,italian_restaurant}', 9.69, '{12.22,14.17,15.73,17.45}', NULL),
	('6f563196-6c59-4841-92ed-8b875458c86f', '2026-02-20 09:02:26.565847+00', 51.50518353003279, -0.08913020281321563, 'Altest1', 'c979ce0bb206f079720b24d71c7393f7e7493d3f37928f30863adc637364ae92', 'Orée Boulangerie', 'bakery', '{bakery,food_store,store,food,point_of_interest,establishment}', '{"x_m": -4486.36, "y_m": -8843.21, "bearing": 206.8997, "distance": 9916.14}', '{"motion": "WALKING", "confidence": "high"}', 14.245954570691152, '{point_of_interest,consultant,medical_clinic,NULL}', 4.29, '{6.1,6.16,6.43,7.72}', NULL),
	('cdf4a4aa-1379-4232-9cdd-fb6b382c28c9', '2026-02-20 09:03:33.634849+00', 51.50469652746355, -0.08794784917710682, 'Altest1', 'fe74a75734d677ddcf0b6c7a744ed0af3a0028baaef6f2261a51a197d31a7021', 'London Knee Clinic', 'medical_clinic', '{point_of_interest,medical_clinic,health,establishment}', '{"x_m": -4404.57, "y_m": -8897.43, "bearing": 206.3372, "distance": 9927.97}', '{"motion": "WALKING", "confidence": "high"}', 14.245954538523446, '{corporate_office,association_or_organization,service,medical_clinic}', 4.78, '{15.56,17.7,16.51,22.29}', NULL),
	('45ab4026-d53a-40a4-a685-19c27519e379', '2026-02-20 09:04:28.716641+00', 51.504279789308555, -0.08717550219028176, 'Altest1', 'bf9d99bdc6bcd07a4268a44ab226b61762a0b43e1238b65436d7b66fefb05a12', 'Science Gallery Café', 'cafe', '{cafe,food,point_of_interest,establishment}', '{"x_m": -4351.15, "y_m": -8943.82, "bearing": 205.9428, "distance": 9946.08}', '{"motion": "WALKING", "confidence": "high"}', 14.24595459083333, '{consultant,service,art_gallery,doctor}', 13.01, '{18.85,19.53,20.61,22.09}', NULL),
	('5e9de4cc-e962-4ed6-896a-89b30d1c4da5', '2026-02-20 09:05:37.884039+00', 51.503661802220286, -0.08617941501210757, 'Altest1', '1e6846f2505712c0f0872356e7c7048c1c08339de195950a84ca8032bc75b205', 'Guy''s Hospital Collecting Box', 'Unknown', '{point_of_interest,establishment}', '{"x_m": -4282.27, "y_m": -9012.59, "bearing": 205.4144, "distance": 9978.21}', '{"motion": "WALKING", "confidence": "high"}', 21.991740463259173, '{doctor,doctor,health,NULL}', 13.91, '{15.57,15.57,15.57,14.66}', NULL),
	('d7eb3a4a-45a5-4db6-86c5-b3b04d29b1cc', '2026-02-20 09:06:44.519302+00', 51.503606680281585, -0.08621450654533515, 'Altest1', '1e6846f2505712c0f0872356e7c7048c1c08339de195950a84ca8032bc75b205', 'Guy''s Hospital Collecting Box', 'Unknown', '{point_of_interest,establishment}', '{"x_m": -4284.7, "y_m": -9018.72, "bearing": 205.4119, "distance": 9984.79}', '{"motion": "WALKING", "confidence": "high"}', 26.678175009414975, '{NULL,doctor,doctor,health}', 9.89, '{18.22,21.99,21.99,21.99}', NULL),
	('d847f38c-2c9e-4cba-be3e-e56c397c00f9', '2026-02-20 09:12:28.656991+00', 51.50352391143656, -0.0863390633141606, 'Altest1', '1e6846f2505712c0f0872356e7c7048c1c08339de195950a84ca8032bc75b205', 'Guy''s Hospital Collecting Box', 'Unknown', '{point_of_interest,establishment}', '{"x_m": -4293.33, "y_m": -9027.92, "bearing": 205.434, "distance": 9996.8}', '{"motion": "STILL", "confidence": "high"}', 7.131714777078641, '{corporate_office,NULL,doctor,doctor}', 8.95, '{14.63,25.53,28.35,33.32}', NULL),
	('4eaf1f4b-5a8a-4db1-9811-319590499b34', '2026-02-20 09:17:23.870638+00', 51.50368167656062, -0.08622688765908224, 'Altest1', '1e6846f2505712c0f0872356e7c7048c1c08339de195950a84ca8032bc75b205', 'Guy''s Hospital Collecting Box', 'Unknown', '{point_of_interest,establishment}', '{"x_m": -4285.55, "y_m": -9010.38, "bearing": 205.4369, "distance": 9977.62}', '{"motion": "UNKNOWN", "confidence": "high"}', 28.06990106765166, '{NULL,doctor,doctor,health}', 12.52, '{10.78,14.16,14.16,14.16}', NULL),
	('26f40cd2-ef88-4f0c-b525-222c6169e0cc', '2026-03-02 11:13:13.323798+00', 37.785834, -122.406417, 'Altest1', '78a3d64a7c6d78eea6c55fc341bbda28f0edb9564fd90e077016725b30b9bec9', 'BART/MUNI Ellis/Stockton Entrance', 'transit_depot', '{transit_depot,transportation_service,point_of_interest,establishment}', NULL, '{"motion": "STILL", "confidence": "unknown"}', 5, '{service,association_or_organization,NULL,NULL}', 9.69, '{30.32,36.1,36.63,42.72}', 'Transportation'),
	('e9f7f102-2d73-4ef2-999f-968edd8d8253', '2026-03-02 11:15:06.726872+00', 37.785834, -122.406417, 'test-MAC', '78a3d64a7c6d78eea6c55fc341bbda28f0edb9564fd90e077016725b30b9bec9', 'BART/MUNI Ellis/Stockton Entrance', 'home', '{transit_depot,transportation_service,point_of_interest,establishment}', '{"x_m": 0, "y_m": 0, "bearing": 0, "distance": 0}', '{"motion": "STILL", "confidence": "unknown"}', 5, '{service,association_or_organization,NULL,NULL}', 9.69, '{30.32,36.1,36.63,42.72}', 'Home'),
	('3397c0d2-789b-4fde-8287-84998e62acb1', '2026-03-02 11:15:38.877144+00', 37.785834, -122.406417, 'test-MAC', '78a3d64a7c6d78eea6c55fc341bbda28f0edb9564fd90e077016725b30b9bec9', 'BART/MUNI Ellis/Stockton Entrance', 'home', '{transit_depot,transportation_service,point_of_interest,establishment}', '{"x_m": 0, "y_m": 0, "bearing": 0, "distance": 0}', '{"motion": "STILL", "confidence": "unknown"}', 5, '{service,association_or_organization,NULL,NULL}', 9.69, '{30.32,36.1,36.63,42.72}', 'Home'),
	('68140fdd-8f1e-4706-8635-280b9badfbf6', '2026-03-02 11:18:02.7806+00', 37.785834, -122.406417, 'test-MAC', '78a3d64a7c6d78eea6c55fc341bbda28f0edb9564fd90e077016725b30b9bec9', 'BART/MUNI Ellis/Stockton Entrance', 'transit_depot', '{transit_depot,transportation_service,point_of_interest,establishment}', NULL, '{"motion": "STILL", "confidence": "unknown"}', 5, '{service,association_or_organization,NULL,NULL}', 9.69, '{30.32,36.1,36.63,42.72}', 'Transportation'),
	('5be31364-fceb-46ce-bbc8-dfe5f76bd923', '2026-03-02 11:24:48.632855+00', 37.785834, -122.406417, 'test-MAC', '78a3d64a7c6d78eea6c55fc341bbda28f0edb9564fd90e077016725b30b9bec9', 'BART/MUNI Ellis/Stockton Entrance', 'transit_depot', '{transit_depot,transportation_service,point_of_interest,establishment}', NULL, '{"motion": "STILL", "confidence": "unknown"}', 5, '{service,association_or_organization,NULL,NULL}', 9.69, '{30.32,36.1,36.63,42.72}', 'Transportation'),
	('fbca1733-9b39-4d71-bb7d-fed91678b305', '2026-03-02 11:29:14.063404+00', 37.785834, -122.406417, 'test-MAC', '78a3d64a7c6d78eea6c55fc341bbda28f0edb9564fd90e077016725b30b9bec9', 'BART/MUNI Ellis/Stockton Entrance', 'transit_depot', '{transit_depot,transportation_service,point_of_interest,establishment}', NULL, '{"motion": "STILL", "confidence": "unknown"}', 5, '{service,association_or_organization,NULL,NULL}', 9.69, '{30.32,36.1,36.63,42.72}', 'Transportation'),
	('775c11c2-11cf-47a5-9ef7-1a653b42ed29', '2026-02-06 13:25:12.434339+00', 51.6033, -0.107, 'test-MAC', 'e482a4d38bac14347a6bb738272ba513230cae81534966ce923324d04b6dfa2a', 'White Hart Lane Recreation Ground', 'park', '{park,point_of_interest,establishment}', '{"bearing": 4.66, "distance": 10632.06}', '{"motion": "walking", "confidence": "high"}', 5, '{}', NULL, NULL, NULL),
	('c70aefc3-7651-4d6e-810b-66fb4be5054f', '2026-02-06 13:25:57.99983+00', 51.6033, -0.1081, 'test-MAC', '9dc4d2ea252020772e687af0980a6c4be5a73a0a5611c227ee4f46f426312403', 'Earlham Primary School', 'primary_school', '{primary_school,school,point_of_interest,establishment}', '{"bearing": 4.25, "distance": 10626.15}', '{"motion": "walking", "confidence": "high"}', 5, '{}', NULL, NULL, NULL),
	('08dbacb4-926d-47be-960f-4a7f94b85840', '2026-02-06 13:32:23.923443+00', 51.5322, -0.1058, 'test-MAC', '5095b3d00470f57ffc9801d8442335f3f5958731b487aa3c98588b172b17b779', 'Angel Station', 'Unknown', '{point_of_interest,establishment}', '{"bearing": 19.47, "distance": 2842.63}', '{"motion": "cycling", "confidence": "medium"}', 5, '{}', NULL, NULL, NULL);


--
-- Data for Name: diary_journey_entries; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: diary_visits; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: diary_visit_entries; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: gcplar_responses; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."gcplar_responses" ("id", "completed_at", "attend_live_performance", "attend_museum_gallery", "browse_internet", "dentist", "disco_nightclub", "doctor_gp", "exercise_class", "go_to_friends_house", "high_street_store", "holiday_daytrip", "hospital", "local_shop_post_office", "look_at_books_magazines", "participate_in_performance_arts", "participate_in_sport", "play_games_with_others", "restaurant_cafe", "social_club_society", "social_networking_internet", "spend_time_with_family", "supermarket_large_retail", "swimming", "device_id") VALUES
	('e77076d8-33cf-4b6c-b81f-7b4290d598ab', '2026-03-16 10:49:59.762346+00', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'A001');


--
-- Data for Name: places; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: spatial_ref_sys; Type: TABLE DATA; Schema: public; Owner: supabase_admin
--



--
-- Data for Name: whodas_responses; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."whodas_responses" ("id", "completed_at", "d1_1", "d1_2", "d1_3", "d1_4", "d1_5", "d1_6", "d2_1", "d2_2", "d2_3", "d2_4", "d2_5", "d3_1", "d3_2", "d3_3", "d3_4", "d4_1", "d4_2", "d4_3", "d4_4", "d4_5", "d5_1", "d5_2", "d5_3", "d5_4", "d5_5", "d5_6", "d5_7", "d5_8", "d6_1", "d6_2", "d6_3", "d6_4", "d6_5", "d6_6", "d6_7", "d6_8", "whodas_complex_score", "device_id", "do1_score", "do2_score", "do3_score", "do4_score", "do5_score", "do6_score") VALUES
	('ae18d3e2-b745-4d25-aee1-6d005039abbd', '2026-03-16 10:49:59.762346+00', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, 'A001', 0, 0, 0, 0, 0, 0);


--
-- Data for Name: buckets; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: buckets_analytics; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: buckets_vectors; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: objects; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: s3_multipart_uploads; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: s3_multipart_uploads_parts; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: vector_indexes; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: hooks; Type: TABLE DATA; Schema: supabase_functions; Owner: supabase_functions_admin
--



--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE SET; Schema: auth; Owner: supabase_auth_admin
--

SELECT pg_catalog.setval('"auth"."refresh_tokens_id_seq"', 1, false);


--
-- Name: places_place_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"public"."places_place_id_seq"', 1, false);


--
-- Name: hooks_id_seq; Type: SEQUENCE SET; Schema: supabase_functions; Owner: supabase_functions_admin
--

SELECT pg_catalog.setval('"supabase_functions"."hooks_id_seq"', 1, false);


--
-- PostgreSQL database dump complete
--

-- \unrestrict LTbopz0pI2wZpNsgfDVRZk9sdgbLMdZ4LKoJpzuU2hoqEpbO6nymEB908QAoFUN

RESET ALL;
