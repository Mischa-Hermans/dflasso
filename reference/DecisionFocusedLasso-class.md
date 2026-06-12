# A fitted decision-focused lasso

The object
[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md)
returns. It holds the three lasso fits (plain, adaptive, and
decision-focused) on one shared set of folds so they compare directly.
It also keeps the per-feature adaptive weights and decision-relevance
scores that shaped the decision-focused fit. The coverage report and the
resolved seed are stored too.

## Usage

``` r
# S4 method for class 'DecisionFocusedLasso'
show(object)
```

## Slots

- `decision_fit,adaptive_fit,plain_fit`:

  The three `cv.glmnet` fits. All three are computed on one shared
  `foldid` so they are comparable; `penalty` chooses which is primary.

- `adaptive_weight`:

  Numeric vector, one baseline ridge-adaptive weight per feature.

- `proxy_score`:

  Numeric vector, the regret-proxy score per feature.

- `penalty_factor`:

  Numeric vector, the final weights fed to the decision-focused lasso.

- `feature_names`:

  Character vector of feature names.

- `features_named`:

  Single logical, `TRUE` when `x` carried column names at fit, which
  drives new-data matching by name rather than position.

- `element_ids`:

  List of per-scenario element id vectors.

- `coverage`:

  Data frame of the per-scenario coverage report, or `NULL` for a
  supplied-regret fit.

- `problem`:

  The
  [OptimizationProblem](https://Mischa-Hermans.github.io/dflasso/reference/OptimizationProblem-class.md)
  object, or `NULL` for a supplied-regret fit.

- `sense`:

  Character scalar, `"min"` or `"max"`.

- `source`:

  Character scalar, `"solver"` or `"supplied regret"`.

- `penalty_primary`:

  Character scalar, one of `"decision"`, `"adaptive"`, `"plain"`.

- `lambda_min,lambda_1se`:

  Numeric scalars, the two standard `cv.glmnet` lambda choices for the
  primary fit.

- `eligibility_threshold`:

  Single number, the resolved ridge-weight gate; `0` when no weight gate
  applies (the default).

- `n_proxy_eligible,n_partial_coverage`:

  Integer counts of scenarios that could and could not be scored.

- `splits`:

  List of the proxy train/validation splits, or `NULL` for a
  supplied-regret fit.

- `seed`:

  Single integer, the resolved seed.

- `standardize`:

  Single logical.

- `control`:

  The `dfl_control` list the fit obeyed.

- `call`:

  The matched call.

## See also

[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md),
[`proxy_score()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl-accessors.md),
[`penalty_factor()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl-accessors.md),
[`adaptive_weight()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl-accessors.md),
[`selected_features()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl-accessors.md),
[`coverage()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl-accessors.md),
[`splits()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl-accessors.md)
