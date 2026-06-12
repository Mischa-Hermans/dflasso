# Broom methods for a fitted decision-focused lasso

The broom verbs for a
[DecisionFocusedLasso](https://Mischa-Hermans.github.io/dflasso/reference/DecisionFocusedLasso-class.md)
fit. [`tidy()`](https://generics.r-lib.org/reference/tidy.html) returns
one row per feature with its decision-stage coefficient, its
decision-relevance score, the penalty the decision focus used, and its
role. [`glance()`](https://generics.r-lib.org/reference/glance.html)
returns a one-row model summary.
[`augment()`](https://generics.r-lib.org/reference/augment.html) runs
[`decide()`](https://Mischa-Hermans.github.io/dflasso/reference/decide.md)
on new rows and attaches the predicted cost (and, with a solver, the
decision) under broom's `.`-prefix convention.
[`augment()`](https://generics.r-lib.org/reference/augment.html) reads
only the features, never the realised cost.

## Usage

``` r
# S3 method for class 'DecisionFocusedLasso'
tidy(x, s = "lambda.min", ...)

# S3 method for class 'DecisionFocusedLasso'
glance(x, ...)

# S3 method for class 'DecisionFocusedLasso'
augment(
  x,
  x_new,
  scenario_new,
  instances_new = NULL,
  element_id_new = NULL,
  newdata = NULL,
  s = "lambda.min",
  ...
)
```

## Arguments

- x:

  A
  [DecisionFocusedLasso](https://Mischa-Hermans.github.io/dflasso/reference/DecisionFocusedLasso-class.md)
  object.

- s:

  Penalty strength the reported coefficient is read at: `"lambda.min"`
  (default), `"lambda.1se"`, or a numeric lambda.

- ...:

  Unused, present for method compatibility.

- x_new:

  Numeric feature matrix of new rows, the
  [`decide()`](https://Mischa-Hermans.github.io/dflasso/reference/decide.md)
  features.

- scenario_new:

  Vector grouping the new rows into instances.

- instances_new:

  Optional named list of per-instance data, `NULL` auto-builds it from
  `scenario_new`.

- element_id_new:

  Optional per-row element ids, `NULL` uses per-scenario row positions.

- newdata:

  Optional data frame to attach the decision columns to, joined on
  `(scenario, element_id)`. `NULL` attaches them to a fresh element-row
  tibble.

## Value

[`tidy()`](https://generics.r-lib.org/reference/tidy.html) returns a
tibble with one row per feature and columns `term`, `estimate`,
`proxy_score`, `adaptive_weight`, `penalty_factor`, `role`.
[`glance()`](https://generics.r-lib.org/reference/glance.html) returns a
one-row tibble of model-level fields.
[`augment()`](https://generics.r-lib.org/reference/augment.html) returns
the new rows with `.predicted_cost` (and the decision columns when a
solver is available) attached.

## See also

[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md),
[summary.DecisionFocusedLasso](https://Mischa-Hermans.github.io/dflasso/reference/summary.DecisionFocusedLasso.md),
[`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md)

## Examples

``` r
sim <- simulate_capital_allocation(60, 6, 6, seed = 1)
fit <- dfl_fit(
  sim$x, sim$cost, sim$scenario,
  problem = capital_allocation_problem(max_weight = 0.5),
  element_id = sim$element_id,
  control = dfl_control(seed = 1, n_splits = 5L)
)
tidy(fit)
#> # A tibble: 6 × 6
#>   term    estimate proxy_score adaptive_weight penalty_factor role              
#>   <chr>      <dbl>       <dbl>           <dbl>          <dbl> <fct>             
#> 1 feat_01  0.300         0.429          11.3            1.24  decision-relevant 
#> 2 feat_05 -0.00551       0.341        1226.             1.24  decision-relevant 
#> 3 feat_02  0.243         0.333          13.3            1.24  decision-relevant 
#> 4 feat_06  0.00130       0.225        2274.             1.24  decision-relevant 
#> 5 feat_03  1.95          0.201           0.302          0.302 prediction-releva…
#> 6 feat_04  1.95          0.125           0.301          0.301 prediction-releva…
glance(fit)
#> # A tibble: 1 × 12
#>    nobs n_instances n_proxy_eligible n_partial_coverage n_features n_selected
#>   <int>       <int>            <int>              <int>      <int>      <int>
#> 1   360          60               60                  0          6          6
#> # ℹ 6 more variables: lambda_min <dbl>, lambda_1se <dbl>, sense <chr>,
#> #   penalty_primary <chr>, source <chr>, seed <int>
augment(fit, sim$x, sim$scenario, element_id_new = sim$element_id)
#> # A tibble: 360 × 8
#>    scenario element_id .decision .chosen .predicted_cost .contribution .feasible
#>    <chr>    <chr>          <dbl> <lgl>             <dbl>         <dbl> <lgl>    
#>  1 scenari… 1                0.5 TRUE              1.35          0.674 TRUE     
#>  2 scenari… 2                0.5 TRUE              1.30          0.650 TRUE     
#>  3 scenari… 3                0   FALSE             1.20          0     TRUE     
#>  4 scenari… 4                0   FALSE             1.08          0     TRUE     
#>  5 scenari… 5                0   FALSE             1.04          0     TRUE     
#>  6 scenari… 6                0   FALSE             0.922         0     TRUE     
#>  7 scenari… 1                0   FALSE            -1.36          0     TRUE     
#>  8 scenari… 2                0   FALSE            -1.37          0     TRUE     
#>  9 scenari… 3                0   FALSE            -1.39          0     TRUE     
#> 10 scenari… 4                0   FALSE            -1.36          0     TRUE     
#> # ℹ 350 more rows
#> # ℹ 1 more variable: .step <int>
```
