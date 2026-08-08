# Authoring benchmarks

This directory contains the feasibility gateways, benchmark harnesses,
canonical results, exploratory scripts, and historical code imported from
`GLNumericalModelingKit/Matlab/Spectral/FFTW`.

None of these files are part of the FFTWTransforms runtime package or its
exported MPM payload. Production MATLAB classes and MEX sources live at the
repository root. Use `fftwBenchmarkPaths` from authoring tools instead of
assuming a current working directory or the former GL repository layout.

The canonical measurements are preserved unchanged here. Issue #3 owns their
full provenance validation and installed-package release gate.
