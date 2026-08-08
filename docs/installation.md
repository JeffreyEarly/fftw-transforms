---
layout: default
title: Installation and capability detection
nav_order: 2
---

# Installation and capability detection

FFTWTransforms will be distributed through OceanKit as an MPM package. During
development, construct the authoring package from the repository root with
`matlab.mpm.Package`.

Capability inspection never triggers a build:

```matlab
capabilities = FFTWBackend.capabilities();
```

On a supported system, build locally when required:

```matlab
if capabilities.build.isRequired && capabilities.build.isPossible
    capabilities = FFTWBackend.build();
end
```

No precompiled MEX file or FFTW library is included in the package.
