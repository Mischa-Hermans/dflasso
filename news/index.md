# Changelog

## dflasso 0.1.0

- First release.
- [`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md)
  fits a sparse linear cost model and selects features by how much they
  change the decision.
- Built-in shortest-path, knapsack and capital-allocation problems, plus
  a custom-solver through
  [`optimization_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/optimization_problem.md).
- [`decide()`](https://Mischa-Hermans.github.io/dflasso/reference/decide.md)
  turns features into decisions;
  [`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md)
  reports the held-out comparison against a prediction-focused baseline;
  [`dfl_score()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_score.md)
  ranks features from out-of-sample regret supplied directly.
- Paired simulators and the demo datasets `aid_routing` and
  `capital_allocation_demo`.
- tidy, glance and augment methods, ggplot2 views, a routing vignette, a
  Dockerfile and R-CMD-check across Linux, Windows and macOS.
