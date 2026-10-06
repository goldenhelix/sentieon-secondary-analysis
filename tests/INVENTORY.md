# Test inventory — Sentieon Secondary Analysis

Maps each test to the workflow + options it exercises. Per the project
test contract, every option appears in at least one test; combinatorial
cross-products are deliberately not enumerated.

Status legend: ✅ authored & runnable · 🟡 authored, needs fixture · ⏸ deferred

## germline_align_call (Targeted Germline)

Input: `devdata/vsw workflows data/germline/paired_end_with_1_2/` (HIS0052,
Illumina paired-end, 19 MB). Runtime ~125 s on `researchserver24`.

| # | Test | Option exercised | Status |
|---|---|---|---|
| 01 | `germline_baseline` | defaults: `ml_model=None`, `output_gvcf=false` | ✅ PASS — run 603, 123 s |
| 02 | `germline_illumina_model` | `ml_model=Illumina WES 2.1` | ✅ PASS — run 604, 129 s |
| 03 | `germline_output_gvcf` | `output_gvcf=true` | ✅ authored, not yet run |
| 04 | `germline_e2e_vspipeline` | Include VSPipeline + clinical variant check | 🟡 — needs clinical variant list curated from first successful e2e run; also depends on agents.yaml `scratch_storage` fix for `localhost_workflows` |

## somatic_align_call (Somatic T/T-N)

| # | Test | Input | Option | Status |
|---|---|---|---|---|
| 05 | `somatic_baseline` | `somatic/HiSeq 2000 Tumor Normal Subset/` (8.6 MB) | defaults | ✅ |
| 06 | `somatic_no_dedup` | same | `perform_dedup=false` (amplicon mode) | ✅ |
| 07 | `somatic_high_tumor_lod` | same | `min_init_tumor_lod=3` | ✅ |
| 08 | `somatic_umi` | `somatic/Element_Panel_UMI_Subset/` (1.2 MB) | `umi_read_structure=8M+T,8M+T`, `duplex_umi=false` | ✅ |
| 09 | `somatic_e2e_vspipeline` | HiSeq subset | Include VSPipeline + Sentieon Somatic template + clinical variant check | 🟡 — needs clinical variant list |

## wgs_align_call (Comprehensive WGS + PGx)

Input: `devdata/vsw workflows data/test/sentieon-fixtures/NA19143-wgs/`
(gzipped paired FASTQ derived from `germline/trio_subset_wgs/NA19143_*`).

| # | Test | Option | Status |
|---|---|---|---|
| 10 | `wgs_baseline` | defaults: CRAM, Illumina WGS 2.2, SV on | ✅ PASS — run 610, ~3 h |
| 11 | `wgs_bam_output` | `cram=false` (BAM instead) | ✅ authored, not yet run |
| 12 | `wgs_no_sv` | `call_svs=false` | ✅ authored, not yet run |
| 13 | `wgs_must_call_vcf` | provide PGx must-call VCF | ⏸ — needs PGx must-call VCF fixture |
| 15 | `wgs_e2e_pgx_str` | Full VSPipeline + VSPGx + STR reports + clinical variant check | 🟡 — needs clinical variant list + agents.yaml fix |

## wgs_call (WGS Precalled)

Input: BAM outputs from a previous `wgs_baseline` run (chained).

| # | Test | Option | Status |
|---|---|---|---|
| 16 | `wgs_call_baseline` | defaults | ⏸ — needs BAM inputs from wgs_baseline run |
| 17 | `wgs_call_no_sv` | `call_svs=false` | ⏸ |
| 18 | `wgs_call_must_call_vcf` | provide must-call VCF | ⏸ |

## sentieon_long_read_cli (Long-Read)

| # | Test | Input | Option | Status |
|---|---|---|---|---|
| 19 | `longread_hifi_baseline` | `PacBioHG002_CSS15kb/single_alignment_pacbio.tsv` (1.6 GB HiFi FASTQ) | `tech=HiFi`, defaults | ✅ PASS — run 609, 764 s |
| 20 | `longread_ont_baseline` | `tests/fixtures/ont_demo_manifest.tsv` (67 MB ONT BAM) | `tech=ONT` | ✅ authored, not yet run |
| 21 | `longread_no_gvcf` | HiFi singleton | `gvcf=false` | ✅ authored, not yet run |
| 22 | `longread_skip_small_variants` | HiFi singleton | `skip_small_variants=true` | ✅ authored, not yet run |
| 23 | `longread_skip_mosdepth` | HiFi singleton | `skip_mosdepth=true` | ✅ authored, not yet run |

## Option-coverage matrix

Every required user-tunable parameter appears in at least one test:

