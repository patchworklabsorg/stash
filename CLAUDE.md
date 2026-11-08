# CLAUDE.md

Guidance for agents working in this repo. Read `README.md` first. The design is in `docs/design.md`, the API contract in `docs/api.md`, the deploy contract in `docs/deploy.md`.

## What this is

Stash is the Patchwork Labs archive: a URL in, durable copies out. Rails 8.1, Ruby 4.0, server-rendered ERB with Tailwind, GoodJob, Active Storage, Weave sign-in. Scaffolded with boxcar, then trimmed to the Patchwork conventions: no password accounts, no Redis, one central database schema.

## Rules

- **One database.** Stash connects only to `patchwork-central`, schema `stash`. Models inherit `CentralRecord`. Migrations go in `db/central_migrate`. Never add a `patchwork-central-restricted` connection.
- **Primary keys are UUIDs. Public ids everywhere.** Every model includes `EncodedIds::UuidIdentifiable` with a prefix registered in internal-docs (`arc`, `cap`, `art`, `aud`). The pages, the API and the logs show the full `public_id`; routes hold the encoded id without the prefix (`use_prefix_in_routes = false`, the org rule in internal-docs public-ids.md). Look up with `CentralRecord.find_by_public_param!`, which takes both forms and answers 404 to a raw UUID. Never find by primary key from a parameter. Timestamps are UTC.
- **Weave owns identity and roles.** People are keyed on the Weave `sub`, never on email. Roles `viewer`, `archivist`, `admin` come from the `roles` claim; `Weave::Roles` is the only place that knows the keys. Stash stores the `sub` only, never a name or email (the member data rule in internal-docs). All Weave HTTP goes through `app/services/weave/`.
- **Authorization is in `ArchivePolicy`** (Pundit). Controllers call `authorize` and `policy_scope`; no inline role checks for archives.
- **The API checks tokens with `Weave::Introspection`** (scope `stash`), caches by a SHA-256 of the token, never the raw token. Never log a token. The contract is `docs/api.md`: change it there too.
- **Capture rules live in `Capturers::Router`**, with the table at the top. One class per method in `app/services/capturers/`. A capturer writes into its work directory and returns `Capturers::Output`s; `CaptureJob` stores them. Change the router table, the design doc and `docs/api.md` together.
- **External tools run through `Capturers::Subprocess`**: arguments as a list, a clean environment, a timeout, an output cap. Never build a shell string from a URL. Never run code from archived content.
- **Limits:** `CAPTURE_TIMEOUT` and `CAPTURE_MAX_BYTES` (`Capturers.timeout`, `Capturers.max_bytes`). A capture past a limit fails with the reason in `error`; the other captures of the archive still run.
- **Nothing is public.** Every page and every artifact needs a signed-in person. Artifacts download through a short-lived signed storage URL.
- **Admin changes write an `AuditEvent`** with a required reason. Audit events are append-only.
- **Dev sign-in** (`STASH_AUTH_MODE=dev`) is for development and tests. The app refuses to boot with it in production and staging.
- **strong_migrations is on.** Use `safety_assured` only with a comment that says why.
- **No secrets in the repo.** `.env.example` holds placeholders only.

## Commands

```sh
docker compose up -d          # Postgres on localhost:5436
bin/setup --skip-server       # gems, bun, database
bin/dev                       # server on :3000, Tailwind, GoodJob
bin/rails test
bin/rubocop
npx @herb-tools/linter && npx @herb-tools/formatter --check
bin/brakeman --no-pager && bin/bundler-audit
docker build -t stash .       # the production image (docs/deploy.md)
```

## Tests

Minitest. Every router rule gets a test. Every route gets a happy-path test and an authz test. Integration tests sign in with `sign_in_as(:admin)` (dev sign-in). `FakeWeave` in `test/support` stubs Weave's OIDC and introspection endpoints. `FakeCapturer` stands in for the capturers; `stub_method` in `test_helper.rb` swaps a module method for a block. Tests never call the network (WebMock) and never run a tool. `CaptureJobTest` runs without a transaction, because Active Storage uploads after commit.

## Style

Short, plain sentences in docs, comments, commits and PRs. Active voice. No em dashes. Commits use Conventional Commits with no attribution.
