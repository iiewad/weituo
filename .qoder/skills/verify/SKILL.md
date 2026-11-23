---
name: verify
description: Run this repo's done-bar checks (bin/rails test + bin/rubocop) and report results. Use before calling a change done, or when asked to verify/check the work.
---

Run the project's verification checks and report concisely.

1. Run both checks (they are independent; run them in parallel):
   - `bin/rails test` — full Minitest suite (fixtures :all; needs local MySQL at /tmp/mysql.sock).
   - `bin/rubocop` — rubocop-rails-omakase style, no overrides.
2. Report a short summary: pass/fail per check. On failure, list each failing test or offense with `file:line` and the message — no full log dumps.
3. If failures are in code you just changed, fix them and re-run the failing check. Otherwise report and ask before touching unrelated code.
4. Do NOT run the full `bin/ci` (security scans + seed replant) unless the user explicitly asks for it.
5. Do not push, commit, or deploy as part of verification.