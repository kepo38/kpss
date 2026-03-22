## Summary
- What changed and why.
- Any user-facing changes?
- Risks or known issues.

## Changes
- List of modified/added files (diff-style is fine).
- Any new tests added.
- Any config changes (CI, etc.).

## Testing steps (local)
- Setup
  - Node.js >= 18
  - npm install
- Run locally
  - npm run dev
- Backend tests
  - npm run test:api
  - npm run test:auth
- Full test suite
  - npm test
- UI tests
  - npm run test:e2e
- Reset
  - npm run test:reset

## CI / PR behavior
- GitHub Actions runs on PRs and pushes to verify tests.
- Check Actions tab for status and logs.

## Rollback plan
- If something breaks, revert this branch and re-run tests after fixes.
