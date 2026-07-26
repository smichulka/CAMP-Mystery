# Contributing

## Branch and merge rules

- Implement multi-file features on a dedicated branch (`feature/`, `fix/`, `chore/`).
- Run `python scripts/run_all_checks.py --require-rojo` locally before opening a
  pull request. The gate must pass before any commit is pushed to `main`.
- Open a pull request. Do not push implementation commits directly to `main`.
- Require the `Validate CAMP-Mystery / structural-validation` check to be green
  before merging.
- Merge only complete, synchronized implementation + tests in a single squash or
  merge commit. Do not intentionally push red intermediate slices to `main`.

## Communication channel

All Claude↔ChatGPT messages go through `ClaudChat/`. See the folder README for
the protocol.
