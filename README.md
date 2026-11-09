# Tabz Terminal-Bench 3 Task Prototypes

This repository contains two Harbor-style Terminal-Bench task projects:

| Task | Challenge | Local validation |
| --- | --- | --- |
| [`jpeg-carve-thumbs/`](jpeg-carve-thumbs/README.md) | Recover intact JPEGs from raw disk bytes while rejecting decoys and embedded previews. | Oracle recovered all 8 exact originals; hash verifier passed. |
| [`sdcard-photo-recovery/`](sdcard-photo-recovery/README.md) | Recover complete photos from a damaged SD card with one- or two-piece fragmentation. | Revised Oracle recovered all 8 exact originals; hash verifier passed. |

Both are prototypes, not yet officially validated Terminal-Bench submissions. Harbor/Docker runs, no-op tests, current agent calibration, and contributor review remain to be completed. Each task README documents its status and next steps.
