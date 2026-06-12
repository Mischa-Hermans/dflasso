# Build the per-scenario instances list

Turns per-element vectors into the named list of per-scenario instances
that
[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md)
and
[`decide()`](https://Mischa-Hermans.github.io/dflasso/reference/decide.md)
expect, with the entry names aligned to the scenarios.

## Usage

``` r
make_instances(scenario, ...)
```

## Arguments

- scenario:

  The per-row scenario vector, the same one passed to
  [`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md).

- ...:

  Named arguments placed into each per-scenario entry by their length.

## Value

A named list with one entry per unique scenario, names aligned to
`as.character(unique(scenario))`, ready to pass as `instances`.

## Details

Each named argument in `...` is placed into every scenario entry by
length:

- length equal to `length(scenario)`: sliced by scenario, so entry `k`
  gets the values for the rows in scenario `k` (per-element data, such
  as item weights).

- length one: recycled, so every entry gets the same scalar (such as a
  shared capacity).

- length equal to the number of scenarios: placed one per instance, so
  entry `k` gets the `k`-th value (such as one grid size per scenario).

List-valued arguments follow the same rules. Slicing is tried before
placement. When the two lengths are equal (one element row per scenario)
the intent is ambiguous, so `make_instances()` errors rather than guess:
pass a list for one-per-scenario placement, or wrap a vector in
[`I()`](https://rdrr.io/r/base/AsIs.html) to force per-element slicing.

## See also

[`dfl_data()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_data.md),
[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md)

Other dflasso data helpers:
[`aid_routing`](https://Mischa-Hermans.github.io/dflasso/reference/aid_routing.md),
[`capital_allocation_demo`](https://Mischa-Hermans.github.io/dflasso/reference/capital_allocation_demo.md),
[`dfl_data()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_data.md),
[`prepare_instances()`](https://Mischa-Hermans.github.io/dflasso/reference/prepare_instances.md),
[`simulate_capital_allocation()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_capital_allocation.md),
[`simulate_knapsack()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_knapsack.md),
[`simulate_shortest_path()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_shortest_path.md)

## Examples

``` r
scenario <- rep(c("a", "b"), each = 3)
make_instances(scenario, weights = c(2, 4, 1, 3, 5, 2), capacity = 50)
#> $a
#> $a$weights
#> [1] 2 4 1
#> 
#> $a$capacity
#> [1] 50
#> 
#> 
#> $b
#> $b$weights
#> [1] 3 5 2
#> 
#> $b$capacity
#> [1] 50
#> 
#> 
make_instances(scenario, capacity = 50)
#> $a
#> $a$capacity
#> [1] 50
#> 
#> 
#> $b
#> $b$capacity
#> [1] 50
#> 
#> 
```
