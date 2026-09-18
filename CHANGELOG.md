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
