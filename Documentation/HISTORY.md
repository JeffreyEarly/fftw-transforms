# GLNumericalModelingKit source history

FFTWTransforms was extracted from
[`JeffreyEarly/GLNumericalModelingKit`](https://github.com/JeffreyEarly/GLNumericalModelingKit)
at source commit `3c5fce2b2df9c892418676ef75ffbc5752216e55`.

- Source path: `Matlab/Spectral/FFTW`
- Source subtree tree: `d8f8e58de659f8c0af8400c003ca98ab9529e1d5`
- Filtered tip: `0281a11f0b6ba32d782bb5887460e1661b6a8bcf`
- Filtered commit count: 35

The tracked source was filtered directly to the new repository root with:

```text
git filter-repo --path Matlab/Spectral/FFTW/ --path-rename Matlab/Spectral/FFTW/: --force
```

Filtering rewrites commit IDs while retaining the FFTW-affecting commit
authors, author dates, commit dates, and messages. The nonzero source-to-filtered
mapping is stored in `tools/history/gl-fftw-commit-map.tsv`.

Historical feasibility and implementation work is recorded in
[GL issues #37–#44](https://github.com/JeffreyEarly/GLNumericalModelingKit/issues?q=is%3Aissue+is%3Aclosed+37..44).
GL issue #34 remains earlier backend context, and GL issue #32 remains related
real-to-real transform context.
