# Contributing a task

Keep each Harbor task self-contained under `tasks/<task-name>/` with its instruction, task metadata, environment image, oracle solution, verifier, and reviewer README.

Before submitting a task:

1. Use the current Terminal-Bench task template and set the author fields you want published.
2. Confirm task-specific assumptions are stated in `instruction.md`.
3. Run the repository's static checks, Harbor quality review, Oracle run, and no-op run.
4. Test at least one current agent and review its trajectory to calibrate difficulty.
5. Follow the Terminal-Bench contribution guide and seek maintainer feedback on the proposal.

Run Harbor commands from the repository root. Examples are in the root README.
