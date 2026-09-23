# ibis.el

Issue maps in plain text for Emacs, backed by Dorian Taylor's
[IBIS vocabulary](https://vocab.methodandstructure.com/ibis#) (v0.7).

An IBIS map records a deliberation: the *issues* raised, the
*positions* taken on them and the *arguments* for and against those
positions. The CogNexus Institute's [IBIS Field
Guide](https://cognexus.org/IBIS_FieldguideVer12012010.pdf) (PDF)
introduces the method. `ibis.el` encodes that vocabulary as data,
parses and serializes the `.ibis` text format, and `ibis-mode` edits
it.

```
? I-1: How should conditions and deadlines be made clear?
  → Rename existing forms only
    - Does not clarify prerequisites or what happens when they fail.
  → Manage state conditions and automatic deadlines separately
    + A deadline can expire while later player actions remain possible.

? I-2: Do pages need to become executable code?
  → Data forms create observers and timers #test
    + Dependencies and writes remain visible.
  → Constrained factories create the same data #test
    + Helpers and a REPL, without arbitrary runtime callbacks.
  → Arbitrary runtime callbacks
    + Flexible composition.
    - Hidden dependencies, side effects, and closure state.

? I-3: What should Tangle do?
  → Collect data forms in one file
    + One artifact; execution stays with the interpreter.
  → Generate an executable entry point with a controlled context
    + Build and inspect it in the REPL.
    - Requires bindings, quoting, or macros; `eval` alone is not enough.
```

## Requirements

Emacs 29.1 or newer. No external dependencies.

## Installation

Put `lisp/` on your `load-path`:

```elisp
(use-package ibis-mode
  :load-path "path/to/ibis.el/lisp"
  :mode "\\.ibis\\'")
```

The transient menu is optional and lives in its own file. Loading it
binds `C-c m`; nothing else depends on it:

```elisp
(use-package ibis-transient
  :load-path "path/to/ibis.el/lisp"
  :after ibis-mode)
```

## The file format

One node per line. Two spaces of indentation nest a node under the one
above it.

| Marker      | Node     | Meaning                    |
|-------------|----------|----------------------------|
| `?`         | issue    | a question under debate    |
| `→` or `->` | position | an answer to an issue      |
| `+`         | argument | supports the position      |
| `-`         | argument | opposes the position       |

After the marker an optional `ID:` names the node so it can be
referred to later, then the node's prose, then any number of trailing
`#hashtags` used as free-form status. A `#` inside the prose stays
prose; only the trailing run is read as tags.

Nesting *is* the relation. The parser derives one IBIS predicate per
line from the marker and the class of its parent:

| child \ parent | issue         | position                 | argument                 |
|----------------|---------------|--------------------------|--------------------------|
| `?`            | `specializes` | `questions`              | `questions`              |
| `→`            | `responds-to` | `specializes` (strict: ✗)| `responds-to` (strict: ✗)|
| `+`            | ✗             | `supports`               | ✗                        |
| `-`            | ✗             | `opposes`                | ✗                        |

A ✗ is a diagnostic rather than an edge: an argument that hangs under
anything but a position is always an error, and a line at column zero
must be an issue.

### Strict grammar

`ibis-strict-grammar` (nil by default) opts into Conklin's stricter
rules, where a position may only respond to an issue. The lenient
default reads a position under a position as `ibis:specializes`, which
the vocabulary allows, and a position under an argument as a response.

## Editing

| Key         | Command                  |
|-------------|--------------------------|
| `TAB`       | `ibis-indent-line`       |
| `RET`       | `ibis-newline-and-indent`|
| `M-RET`     | `ibis-insert-sibling`    |
| `S-RET`     | `ibis-insert-child`      |
| `C-c i`, `C-c ?` | `ibis-insert-issue`  |
| `C-c I`     | `ibis-insert-root-issue` |
| `C-c >`     | `ibis-insert-position`   |
| `C-c +`     | `ibis-insert-pro`        |
| `C-c -`     | `ibis-insert-con`        |
| `C-c t`     | `ibis-toggle-tag`        |
| `C-c TAB`   | `ibis-toggle-fold`       |
| `C-c S-TAB` | `ibis-toggle-fold-all`   |
| `M-<left>`  | `ibis-promote`           |
| `M-<right>` | `ibis-demote`            |
| `M-<up>`    | `ibis-move-up`           |
| `M-<down>`  | `ibis-move-down`         |
| `C-c C-c`   | `ibis-check`             |

`TAB` indents like the line above; pressing it again cycles through
the child and ancestor indentations. The insert commands add a child
line under the node at point, after its subtree, and refuse a nesting
the grammar rejects. `C-c i` with a prefix argument, or off a node
line, starts a new top-level issue after the block at point, as
`C-c I` always does. `M-RET` repeats the marker of the node at point
as a sibling below its subtree; `S-RET` adds the customary child — a
position under an issue, a supporting argument under a position, an
issue under an argument. Typing `->` at the start of a line writes
`→`. `C-c t` completes over the hashtags already used in the buffer
and adds or removes one on the current line.

`M-<left>` and `M-<right>` shift the node at point and its subtree by
one level without touching its marker; `M-<up>` and `M-<down>` swap it
with the sibling above or below, subtree and all.

With `ibis-transient` loaded, `C-c m` opens a menu of these commands
in four columns: navigate (`p`, `n`, `u`, `b`, `f` walk the outline,
`TAB` and `S-TAB` fold, all keeping the menu open), insert, structure (the `M-<arrow>` keys, kept
open so a subtree can be nudged repeatedly), and other (`t` tag, `!`
check, `q` quit).

`outline-minor-mode` is on, so the usual outline commands work.
`C-c TAB` folds the subtree at point or opens it again; `C-c S-TAB`
folds the whole map down to its top-level issues, and opens everything
once nothing nested is left showing. Top-level issues are listed by
`imenu`, and flymake flags what the parser rejects — `C-c C-c` runs it
and shows the list.

## Library

`ibis-parse-buffer` and `ibis-parse-string` return `(NETWORK
. DIAGNOSTICS)`, where diagnostics are `(POSITION . MESSAGE)` pairs.
`ibis-serialize` writes a network back out, normalizing markers and
indentation. The vocabulary itself is queryable: `ibis-subclass-p`,
`ibis-property`, `ibis-inverse`, `ibis-label`, `ibis-preferred`,
`ibis-legal-properties` and `ibis-relation-legal-p`.

## Development

`make help` lists the targets; `make all` compiles with warnings as
errors, lints with package-lint and checkdoc, runs the ERT suite and
then `make test-e2e`, which drives a terminal Emacs inside tmux with
real keystrokes and checks both the buffer and the rendered frame. It
skips itself when tmux is not installed.
