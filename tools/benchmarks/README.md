# Authoring benchmarks

This directory contains the feasibility gateways, benchmark harnesses,
canonical results, exploratory scripts, and historical code imported from
`GLNumericalModelingKit/Matlab/Spectral/FFTW`.

None of these files are part of the FFTWTransforms runtime package or its
exported MPM payload. Production MATLAB classes and MEX sources live at the
repository root. Use `fftwBenchmarkPaths` from authoring tools instead of
assuming a current working directory or the former GL repository layout.

`runFFTWCapabilityMemoryBenchmark` compares the released `v1.0.2` capability
path with a clean candidate commit in fresh MATLAB processes. It samples RSS
externally at lifecycle handshakes and records `vmmap` evidence for Java runtime
and heap regions. The default command runs three no-query, explicit-Java,
compiler-discovery, and complete FFTW lifecycle processes per implementation:

```matlab
addpath("tools/benchmarks");
runFFTWCapabilityMemoryBenchmark
```

The canonical measurements are preserved byte-for-byte. Their fixed hashes,
original GL issues and commits, filtered FFTWTransforms commits, library
identities, and recorded working-tree state are listed in
`benchmark-history.json`. Issue #3 owns the history checks and the
installed-package release gate.

## Canonical record

The benchmark record covers GL issues #37, #38, #39, #41, and #43. Issue #40
made a readiness decision and issue #42 hardened production code, so neither
created a canonical benchmark artifact. Native FFTW and Accelerate/vDSP results
remain historical evidence only; the FFTWTransforms 1.0 release gate builds and
validates MATLAB's bundled FFTW.

New benchmark output records both repositories: the active
`JeffreyEarly/fftw-transforms` commit and tree, plus the pinned
`JeffreyEarly/GLNumericalModelingKit` extraction record. The runtime package
does not read this file; static eligibility remains encoded in `FFTWBackend`.
