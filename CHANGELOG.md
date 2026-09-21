# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

### Fixed

- `ibis-mode` indents with spaces, so shifting a subtree into column
  eight no longer writes a tab that turns the line into one the parser
  rejects.
- A subtree now reaches across the blank lines inside it, the way the
  parser does: `ibis-demote`, `ibis-move-up`, `ibis-move-down` and
  `ibis-insert-sibling` take the whole block instead of leaving its
  tail behind under a parent it never had.
- An inserted top-level sibling is separated by a blank line from the
  block below it as well as from the one above, without doubling a
  separator that is already there.
- A subtree and a sibling are now read off the parser, so a line the
  parser cannot read is as transparent to `ibis-demote`, `ibis-move-up`
  and `ibis-move-down` as it is to the nesting itself: a node below such
  a line moves with the subtree it belongs to, and a sibling behind one
  is found instead of reported missing.
- A shift that fails halfway, such as one in a read-only buffer, no
  longer leaves a marker behind pointing into the buffer.
