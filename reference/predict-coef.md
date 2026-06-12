# Predicted costs and coefficients from a fitted model

[`predict()`](https://rdrr.io/r/stats/predict.html) turns new feature
rows into the predicted cost vector the decision is made from;
[`coef()`](https://rdrr.io/r/stats/coef.html) returns the sparse
coefficient vector. Neither needs realised costs.

## Usage

``` r
# S4 method for class 'DecisionFocusedLasso'
predict(
  object,
  x_new,
  s = "lambda.min",
  penalty = NULL,
  type = c("response", "coefficients", "nonzero"),
  ...
)

# S4 method for class 'DecisionFocusedLasso'
coef(object, s = "lambda.min", penalty = NULL, ...)
```

## Arguments

- object:

  A
  [DecisionFocusedLasso](https://Mischa-Hermans.github.io/dflasso/reference/DecisionFocusedLasso-class.md)
  object.

- x_new:

  Numeric feature matrix of new rows, columns in the same order (or with
  the same names) as the matrix the fit was trained on.

- s:

  Penalty strength: `"lambda.min"` (default), `"lambda.1se"`, or a
  numeric lambda.

- penalty:

  Which stage to read, `NULL` (default) for the fit's primary stage, or
  one of `"decision"`, `"adaptive"`, `"plain"` to inspect a specific
  stage.

- type:

  What to return. `"response"` (default) gives the predicted cost
  vector, one value per row of `x_new`. `"coefficients"` gives the
  sparse coefficient vector. `"nonzero"` gives the names of the kept
  features.

- ...:

  Unused, present for S4/S3 compatibility.

## Value

[`predict()`](https://rdrr.io/r/stats/predict.html) with
`type = "response"` returns a numeric vector of length `nrow(x_new)`.
With `type = "coefficients"` it returns a sparse coefficient vector
including the intercept. With `type = "nonzero"` it returns a character
vector of kept feature names.
[`coef()`](https://rdrr.io/r/stats/coef.html) returns the sparse
coefficient vector including the intercept.

## See also

[`decide()`](https://Mischa-Hermans.github.io/dflasso/reference/decide.md)
to act on a fit.

Other dflasso workflow:
[`decide()`](https://Mischa-Hermans.github.io/dflasso/reference/decide.md),
[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md),
[`dfl_score()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_score.md),
[`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md)

## Examples

``` r
sim <- simulate_capital_allocation(40, 6, 6, seed = 1)
fit <- dfl_fit(
  sim$x, sim$cost, sim$scenario,
  problem = capital_allocation_problem(max_weight = 0.5),
  element_id = sim$element_id,
  control = dfl_control(seed = 1, n_splits = 5L)
)
head(predict(fit, sim$x))
#> [1] 1.933817 1.936472 1.801834 1.720960 1.641494 1.578352
coef(fit)
#> 7 x 1 sparse Matrix of class "dgCMatrix"
#>              lambda.min
#> (Intercept) -0.02364397
#> feat_01      0.19097869
#> feat_02      0.35781135
#> feat_03      2.05011618
#> feat_04      1.99891549
#> feat_05      .         
#> feat_06      .         
predict(fit, sim$x, type = "nonzero")
#> [1] "feat_01" "feat_02" "feat_03" "feat_04"
```
