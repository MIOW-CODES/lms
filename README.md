# MIOW LMS

MIOW (MSU-IIT IDS Online Workspace) is a learning management system for junior and senior high school, built with TanStack Start, React, TypeScript, Tailwind CSS, and PostgreSQL.

## Local development

Requirements: Bun and Docker Engine with Compose.

```sh
git clone https://github.com/MIOW-CODES/lms.git
cd lms
bun install --frozen-lockfile
Copy-Item .env.example .env   # PowerShell; edit the required values
# On macOS/Linux: cp .env.example .env
docker compose up -d postgres
bun run db:migrate
bun run dev
```

Open `http://127.0.0.1:3000`. Set a unique `SESSION_SECRET` in `.env`, for example from `openssl rand -hex 32`. Never use shared/demo credentials or real student information in a development database.

## Database

The application uses **native PostgreSQL only**. Supabase services, SDKs, provider autodetection, and Supabase credentials are not supported. The server uses its custom signed-session authentication and accesses PostgreSQL using `DATABASE_URL`. Uploaded materials and avatars use local filesystem storage under `STORAGE_PATH`.

For a local-only development database, Compose uses a local development password. Replace it with a strong private value before starting PostgreSQL; never expose this database port to the internet. Production must use separate migration-owner and non-superuser application roles, private networking, and secret values outside the repository. See [ORANGE_PI_DEPLOYMENT_PLAN.md](ORANGE_PI_DEPLOYMENT_PLAN.md) for the native schema conversion and Orange Pi/Nginx Proxy Manager deployment plan.

## Environment

See `.env.example`. Required runtime settings:

- `DATABASE_URL` — PostgreSQL connection string.
- `SESSION_SECRET` — random secret used to sign session tokens.
- `STORAGE_PATH` — persistent local upload directory.

`PG_POOL_MAX` limits per-process database connections. AI and Google integrations are optional and independent from the database.

## Features

- PIN login and RFID attendance with server-side session and role checks.
- Student, teacher, and administrator dashboards.
- Course, enrollment, assignment, quiz, grading, and attendance workflows.
- Course-material and submission-file uploads.
- Optional academic assistant and Google document import.

## Commands

```sh
bun run dev
bun run typecheck
bun run lint
bun run test
bun run test:e2e
bun run build
bun run db:up
bun run db:migrate
bun run db:seed
```

The default unit-test command covers `src/`. Run database integration and browser tests separately as documented by the relevant scripts/workflows.

## License

Private — MSU-IIT IDS
