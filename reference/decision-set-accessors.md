# Read decisions out of a decision set

Accessors for a
[DecisionSet](https://Mischa-Hermans.github.io/dflasso/reference/DecisionSet-class.md)
object. The list and vector accessors are named by `scenario` id, so
`names(which(!is_feasible(set)))` gives the failing scenarios and
`sum(objectives(set))` totals without building a tibble.

## Usage

``` r
decisions(object)

# S4 method for class 'DecisionSet'
decisions(object)

selected_elements(object)

# S4 method for class 'DecisionSet'
selected_elements(object)

objectives(object)

# S4 method for class 'DecisionSet'
objectives(object)

is_feasible(object)

# S4 method for class 'DecisionSet'
is_feasible(object)

element_sequence(object)

# S4 method for class 'DecisionSet'
element_sequence(object)
```

## Arguments

- object:

  A
  [DecisionSet](https://Mischa-Hermans.github.io/dflasso/reference/DecisionSet-class.md)
  object.

## Value

`decisions()`, `selected_elements()`, and `element_sequence()` return
lists named by scenario; each `decisions()` entry is a numeric vector
named by element id. `objectives()` returns a numeric vector named by
scenario; `is_feasible()` returns a logical vector named by scenario.

## See also

[`decide()`](https://Mischa-Hermans.github.io/dflasso/reference/decide.md),
[`feasible()`](https://Mischa-Hermans.github.io/dflasso/reference/decision-set-feasibility.md),
[`infeasible_reasons()`](https://Mischa-Hermans.github.io/dflasso/reference/decision-set-feasibility.md)

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
decisions(picks)[[1]]
#>   1   2   3   4   5   6 
#> 0.5 0.5 0.0 0.0 0.0 0.0 
is_feasible(picks)
#> scenario_01 scenario_02 scenario_03 scenario_04 scenario_05 scenario_06 
#>        TRUE        TRUE        TRUE        TRUE        TRUE        TRUE 
#> scenario_07 scenario_08 scenario_09 scenario_10 scenario_11 scenario_12 
#>        TRUE        TRUE        TRUE        TRUE        TRUE        TRUE 
#> scenario_13 scenario_14 scenario_15 scenario_16 scenario_17 scenario_18 
#>        TRUE        TRUE        TRUE        TRUE        TRUE        TRUE 
#> scenario_19 scenario_20 scenario_21 scenario_22 scenario_23 scenario_24 
#>        TRUE        TRUE        TRUE        TRUE        TRUE        TRUE 
#> scenario_25 scenario_26 scenario_27 scenario_28 scenario_29 scenario_30 
#>        TRUE        TRUE        TRUE        TRUE        TRUE        TRUE 
#> scenario_31 scenario_32 scenario_33 scenario_34 scenario_35 scenario_36 
#>        TRUE        TRUE        TRUE        TRUE        TRUE        TRUE 
#> scenario_37 scenario_38 scenario_39 scenario_40 
#>        TRUE        TRUE        TRUE        TRUE 
```
