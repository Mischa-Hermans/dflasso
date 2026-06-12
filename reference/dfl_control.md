# Options for a dflasso fit

Collects every setting a
[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md)
run uses into one validated object. The arguments fall into two groups.
The main settings are a seed, whether to run in parallel, whether to
print progress, and the cross-validation and coverage controls. The
method settings control how the decision-relevance score rescales each
feature's penalty; their defaults are tuned.

## Usage

``` r
dfl_control(
  seed = NULL,
  parallel = FALSE,
  workers = NULL,
  progress = interactive(),
  standardize = TRUE,
  min_elements_per_scenario = 2L,
  nfolds = 10L,
  gamma = 2,
  kappa = 6,
  proxy_score_reference = 0.2,
  w_min = 0.1,
  w_max = 500,
  n_splits = 15L,
  split_fraction = 0.7,
  eligibility_threshold = NULL,
  score_floor = 0.001,
  ...
)
```

## Arguments

- seed:

  Single integer, or `NULL` (default) to draw one at random. The
  resolved seed is stored on the fit.

- parallel:

  Single logical, default `FALSE`. Run the proxy loop in parallel.

- workers:

  Single positive integer, or `NULL` (default). The number of parallel
  workers: set it to start a cluster of that size and run in parallel;
  `NULL` leaves parallelism to `parallel`.

- progress:

  Single logical, default
  [`interactive()`](https://rdrr.io/r/base/interactive.html). When
  `TRUE`, the decision-quality step prints a one-line start and a
  `Done.` when it finishes; when `FALSE`, that step is silent.

- standardize:

  Single logical, default `TRUE`, passed to glmnet's `standardize`,
  which scales features for the fit and returns coefficients on the
  original scale.

- min_elements_per_scenario:

  Single positive integer, default `2`. Drop scenarios smaller than this
  after missing costs are removed.

- nfolds:

  Single integer of at least 3 (glmnet's minimum), default `10`.
  Cross-validation folds for the final weighted lasso.

- gamma:

  Single positive number, default `2`. The adaptive-weight exponent in
  `1 / abs(beta_ridge)^gamma`.

- kappa:

  Single positive number, default `6`, the decision-relevance strength.
  A rescued feature's penalty is `w_max * exp(-kappa * rescaled_score)`,
  so a higher `kappa` discounts a high-scoring feature harder.

- proxy_score_reference:

  Single positive number, default `0.2`, typically `(0, 1]`. The
  reference the proxy score is rescaled against; must be positive
  because it divides the score.

- w_min:

  Single positive number below `w_max`, default `0.1`. The lower bound
  on the final weights.

- w_max:

  Single positive number above `w_min`, default `500`. The upper bound
  on the final weights, and where the rescue starts: a decision-relevant
  feature is pulled down from `w_max` by its score, so it reaches a
  selectable penalty whatever its raw adaptive weight.

- n_splits:

  Single integer of at least 2, default `15`. The train/validation
  resamples the proxy averages over.

- split_fraction:

  Single number in `(0, 1)`, default `0.7`. The training share within
  each proxy split.

- eligibility_threshold:

  `NULL` (default) or a single positive number, a minimum adaptive
  weight for rescue. `NULL` applies no such gate: a feature is rescued
  on its decision-relevance score alone, whatever its adaptive weight. A
  positive number (such as one from
  [dflasso_tuned_thresholds](https://Mischa-Hermans.github.io/dflasso/reference/dflasso_tuned_thresholds.md))
  restricts the rescue to features whose adaptive weight is at least
  that.

- score_floor:

  Single positive number, default `1e-3`. Raw proxy scores below this
  trigger no discount.

- ...:

  Caught only to reject unknown arguments with a did-you-mean
  suggestion.

## Value

A validated list of class `dfl_control`, ready to pass to the `control`
argument of
[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md).

## Details

`dfl_control()` validates everything up front, so a bad value or a
mistyped name fails at the call rather than inside a fit. An unknown
argument is rejected with a did-you-mean suggestion.

## See also

[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md),
[dflasso_tuned_thresholds](https://Mischa-Hermans.github.io/dflasso/reference/dflasso_tuned_thresholds.md)

## Examples

``` r
dfl_control()
#> <dfl_control>
#> main:
#>   seed                       NULL
#>   parallel                   FALSE
#>   workers                    NULL
#>   progress                   FALSE
#>   standardize                TRUE
#>   min_elements_per_scenario  2
#>   nfolds                     10
#> method settings:
#>   gamma                      2
#>   kappa                      6
#>   proxy_score_reference      0.2
#>   w_min                      0.1
#>   w_max                      500
#>   n_splits                   15
#>   split_fraction             0.7
#>   eligibility_threshold      NULL
#>   score_floor                0.001
dfl_control(seed = 2024, workers = 8)
#> <dfl_control>
#> main:
#>   seed                       2024
#>   parallel                   FALSE
#>   workers                    8
#>   progress                   FALSE
#>   standardize                TRUE
#>   min_elements_per_scenario  2
#>   nfolds                     10
#> method settings:
#>   gamma                      2
#>   kappa                      6
#>   proxy_score_reference      0.2
#>   w_min                      0.1
#>   w_max                      500
#>   n_splits                   15
#>   split_fraction             0.7
#>   eligibility_threshold      NULL
#>   score_floor                0.001
dfl_control(eligibility_threshold = dflasso_tuned_thresholds[["knapsack"]])
#> <dfl_control>
#> main:
#>   seed                       NULL
#>   parallel                   FALSE
#>   workers                    NULL
#>   progress                   FALSE
#>   standardize                TRUE
#>   min_elements_per_scenario  2
#>   nfolds                     10
#> method settings:
#>   gamma                      2
#>   kappa                      6
#>   proxy_score_reference      0.2
#>   w_min                      0.1
#>   w_max                      500
#>   n_splits                   15
#>   split_fraction             0.7
#>   eligibility_threshold      20
#>   score_floor                0.001
```
