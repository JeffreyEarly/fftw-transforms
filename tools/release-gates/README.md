# Release gates

`runFFTWTransformsReleaseGate` validates the authoring checkout and a clean
simulated `FFTWTransforms-1.0.0` export made by OceanKit's real release helper.
It records the exact OceanKit commit and exporter hash used for each run.

Run the canonical Apple gate from a clean tracked checkout:

```matlab
addpath("tools/release-gates")
runFFTWTransformsReleaseGate
```

Portable CI sets `requireCanonicalPlatform=false`. That route validates package
identity, export hygiene, snapshot-only loading, and structured backend
unavailability without compiling a MEX file. Native FFTW is not built by either
route.
