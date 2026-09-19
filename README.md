# ibis.el

Issue maps in plain text for Emacs, backed by Dorian Taylor's
[IBIS vocabulary](https://vocab.methodandstructure.com/ibis#) (v0.7).

An IBIS map records a deliberation: the *issues* raised, the
*positions* taken on them and the *arguments* for and against those
positions. `ibis.el` encodes that vocabulary as data, parses and
serializes the `.ibis` text format, and `ibis-mode` edits it.

```
? I-1: Wie werden Bedingung und Termin verständlich?
  → Bestehende Formen nur umbenennen
    - Klärt Voraussetzungen und Ausfall nicht.
  → Zustandserfüllung und automatischen Termin getrennt verwalten #Empfehlung
    + Termin kann verfallen; spätere Spielerhandlung bleibt möglich.
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

| Key       | Command                  |
|-----------|--------------------------|
| `TAB`     | `ibis-indent-line`       |
| `RET`     | `ibis-newline-and-indent`|
| `C-c ?`   | `ibis-insert-issue`      |
| `C-c >`   | `ibis-insert-position`   |
| `C-c +`   | `ibis-insert-pro`        |
| `C-c -`   | `ibis-insert-con`        |
| `C-c t`   | `ibis-toggle-tag`        |
| `C-c C-c` | `ibis-check`             |

`TAB` indents like the line above; pressing it again cycles through
the child and ancestor indentations. The insert commands add a child
line under the node at point, after its subtree, and refuse a nesting
the grammar rejects. `C-c t` completes over the hashtags already used
in the buffer and adds or removes one on the current line.

Buffers fold with `outline-minor-mode`, top-level issues are listed by
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
errors, lints with package-lint and checkdoc, and runs the ERT suite.
