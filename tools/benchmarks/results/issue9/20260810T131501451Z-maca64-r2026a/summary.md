# FFTW capability memory benchmark

| Field | Value |
|---|---:|
| Status | passed |
| MATLAB | 2026a |
| Architecture | maca64 |

## RSS comparison

| Scenario | Phase | v1.0.2 RSS (MiB) | Candidate RSS (MiB) | Candidate - v1.0.2 (MiB) |
|---|---|---:|---:|---:|
| no-query | startup | 625.562 | 620.406 | -5.156 |
| no-query | no-query-control | 629.828 | 629.312 | -0.516 |
| java-control | startup | 621.078 | 624.109 | +3.031 |
| java-control | java-positive-control | 729.078 | 728.484 | -0.594 |
| compiler-control | startup | 626.000 | 624.078 | -1.922 |
| compiler-control | compiler-discovery-control | 634.484 | 633.906 | -0.578 |
| lifecycle | startup | 626.828 | 625.859 | -0.969 |
| lifecycle | capability-query | 767.812 | 666.031 | -101.781 |
| lifecycle | build-validation | 795.641 | 691.375 | -104.266 |
| lifecycle | plan-construction | 796.219 | 691.984 | -104.234 |
| lifecycle | first-transform | 804.562 | 700.375 | -104.188 |
| lifecycle | repeated-transforms | 808.219 | 704.312 | -103.906 |
| lifecycle | transform-deletion | 808.234 | 704.328 | -103.906 |
| lifecycle | mex-clearing | 807.703 | 703.750 | -103.953 |

## Java-state evidence

See `capability-memory.json` for per-phase `vmmap` evidence, process trees, and raw samples.

## Capability-query attribution

| Measurement | RSS (MiB) |
|---|---:|
| v1.0.2 capability increment | 140.984 |
| Candidate capability increment | 40.172 |
| JVM-free reduction | 100.812 |
