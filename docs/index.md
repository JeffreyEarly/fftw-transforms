---
layout: default
title: Home
nav_order: 1
description: "Reusable FFTW transforms for MATLAB"
permalink: /
---

# FFTWTransforms

FFTWTransforms provides reusable real-to-complex, complex-to-real, DCT-I, and
DST-I transforms backed by the FFTW library shipped with MATLAB.

The package distributes source only. Supported installations build MEX gateways
locally against the active MATLAB installation; unsupported installations return
structured capability information without attempting compilation.

## Initial support target

The first validated backend targets MATLAB R2026a on Apple silicon (`maca64`).
The MPM package installs on MATLAB R2024b or later so consumers can detect an
unavailable backend and use their existing fallback.
