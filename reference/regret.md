# Realised regret of the decision focus against the baseline

On held-out data, `regret()` measures how much worse the
decision-focused fit's decisions turned out than the best possible in
hindsight, and does the same for a prediction-focused baseline on the
same instances.

## Usage

``` r
regret(
  object,
  x_test,
  cost_test,
  scenario_test,
  instances_test = NULL,
  element_id_test = NULL,
  s = "lambda.min",
  baseline = c("adaptive", "plain", "none"),
  ...
)

# S4 method for class 'DecisionFocusedLasso'
regret(
  object,
  x_test,
  cost_test,
  scenario_test,
  instances_test = NULL,
  element_id_test = NULL,
  s = "lambda.min",
  baseline = c("adaptive", "plain", "none"),
  ...
)

# S3 method for class 'dfl_regret'
print(x, ...)
```

## Arguments

- object:

  A
  [DecisionFocusedLasso](https://Mischa-Hermans.github.io/dflasso/reference/DecisionFocusedLasso-class.md)
  object.

- x_test:

  Numeric feature matrix of held-out rows.

- cost_test:

  Numeric vector of realised costs for the held-out rows, `NA` allowed
  for unobserved elements.

- scenario_test:

  Vector grouping the held-out rows into instances.

- instances_test:

  Optional named list of per-instance data. `NULL` (default) auto-builds
  it from `scenario_test`.

- element_id_test:

  Optional per-row element ids. `NULL` (default) uses per-scenario row
  positions.

- s:

  Penalty strength for the predicted costs: `"lambda.min"` (default),
  `"lambda.1se"`, or a numeric lambda.

- baseline:

  Which baseline to compare against: `"adaptive"` (default, the
  prediction-focused adaptive lasso), `"plain"` (the plain lasso), or
  `"none"` for no comparison.

- ...:

  Unused, present for S4 compatibility.

- x:

  A `dfl_regret` object.

## Value

An S3 `dfl_regret` object with the mean and per-instance regret for the
decision focus and the baseline, the baseline label, and the instance
counts (`n_instances`, `n_proxy_eligible`, `n_partial_coverage`,
`n_infeasible`). Its [`print()`](https://rdrr.io/r/base/print.html)
shows the head-to-head, the signed percent change, and the coverage
line.

## Details

Instances where a solved element has no realised cost are set aside (and
counted), as are infeasible ones. Both approaches are scored on the same
eligible instances.

## See also

[`decide()`](https://Mischa-Hermans.github.io/dflasso/reference/decide.md),
[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md).

Other dflasso workflow:
[`decide()`](https://Mischa-Hermans.github.io/dflasso/reference/decide.md),
[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md),
[`dfl_score()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_score.md),
[`predict-coef`](https://Mischa-Hermans.github.io/dflasso/reference/predict-coef.md)

## Examples

``` r
sim <- simulate_capital_allocation(60, 6, 6, seed = 1)
fit <- dfl_fit(
  sim$x, sim$cost, sim$scenario,
  problem = capital_allocation_problem(max_weight = 0.5),
  element_id = sim$element_id,
  control = dfl_control(seed = 1, n_splits = 5L)
)
regret(fit, sim$x, sim$cost, sim$scenario)
#> Decision quality vs the prediction-focused approach (dflasso regret)
#>   Lower regret is better. Regret = how much worse a decision was than the
#>   best possible in hindsight, averaged over instances.
#> 
#>   Decision-focused model : 0.21 average regret
#>   Prediction-focused model: 0.34 average regret
#> 
#>   The decision focus cut regret by 36.2% on this held-out data.
#> 
#>   Measured on 60 of 60 instances (100%); 0 set aside for missing costs, 0 had no feasible decision. Both approaches were compared on the same instances.
```
