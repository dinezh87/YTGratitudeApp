CREATE USER gratitude_user WITH PASSWORD 'postgres%';
CREATE DATABASE gratitude_db;
GRANT ALL PRIVILEGES ON DATABASE gratitude_db TO gratitude_user;
