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
  `ibis-toggle-tag` to add or remove a hashtag on the current line.
- A flymake backend reporting the parser's diagnostics, and
  `ibis-check` to run it.
- A README covering the file format, the nesting rules and the keys.
