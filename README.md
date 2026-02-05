# YTGratitudeApp Documentation

## Overview
This repo is a small microservice-based Gratitude & Mood journal. A React client calls a set of REST endpoints that fan out to gRPC services for data in Postgres, plus an S3-backed files service and an OpenAI-backed AI mentor flow.

## Architecture
High-level flow (default ports shown):

Client (React, :3000)
  -> /api/journal/*  -> api-gateway (:5000) -> gRPC entries-service (:50051) -> Postgres (entries)
  -> /api/ai/*       -> api-gateway (:5000) -> OpenAI API
  -> /api/moods/*    -> moods-api (:5002)   -> gRPC moods-service (:50052) -> Postgres (moods)
  -> /api/stats/*    -> stats-api (:5003)   -> gRPC stats-service (:50053) -> Postgres (entries, moods)
  -> /api/files/*    -> files-service (:5004) -> S3
  -> /api/server/*   -> server-main (:5001) -> Postgres (values, entries) [legacy]

gRPC contracts live in `protos/*.proto`. Each gRPC service currently loads proto files from a local `protos/` folder inside its service directory, so copy or symlink the files from `/protos` before running (see setup below).

## Services
- `client`: React UI with journal, moods, stats, files, and AI mentor views.
- `services/api-gateway`: REST facade for journal entries + AI endpoints (OpenAI).
- `services/entries-service`: gRPC service for journal entries (Postgres).
- `services/moods-api`: REST facade for moods (gRPC).
- `services/moods-service`: gRPC service for moods (Postgres).
- `services/stats-api`: REST facade for stats (gRPC).
- `services/stats-service`: gRPC service that aggregates entries + moods in Postgres.
- `services/files-service`: REST file upload/list/download backed by S3.
- `services/server-main`: legacy Express server with `/values` and `/entries` endpoints.

## Environment variables
Set these in the shell before starting each service (no dotenv loader is used).

### Postgres (used by entries-service, moods-service, stats-service, server-main)
- `PGUSER`: Postgres user
- `PGHOST`: Postgres host
- `PGDATABASE`: Database name
- `PGPASSWORD`: Postgres password
- `PGPORT`: Postgres port (e.g. 5432)

### gRPC services
- `HOST`: bind host (default `0.0.0.0`) for entries-service, moods-service, stats-service
- `PORT`: gRPC port
  - entries-service default: `50051`
  - moods-service default: `50052`
  - stats-service default: `50053`

### REST services
- api-gateway
  - `PORT` (default `5000`)
  - `ENTRIES_SERVICE_ADDR` (default `entries-cluster-ip-service:50051`)
  - `OPENAI_API_KEY` (required for AI endpoints)
  - `OPENAI_MODEL` (default `gpt-4o-mini`)
- moods-api
  - `PORT` (default `5002`)
  - `MOODS_SERVICE_ADDR` (default `moods-service-cluster-ip-service:50052`)
- stats-api
  - `PORT` (default `5003`)
  - `STATS_SERVICE_ADDR` (default `stats-service-cluster-ip-service:50053`)
- files-service
  - `PORT` (default `5004`)
  - `AWS_REGION` (default `us-east-1`)
  - `S3_BUCKET` (required)
  - `S3_PREFIX` (optional key prefix)
  - `FILE_MAX_MB` (default `10`)
  - AWS credentials are picked up from the default AWS SDK chain (for example `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, optional `AWS_SESSION_TOKEN`).
- server-main
  - `PORT` (default `5001`)
  - Postgres vars listed above

## Database setup
The services create tables automatically on startup, but the database and user must exist.

Required Postgres tables:
- `entries` (created by entries-service, stats-service, server-main)
  - `id SERIAL PRIMARY KEY`
  - `text TEXT NOT NULL`
  - `created_at TIMESTAMPTZ DEFAULT NOW()`
- `moods` (created by moods-service, stats-service)
  - `id SERIAL PRIMARY KEY`
  - `mood TEXT NOT NULL`
  - `note TEXT`
  - `created_at TIMESTAMPTZ DEFAULT NOW()`
- `values` (legacy, created by server-main)
  - `number INT`

Example Postgres bootstrap (adjust to your environment):
```bash
createdb gratitude
createuser gratitude_user
psql -c "ALTER USER gratitude_user WITH PASSWORD 'secret';"
psql -c "GRANT ALL PRIVILEGES ON DATABASE gratitude TO gratitude_user;"
```

## Local development commands
Install dependencies once per package:
```bash
# from repo root
(cd client && npm install)
(cd services/api-gateway && npm install)
(cd services/entries-service && npm install)
(cd services/moods-service && npm install)
(cd services/moods-api && npm install)
(cd services/stats-service && npm install)
(cd services/stats-api && npm install)
(cd services/files-service && npm install)
(cd services/server-main && npm install)
```

Copy proto files into each gRPC service and the gateway:
```bash
mkdir -p services/entries-service/protos services/moods-service/protos services/stats-service/protos services/api-gateway/protos
cp protos/*.proto services/entries-service/protos
cp protos/*.proto services/moods-service/protos
cp protos/*.proto services/stats-service/protos
cp protos/*.proto services/api-gateway/protos
```

Start the backend services (separate terminals):
```bash
# gRPC data services
(cd services/entries-service && npm start)
(cd services/moods-service && npm start)
(cd services/stats-service && npm start)

# REST facades + files
(cd services/api-gateway && npm start)
(cd services/moods-api && npm start)
(cd services/stats-api && npm start)
(cd services/files-service && npm start)
(cd services/server-main && npm start)
```

Run the client:
```bash
(cd client && npm start)
```

### API routing for the client
The frontend calls `/api/...` paths. In development you need a reverse proxy that maps:
- `/api/journal/*` -> `http://localhost:5000/*`
- `/api/ai/*` -> `http://localhost:5000/*`
- `/api/moods/*` -> `http://localhost:5002/*`
- `/api/stats/*` -> `http://localhost:5003/*`
- `/api/files/*` -> `http://localhost:5004/*`
- `/api/server/*` -> `http://localhost:5001/*`

You can use a local reverse proxy (nginx, Caddy, or a small Express proxy) to do this. Without a proxy, update the client to call full URLs.

Steps followed:
  1. kubectl apply -f secrets.yml
  2. kubectl apply -f configmap.yml
  3. cd Database
  4. dineshkumar@Dineshs-MacBook-Pro Database % ls -l
     total 56
     -rw-r--r--@ 1 dineshkumar  staff  1463  5 Feb 19:08 database-deployment-gpt.yml
     -rw-r--r--@ 1 dineshkumar  staff  1675  4 Feb 16:54 database-deployment.yml
     -rw-r--r--@ 1 dineshkumar  staff   206  4 Feb 07:39 database-persistent-vlc.yml
     -rw-r--r--@ 1 dineshkumar  staff   259  4 Feb 07:39 database-pv.yml
     -rw-r--r--@ 1 dineshkumar  staff   110  4 Feb 07:39 database-secret.yml
     -rw-r--r--@ 1 dineshkumar  staff   178  4 Feb 07:39 database-service.yml
     -rw-r--r--@ 1 dineshkumar  staff   149  5 Feb 19:00 init.sql
  5. kubectl create configmap db-init-script --from-file=init.sql
  6. kubectl apply -f database-pv.yml
  7. kubectl apply -f database-persistent-vlc.yml
  8. kubectl apply -f database-deployment.yml
  9. cd ../services/entries-service
  10. kubectl apply -f entries-service-deployment.yml
  11. kubectl apply -f entries-service-service.yml
