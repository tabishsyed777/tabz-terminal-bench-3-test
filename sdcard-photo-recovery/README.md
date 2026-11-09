# SD Card Photo Recovery

Terminal-Bench/Harbor task prototype for recovering exact JPEG files from a damaged raw SD card image. It is intentionally more involved than the single-file carving task: files can be fragmented, data from other photos can appear between fragments, and some images are incomplete.

## Contents

- `instruction.md` — agent-facing recovery request and storage constraints
- `environment/` — Ubuntu task image and raw card dump
- `solution/solve.sh` — reference solution
- `tests/` — deterministic hash and source-integrity verifier
- `generator/` — synthetic card builder for maintainers
- `task.toml` — Harbor timeouts, resources, and task metadata

## Verification status

The original reference solver was too slow for a 120-second local check. The revised solver bounds candidate reconstruction using the stated 14-cluster and file-size limits, validates image decoding with Pillow, and strictly checks that the baseline JPEG entropy stream ends at the expected image boundary.

Local verification passed: the revised oracle recovered all eight expected JPEGs, the included hash verifier returned `PASS`, and the source-card checksum matched. Harbor and Docker were unavailable in the authoring environment, so no Harbor Oracle, no-op, or agent calibration run is claimed here.

## Run with Harbor

From the task directory, after installing Harbor and Docker:

```bash
harbor check . -m anthropic/claude-opus-4-7
harbor run -p . --agent oracle
harbor run -p . --agent nop
```

The Oracle should achieve reward `1.0`; the no-op agent should achieve `0.0`. Review agent runs to confirm the task is difficult for the intended benchmark and not merely slow to execute. Terminal-Bench 3 asks contributors to get task proposals reviewed before implementation.

## Rebuild the fixture

Install dependencies from `generator/requirements.txt` and run `python3 generator/build_card.py` from the task root. Compare regenerated `environment/card.img` and `tests/expected.json` with the checked-in files before replacing fixtures; image encoding can vary by library version.

## Before submission

- Set `metadata.author_email` in `task.toml` to the email you want associated with the task.
- Run the current Terminal-Bench static checks, Harbor quality review, Oracle and no-op runs.
- Confirm the proposal with Terminal-Bench maintainers.
