# Accessors for a fitted decision-focused lasso

Read pieces of a
[DecisionFocusedLasso](https://Mischa-Hermans.github.io/dflasso/reference/DecisionFocusedLasso-class.md)
object without touching its slots. `proxy_score()`, `adaptive_weight()`,
and `penalty_factor()` return the per-feature vectors named by feature;
`selected_features()` returns the names the primary fit kept;
`coverage()` returns the coverage report (or `NULL` for a
supplied-regret fit); `splits()` returns the stored proxy splits;
`seed()` returns the resolved seed; `lambda_min()`/`lambda_1se()` return
the two standard lambda choices; `problem()` returns the attached
optimisation problem (or `NULL`).

## Usage

``` r
proxy_score(object)

# S4 method for class 'DecisionFocusedLasso'
proxy_score(object)

adaptive_weight(object)

# S4 method for class 'DecisionFocusedLasso'
adaptive_weight(object)

penalty_factor(object)

# S4 method for class 'DecisionFocusedLasso'
penalty_factor(object)

selected_features(object)

# S4 method for class 'DecisionFocusedLasso'
selected_features(object)

coverage(object)

# S4 method for class 'DecisionFocusedLasso'
coverage(object)

splits(object)

# S4 method for class 'DecisionFocusedLasso'
splits(object)

seed(object)

# S4 method for class 'DecisionFocusedLasso'
seed(object)

lambda_min(object)

# S4 method for class 'DecisionFocusedLasso'
lambda_min(object)

lambda_1se(object)

# S4 method for class 'DecisionFocusedLasso'
lambda_1se(object)

problem(object)

# S4 method for class 'DecisionFocusedLasso'
problem(object)
```

## Arguments

- object:

  A
  [DecisionFocusedLasso](https://Mischa-Hermans.github.io/dflasso/reference/DecisionFocusedLasso-class.md)
  object.

## Value

`proxy_score()`, `adaptive_weight()`, and `penalty_factor()` return
named numeric vectors. `selected_features()` returns a character vector.
`coverage()` returns a data frame or `NULL`. `splits()` returns a list
or `NULL`. `seed()` returns a single integer.
`lambda_min()`/`lambda_1se()` return single numbers. `problem()` returns
an
[OptimizationProblem](https://Mischa-Hermans.github.io/dflasso/reference/OptimizationProblem-class.md)
object or `NULL`.

## See also

[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md),
[DecisionFocusedLasso](https://Mischa-Hermans.github.io/dflasso/reference/DecisionFocusedLasso-class.md)

## Examples

``` r
sim <- simulate_capital_allocation(40, 6, 6, seed = 1)
fit <- dfl_fit(
  sim$x, sim$cost, sim$scenario,
  problem = capital_allocation_problem(max_weight = 0.5),
  element_id = sim$element_id,
  control = dfl_control(seed = 1, n_splits = 5L)
)
proxy_score(fit)
#>    feat_01    feat_02    feat_03    feat_04    feat_05    feat_06 
#> 0.47584505 0.27799812 0.07739936 0.28721458 0.17080553 0.11768179 
selected_features(fit)
#> [1] "feat_01" "feat_02" "feat_03" "feat_04"
lambda_min(fit)
#> [1] 0.03070895
```
