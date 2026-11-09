# Tabz Terminal-Bench 3 Tasks

This repository organizes each Harbor task under `tasks/<task-name>/`.

| Task | Summary | Current checks |
| --- | --- | --- |
| [`jpeg-carve-thumbs`](tasks/jpeg-carve-thumbs/README.md) | Recover intact JPEGs from disk bytes while rejecting decoys and embedded previews. | Local oracle and hash verifier passed. |
| [`sdcard-photo-recovery`](tasks/sdcard-photo-recovery/README.md) | Recover complete photos from a damaged card with one- or two-piece fragmentation. | Revised local oracle and hash verifier passed. |

## Run task checks

Install Harbor and Docker, then run from the repository root:

```bash
harbor check tasks/jpeg-carve-thumbs
harbor run -p tasks/jpeg-carve-thumbs --agent oracle
harbor run -p tasks/jpeg-carve-thumbs --agent nop

harbor check tasks/sdcard-photo-recovery
harbor run -p tasks/sdcard-photo-recovery --agent oracle
harbor run -p tasks/sdcard-photo-recovery --agent nop
```

These tasks have not had Harbor runs or frontier-agent difficulty calibration yet, so they are prototypes rather than benchmark-validated submissions. Their task READMEs include details and remaining checks.