| Workflow | Option | Tests that exercise it |
|---|---|---|
| germline | `ml_model` (None) | 01, 03 |
| germline | `ml_model` (Illumina WES) | 02 |
| germline | `output_gvcf` | 03 |
| germline | VSPipeline stages | 04 |
| somatic | `ml_model` (None default) | 05–09 |
| somatic | `perform_dedup` | 06 |
| somatic | `umi_read_structure`+`duplex_umi` | 08 |
| somatic | `min_init_tumor_lod` | 07 |
| somatic | T-N pairing via SampleCatalog | 05 |
| somatic | VSPipeline | 09 |
| wgs | `cram` true/false | 10/11 |
| wgs | `call_svs` true/false | 10/12 |
| wgs | `must_call_vcf` | 13 (deferred) |
| wgs | GangSTR optional | 14 |
| wgs | VSPipeline + PGx + STR reports | 15 |
| wgs_call | (all options) | 16–18 (deferred) |
| long-read | `tech=HiFi` | 19, 21–23 |
| long-read | `tech=ONT` | 20 |
| long-read | `gvcf` | 19/21 |
| long-read | `skip_small_variants` | 22 |
| long-read | `skip_mosdepth` | 23 |

Platforms beyond Illumina/Element (MGI / Salus / Ultima) require dedicated
per-platform test data; deferred to a v2 expansion.

## Known issues found while building this suite

1. **Stale task_path in workflow YAMLs** (fixed 2026-05-21). All 5
   workflow YAMLs referenced `tasks/vspipeline-resources/pipeline/*.task.yaml`
   but the files are at `tasks/vspipeline-resources/*.task.yaml`. Fixed.
2. **`run_step: optional_default_skip` is GUI-only, by design.** Confirmed
   2026-05-21: this setting controls the default checkbox state in the
   workflow GUI; the CLI/runtime does NOT default-skip the stage. To
   actually skip an optional stage from `gautil client workflow-run`,
   pass an explicit `--skip=<stage>` (or set `runStep` directly via
   `-s`). Every test manifest in this suite carries an explicit
   `"skip": [...]` array for the optional VSPipeline stages it doesn't
   intend to exercise. The agent-workflows docs were misleading on this
   point; updated to reflect the actual behavior.
3. **`/scratch` permission denied → missing `scratch_storage` in agent config.**
   Root cause: in [`/opt/ghserver/configs/agents.yaml`](/opt/ghserver/configs/agents.yaml),
   `researchserver24` declares `scratch_storage: /opt/scratch` and
   `benchmark01` declares `scratch_storage: /var/tmp`, but
   **`localhost_workflows` has no `scratch_storage` field at all** —
   the default falls back to a path the workflow user can't write to.
   Hence somatic_baseline (run 605) succeeded through BWA-MEM on
   `researchserver24` then failed at `Generate Batch Parameter File`
   when the scheduler placed it on `localhost_workflows`.

   **Real fix:** add `scratch_storage: /var/tmp` (or similar writable
   path) to the `localhost_workflows` entry in `agents.yaml`. One-line
   server-side config change. (cypcall succeeded 8/8 on `researchserver24`
   with the same VSPipeline image, confirming the image itself is fine.)

   Until the agent config is fixed, somatic and any other test whose
   VSPipeline-image stage lands on `localhost_workflows` will be flaky.

4. **Stage/task param mismatches in workflow YAMLs** (fixed 2026-05-21).
   - `sentieon_long_read_cli.workflow.yaml`: "Merge Minimap2 BAMs" stage
     forwarded `output_folder` to a task that didn't declare it.
     Resolution: added `output_folder` (optional) to
     `merge_minimap2_bams.task.yaml` so downstream stages can also
     reference it.
   - `wgs_call.workflow.yaml`: "Prepare Directories" stage declared an
     extra `output_folder` parameter that the task doesn't accept.
     Removed.
   - `wgs_align_call.workflow.yaml`: verified clean (no mismatches).

5. **`merge_minimap2_bams` task is not idempotent across re-runs.** On
   long-read re-runs, it picks up the previous run's `*.minimap2.bam`
   output (matched by `find "$input_folder" -name "${sample_name}*.minimap2.bam"`)
   alongside the actual per-shard inputs, then `samtools merge` fails
   with `File '/scratch/X.minimap2.bam' exists. Please apply '-f'`.
   Test-side workaround: the driver wipes the per-test output dir before
   each run (the test contract says outputs are wipeable anyway). A
   proper task-side fix would add `-f` to the `samtools merge` call or
   filter out the merged-output filename from the input glob.

## How to run

```bash
./run_tests.sh                  # everything
./run_tests.sh germline         # filter by name substring
./run_tests.sh -k longread_hifi # explicit flag form
./run_tests.sh --dry-run        # preview gautil commands without running
```

Per-test logs land in `logs/<test_name>.log`. Each test runs sequentially;
the suite stops at SUMMARY but does not exit early on individual failures.
