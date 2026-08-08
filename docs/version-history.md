---
layout: default
title: Version History
nav_order: 100
---

# Changelog

## Unreleased

- Preserve fixed benchmark history and add authoring/exported-package release gates.

- Extracted the FFTW transform history from GLNumericalModelingKit into a
  dedicated OceanKit authoring repository.
- Added the FFTWTransforms 0.1.0 MPM contract, source-only licensing policy,
  portable CI, documentation source, and shared OceanKit release caller.
- Migrated the validated bundled-FFTW r2c/c2r and DCT-I/DST-I implementations
  into a self-contained production package root.
- Preserved zero-copy allocation, destructive-inverse, alignment, transactional
  build, static eligibility, and structured fallback contracts.
- Quarantined feasibility benchmarks and canonical artifacts under the
  authoring-only `tools/benchmarks` tree.
