ALWAYS start your session with `make help`; it explains the automation
actions and development flows.

During work:
- Develop elephant carpaccio style: slice the work into the thinnest possible
  end-to-end increments, each independently shippable and committable. Prefer many
  thin vertical slices over one horizontal layer. Each slice should leave the build
  green (`make all`).
- Use red/green TDD with ERT unit tests. For every slice: write a failing test
  (red), make it pass (green), then refactor.
- Create git commits as small as possible as you go.

Elisp conventions:
- No code comments; docstrings on every definition.
- Regexps with `rx`.
- Private symbols use the `ibis--` prefix.
- `user-error` for interactive errors.
- Minimum Emacs 29.1, no external dependencies.
