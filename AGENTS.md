# AGENTS.md

This file provides guidance to the AI agent when working with code in this repository.

## Stack

- Rails 8.1 / Ruby 3.3.9, MySQL, Hotwire (Turbo + Stimulus), Tailwind CSS via tailwindcss-rails with daisyUI, importmap JS (no JS bundler build step).
- Search: ransack (`@q = Model.ransack(params[:q])`) — models must declare `ransackable_attributes` / `ransackable_associations` explicitly (see `Student`, `SemesterKlass`). Pagination: kaminari (`.page(params[:page])`). State machines: aasm.
- Background jobs, cache and Action Cable are database-backed (solid_queue / solid_cache / solid_cable) against the production databases.

## Commands

- Setup: `bin/setup` (idempotent: bundle install, `db:prepare`, then starts `bin/dev`; `--skip-server`, `--reset`).
- Dev server: `bin/dev` (starts Rails plus the Tailwind watcher via `Procfile.dev`; new styles will not appear without the watcher).
- Full local checks: `bin/ci` (see `config/ci.rb`: rubocop, bundler-audit, importmap audit, brakeman, `bin/rails test`, and test-env `db:seed:replant`).
- Tests: `bin/rails test` (Minitest + `fixtures :all`). Single test: `bin/rails test test/models/semester_test.rb` or `bin/rails test test/models/semester_test.rb:18`. Authenticated controller tests use `sign_in_as(users(:one))` from `test/test_helpers/session_test_helper.rb`.
- Lint: `bin/rubocop` — style is rubocop-rails-omakase defaults, no overrides (`.rubocop.yml` only inherits the gem config).
- Security checks: `bin/bundler-audit`, `bin/importmap audit`, `bin/brakeman`.
- One-off CSS build: `bin/rails tailwindcss:build` (writes `app/assets/builds/tailwind.css`); the Dockerfile runs `assets:precompile` for production.
- CI: `.github/workflows/ci.yml` runs `bin/ci` on pull requests and pushes to `main` (MySQL 8 service, `RAILS_ENV=test`).
- Deploy: Kamal. `.github/workflows/cd.yml` runs `kamal redeploy` on every push to `main`, independently of CI — it does not wait for the checks to pass; do not push to `main` casually. Aliases: `bin/kamal console|shell|logs|dbc` (`config/deploy.yml`).

## Architecture

- Tutoring-school admin app. Root is `admin/students#index` and nearly all routes live under `namespace :admin` (`config/routes.rb`); only session, passwords and `/up` are public.
- Domain chain: `School` → `Campuse` (校区) → `Semester` (per school, ordered by `seq`; `current` / `history` / `related_*` scopes are date-based) → `SemesterKlass` (班级 = semester + grade + subject + genre + seq) → `Course` (课次, `seq`, `start_date`) → `Attendance` (one per course × `KlassStudent`). `SemesterKlass` creates `times` courses in an `after_create`; `Course#start!` creates an Attendance for every enrolled student. `Student` / `Teacher` belong to a campuse; `Guardian`, `DaySchool`, `Grade`, `Subject`, `GradeSubject` are supporting tables.
- Access control: `User` → `UserCampuse` (role `admin` / `manager`, JSON `grade_ids`) → `Campuse`; `Current` (ActiveSupport::CurrentAttributes) holds the session and delegates `user`. `Current.user.grades_by_campuse` / `subjects_by_campuse` limit which grades and subjects a manager sees.
- Request context: `AdminController#set_thread_current` populates `Thread.current[:campuse]`, `[:school]`, `[:semester]` from the session; switching happens in `Admin::CampusesController#switch_thread_campuse` and `Admin::SemestersController#switch_thread_semester`. Views read these directly too (hidden fields and filter forms under `app/views/admin/`) — check views as well as controllers when changing scope.
- State machines (aasm): `Attendance` has 7 statuses with `mark_absent` / `mark_personal_leave` / `mark_sick_leave` / `mark_filled` / `mark_quit` / `mark_transfer` / `mark_rejoin`; `mark_quit` and `mark_transfer` cascade to later courses and update `KlassStudent` (`in` / `out` / `transfer`). `Admin::AttendancesController#mark` dispatches `"mark_#{params[:status]}!"`.
- Reporting: `Admin::SemesterKlassesController#statement` plus `SemesterKlass#new_rate` / `expand_rate` / `reserve_rate` compute 班级报表 using `Semester#related_*` scopes; `copy` / `copy_create` duplicate classes into another semester.
- UI: daisyUI + Tailwind v4 with Turbo/Stimulus; shared navbar / alert / footer / drawer partials live in `app/views/admin/shared/`.

## Gotchas

- `Thread.current[:campuse]`, `Thread.current[:school]`, and `Thread.current[:semester]` hold the logged-in user's currently selected campus/school/semester, set in `AdminController#set_thread_current`. Admin controllers must scope queries by these — never by all of the user's campuses.
- `Campuse` is the intentional model name (misspelled singular): table `campuses`, join model `UserCampuse` (`user_campuses`), routes `campuses`. Do not rename or "fix" it.
- All UI copy is Chinese — keep new views, notices, and labels in Chinese.
- Auth is Rails 8 cookie-session auth via the `Authentication` concern: every controller requires login unless it declares `allow_unauthenticated_access`.
- Local MySQL connects via socket `/tmp/mysql.sock`, user root, no password (`weituo_development` / `weituo_test`). Production uses separate cache/queue/cable databases with their own migration dirs (`db/cache_migrate`, `db/queue_migrate`, `db/cable_migrate`) — schema changes to those go in those dirs; connection URLs come from `*_DATABASE_URL` secrets via `.kamal/secrets`.
- `config/deploy.yml` runs Solid Queue inside Puma (`SOLID_QUEUE_IN_PUMA`) on a single web host; recurring jobs are in `config/recurring.yml`.
- `node_modules/` is NOT gitignored — hundreds of files under `node_modules/daisyui` are committed, so npm upgrades produce large diffs.
- daisyUI is vendored in three places: the tracked `node_modules/daisyui` package, the standalone bundles `app/assets/tailwind/daisyui.mjs` + `daisyui-theme.mjs` (loaded via `@plugin "./daisyui*.mjs"` in `app/assets/tailwind/application.css` because the Tailwind standalone CLI cannot resolve npm packages), and `vendor/javascript/daisyui.js` pinned by `config/importmap.rb` (`pin "daisyui"`, comment still `@5.5.17`, not imported anywhere). Keep all three in sync when upgrading.
- `app/assets/builds/*` and `public/assets` are gitignored — CSS and compiled assets are generated, never committed.
- `db/seeds.rb` generates demo data (including 1000 students); `bin/ci` runs `env RAILS_ENV=test bin/rails db:seed:replant`.
- Commit messages are short and often Chinese; no strict convention beyond that.
