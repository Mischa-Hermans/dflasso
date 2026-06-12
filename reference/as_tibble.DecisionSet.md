# Tidy a decision set into a long table

Returns one row per (instance, element). `element_id` is a real column,
so a `left_join` back onto the original rows matches by id, not by row
order.

## Usage

``` r
# S3 method for class 'DecisionSet'
as_tibble(x, ...)
```

## Arguments

- x:

  A
  [DecisionSet](https://Mischa-Hermans.github.io/dflasso/reference/DecisionSet-class.md)
  object.

- ...:

  Unused, present for method compatibility.

## Value

A tibble with columns `scenario`, `element_id`, `decision`, `chosen`,
`predicted_cost`, `contribution`, `feasible`, and `step`. For an
infeasible instance every element row is kept with `decision`, `chosen`,
and `contribution` set to `NA` and `predicted_cost` still filled.

## See also

[`decide()`](https://Mischa-Hermans.github.io/dflasso/reference/decide.md),
[`decisions()`](https://Mischa-Hermans.github.io/dflasso/reference/decision-set-accessors.md)

## Examples

``` r
sim <- simulate_capital_allocation(40, 6, 6, seed = 1)
fit <- dfl_fit(
  sim$x, sim$cost, sim$scenario,
  problem = capital_allocation_problem(max_weight = 0.5),
  element_id = sim$element_id,
  control = dfl_control(seed = 1, n_splits = 5L)
)
picks <- decide(fit, sim$x, sim$scenario, element_id_new = sim$element_id)
head(as_tibble(picks))
#> # A tibble: 6 × 8
#>   scenario element_id decision chosen predicted_cost contribution feasible  step
#>   <chr>    <chr>         <dbl> <lgl>           <dbl>        <dbl> <lgl>    <int>
#> 1 scenari… 1               0.5 TRUE             1.93        0.967 TRUE        NA
#> 2 scenari… 2               0.5 TRUE             1.94        0.968 TRUE        NA
#> 3 scenari… 3               0   FALSE            1.80        0     TRUE        NA
#> 4 scenari… 4               0   FALSE            1.72        0     TRUE        NA
#> 5 scenari… 5               0   FALSE            1.64        0     TRUE        NA
#> 6 scenari… 6               0   FALSE            1.58        0     TRUE        NA
```
