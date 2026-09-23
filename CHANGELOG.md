# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `ibis-transient`, an optional module: `(require 'ibis-transient)` binds `C-c m` to a menu of navigation, insert, structure and other commands.
- `ibis-insert-root-issue` (`C-c I`) starts a new top-level issue after the block at point.
- `C-c i` as an unshifted binding for `ibis-insert-issue`; with a prefix argument, or off a node line, it starts a top-level issue.

### Fixed
- `ibis-insert-issue` no longer errors off a node line.

## [0.1.0] - 2026-09-21

### Added

- IBIS vocabulary 0.7 as data: classes with their hierarchy and
  disjointness, properties with labels, inverses, domains, ranges and
  preferred direction, and the legality table for issues, positions and
  arguments.
- An in-memory graph of nodes, edges and networks with parent and child
  traversal.
- A parser for the `.ibis` text format returning a network and
  diagnostics, with `ibis-strict-grammar` for Conklin's nesting rules,
  and a serializer that round-trips it.
- `ibis-mode`, a major mode for `.ibis` files: font-lock for markers,
  identifiers and hashtags, outline folding, an imenu index of the
  top-level issues, `TAB` indentation cycling and `RET` that keeps the
  indentation.
- Commands to insert a child issue, position or argument under the
  node at point, refusing a nesting the grammar rejects, and
  `ibis-toggle-tag` (`C-c t`) to add or remove a hashtag on the current
  line.
- `ibis-insert-sibling` (`M-RET`) and `ibis-insert-child` (`S-RET`),
  which repeat the marker of the node at point as a sibling or add the
  child its class calls for, and the replacement of a `->` marker typed
  at the start of a line with `→`.
- `ibis-promote` and `ibis-demote` (`M-<left>` and `M-<right>`) to shift
  a node and its subtree by one level, and `ibis-move-up` and
  `ibis-move-down` (`M-<up>` and `M-<down>`) to swap it with a sibling.
- A flymake backend reporting the parser's diagnostics, and
  `ibis-check` to run it.
- A README covering the file format, the nesting rules and the keys.
