# FFTWTransforms release gate

Status: **PASSED**

## Environment

| Field | Value |
|---|---|
| MATLAB | 26.1.0.3312084 (R2026a) Update 4 |
| Architecture | maca64 |
| Processor | Apple M5 Max |
| Physical memory | 48.0 GiB |
| MEX compiler | Xcode Clang++ 21.0.0 |
| Candidate source | 3b50801d669fab19ec621f15f039d8f33ec40388 |
| OceanKit exporter commit | 92e618cbc4e47752352643664b4f5f192d663587 |
| Exporter SHA-256 | 8bfe74a13661156abc90bdf0e7fd623bf115b2bc60851d8450a24f445be8f57b |
| FFTW provider | matlab-bundled |
| FFTW version | fftw-3.3.8 |
| Resolved FFTW library | /Applications/MATLAB_R2026a.app/bin/maca64/libmwfftw3.3.dylib |

## Export hygiene

| Check | Result |
|---|---|
| Candidate version | 1.0.0 |
| Pre-build payload digest | 7b5554243a3df81346e073a0d66577275cb68ccd0315e0d92456e010d3e136cb |
| Forbidden files absent | yes |

## Tests

| Tree | Passed | Failed | Incomplete | Seconds |
|---|---:|---:|---:|---:|
| Authoring | 32 | 0 | 0 | 42.14 |
| Exported | 20 | 0 | 0 | 30.35 |

## Numerical validation

| Feature | Maximum relative error | Passed |
|---|---:|---|
| r2c | 1.51e-16 | yes |
| c2r | 3.33e-16 | yes |
| dct1 | 2.62e-16 | yes |
| dst1 | 1.06e-15 | yes |

## Benchmark history

| Record | Value |
|---|---|
| History SHA-256 | cae5c9a7338ad8694df64e9178f033f084331c22f584408b10a925679179ece8 |
| Historical repository | JeffreyEarly/GLNumericalModelingKit |
| Canonical benchmark issues | 37, 38, 39, 41, 43 |
