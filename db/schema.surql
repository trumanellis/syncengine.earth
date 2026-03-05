-- SyncEngine Early Access Signup Schema
-- Run this against your SurrealDB instance to set up the signup system.
--
-- Usage:
--   surreal sql --endpoint wss://your-instance.surreal.cloud --token <token> < db/schema.surql
--
-- Then set DB.url in index.html to your SurrealDB endpoint.

-- Namespace & database
DEFINE NAMESPACE IF NOT EXISTS syncengine;
USE NS syncengine;
DEFINE DATABASE IF NOT EXISTS main;
USE DB main;

-- Signup records table
DEFINE TABLE IF NOT EXISTS signup SCHEMALESS PERMISSIONS FOR create WHERE $access = 'earlyaccess', FOR select, update, delete NONE;

-- Indexes
DEFINE INDEX IF NOT EXISTS signup_email ON signup FIELDS email;
DEFINE INDEX IF NOT EXISTS signup_created ON signup FIELDS created_at;

-- Record access method for public signup (no credentials needed on client)
DEFINE ACCESS IF NOT EXISTS earlyaccess ON DATABASE TYPE RECORD SIGNUP (CREATE signup SET name = $name, need = $need, location = $location, focus = $focus, skills = $skills, offer = $offer, collab = $collab, email = $email, tag = $tag, time_spent = $time_spent, stages = $stages, created_at = time::now(), source = 'homepage') SIGNIN (SELECT * FROM signup WHERE email = $email LIMIT 1) DURATION FOR SESSION 1h;
