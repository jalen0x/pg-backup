# pg-backup

PostgreSQL scheduled backup to S3-compatible storage. Designed to run as a [Kamal](https://kamal-deploy.org/) accessory alongside your main application.

## How it works

A lightweight container based on `postgres:15` that runs `pg_dump` on a cron-like schedule, uploads compressed backups to S3, and cleans up files older than the retention window. Optionally pings a heartbeat URL after each successful backup.

## Usage

Build and push the image, then add it as an accessory in your project's `config/deploy.yml`.

### 1. Build the image

```bash
docker build -t yourorg/pg-backup .
docker push yourorg/pg-backup
```

### 2. Add accessory to your project

In your application's `config/deploy.yml`:

```yaml
accessories:
  db-backup:
    image: yourorg/pg-backup
    host: 10.0.0.1
    env:
      clear:
        POSTGRES_PORT: 5432
        PGDATABASE: myapp_production
        BUCKET: my-bucket/backups
        HOST_BASE: s3.eu-central-1.amazonaws.com
        SCHEDULE: "0 9 12 16"
        RETENTION_DAYS: 7
        HEARTBEAT_URL: "https://status.example.com/ping/xxx"
      secret:
        - ACCESS_KEY_ID
        - SECRET_ACCESS_KEY
        - POSTGRES_USER
        - POSTGRES_PASS
        - POSTGRES_HOST
```

### 3. Configure secrets

In your application's `.kamal/secrets`, add the corresponding secret values:

```bash
ACCESS_KEY_ID=...
SECRET_ACCESS_KEY=...
POSTGRES_USER=...
POSTGRES_PASS=...
POSTGRES_HOST=...
```

### 4. Deploy

```bash
kamal accessory boot db-backup
```

## Environment variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `PGDATABASE` | Yes | — | Database name |
| `POSTGRES_HOST` | Yes | — | Database host |
| `POSTGRES_USER` | Yes | — | Database user |
| `POSTGRES_PASS` | Yes | — | Database password |
| `POSTGRES_PORT` | No | `5432` | Database port |
| `BUCKET` | Yes | — | S3 bucket (and optional prefix) |
| `ACCESS_KEY_ID` | Yes | — | S3 access key |
| `SECRET_ACCESS_KEY` | Yes | — | S3 secret key |
| `HOST_BASE` | Yes | — | S3 endpoint (e.g. `s3.amazonaws.com`) |
| `SCHEDULE` | No | `0 9 12 16` | Backup hours in UTC, space-separated |
| `RETENTION_DAYS` | No | `7` | Days to keep old backups |
| `HEARTBEAT_URL` | No | — | URL to POST after each backup |

## Manual backup

```bash
docker exec <container> /backup.sh --once
```
