# Sentieon Secondary Analysis — regression test suite

Reusable test bank that exercises each option of every workflow in this
directory. Built per goal 4 of the [Workflows reorganization](../../CLAUDE.md).

## Pass / fail contract

Per the project decision (`../../CLAUDE.md` → "Decisions made so far"):

- **Every workflow run** must finish without error AND produce the
  expected file set (e.g. small-variant VCF + CNV VCF + SV VCF for a
  germline WGS workflow). File contents are NOT compared byte-for-byte
  — they're allowed to drift across VarSeq / dependency upgrades.
- **End-to-end VarSeq workflows** (those that wire through VSPipeline /
  VSClinical) additionally verify a checked-in set of clinically
  relevant variants is retained in the final output. Other content is
  still allowed to differ.

## How to run

```bash
# From this directory:
./run_tests.sh                  # run every test
./run_tests.sh germline         # run tests whose name contains "germline"
./run_tests.sh -k somatic       # same, explicit flag
./run_tests.sh --dry-run        # preview commands without invoking gautil
```

Each test gets its own subdirectory under
`/opt/ghdata/share/devdata/vsw_workflows_data/one-off/sentieon-tests/`
and is **overwritten on each run**. No accumulated debris.

## Layout

- `*.test.json` — one file per test. Specifies workflow path,
  parameters, expected output globs, and (for e2e tests) the clinical
  variant assertion file.
- `run_tests.sh` — driver. Reads each manifest, invokes
  `gautil client workflow-run`, polls to completion, runs verification.
- `_shared/verify_filesets.sh` — globs the output dir, confirms each
  pattern in the manifest matched at least one file.
- `_shared/verify_clinical_variants.sh` — for e2e tests, greps the
  final VarSeq report / VCF for the clinical variant list.
- `logs/<test_name>.log` — per-test gautil output; persists across runs
  so failures can be inspected after the fact.

## Test inventory

See `INVENTORY.md` for the matrix of tests vs. workflow options exercised.
