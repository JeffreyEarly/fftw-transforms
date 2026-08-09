---
layout: default
title: Transform contracts
nav_order: 3
---

# Transform contracts

FFTWTransforms exposes two production transform classes. Both resolve their
MEX sources relative to the installed class location, so local builds do not
depend on the current working directory.

## Real-to-complex transforms

The final entry in the ordered `dims` list determines the compressed
half-spectrum dimension. For a real array with shape `[nx ny nz]`, `dims=[2 1]`
produces `[floor(nx/2)+1 ny nz]`, while `dims=[1 2]` produces
`[nx floor(ny/2)+1 nz]`.

```matlab
transform = RealToComplexTransform([128 128 32],dims=[2 1]);
spectrum = transform.transformForward(values);
roundTrip = transform.scaleFactor*transform.transformBack(spectrum);
```

FFTW's complex-to-real operation is unnormalized. `scaleFactor` is the
reciprocal product of the transformed dimension lengths. Preserving inverse
calls leave their input unchanged by lazily allocating reusable scratch on the
first preserving call and making exactly one half-spectrum copy. Plan creation,
forward transforms, and destructive-only use retain no spectrum-sized scratch.
The destructive inverse makes no explicit spectrum copy for uniquely owned storage:

```matlab
[spectrum,values] = transform.transformBackIntoArrayDestructive(spectrum,values);
values = transform.scaleFactor*values;
```

Always reassign caller-preallocated and destructive outputs. MATLAB may detach
aliased arrays through copy-on-write, so aliases are outside the zero-copy
guarantee.

## Real-to-real transforms

`RealToRealTransform` applies one-dimensional DCT-I or DST-I operations along a
chosen nonsingleton dimension. Results follow the existing GL endpoint and
normalization conventions, so `scaleFactor` is one.

```matlab
transform = RealToRealTransform([65 128],dims=1, ...
    transform="cosine",dataType="complex");
coefficients = transform.transformForward(values);
roundTrip = transform.transformBack(coefficients);
```

DCT-I retains the transformed length. DST-I returns `N-2` coefficients,
ignores physical input endpoints on the forward transform, and returns exact
zero endpoints on the inverse transform. Complex arrays are processed directly
as batched interleaved real and imaginary components.

## Building and availability

Use `FFTWBackend.capabilities()` to inspect support without compiling. If the
backend is supported but not built, call `FFTWBackend.build()`. Expected
platform, compiler, library, module, alignment, or numerical failures are
returned as structured capability records rather than warnings or exceptions.

The 1.0 provider is MATLAB's bundled FFTW on validated R2026a Apple-silicon
installations. Other R2024b-and-later environments can install the package and
receive structured unavailability for safe fallback.
