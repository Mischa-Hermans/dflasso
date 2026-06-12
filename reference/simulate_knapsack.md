# Simulate a knapsack problem

Builds an example predict-then-optimize dataset for the 0/1 knapsack.
Each scenario is one realisation of uncertain item values; the optimiser
picks items to maximise value under a single capacity. Item weights are
fixed random integers across scenarios.

## Usage

``` r
simulate_knapsack(n_scenarios, n_items, n_features, seed = NULL)
```

## Arguments

- n_scenarios:

  Number of scenarios, each one optimisation instance.

- n_items:

  Number of items per scenario.

- n_features:

  Number of feature columns. The first two are the decision-relevant
  features, the next few predict the return, and the rest are noise.
  Must be at least three.

- seed:

  Single integer, or `NULL` to draw one at random. The same seed gives
  the same data.

## Value

A list with `data` (a data frame: `feat_01` .. `feat_<n_features>`,
`realized_value`, `scenario`, `item_id`, and `weight`), plus `x`, `cost`
(the realized values), `scenario`, `weights` (the per-item weights),
`capacity` (a default budget of half the total item weight, a binding
limit), and `item_id`. Pass the weights and the capacity through
[`make_instances()`](https://Mischa-Hermans.github.io/dflasso/reference/make_instances.md).

## Details

The true value of item `i` in scenario `s` follows the same equation as
[`simulate_capital_allocation()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_capital_allocation.md):
prediction-heavy scenario-level features move every item's value
together, the two decision-relevant features are per-item
(`g_sj loading_i + small noise`) with a small coefficient, and the rest
are noise.

## See also

[`simulate_capital_allocation()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_capital_allocation.md),
[`simulate_shortest_path()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_shortest_path.md),
[`knapsack_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/knapsack_problem.md)

Other dflasso data helpers:
[`aid_routing`](https://Mischa-Hermans.github.io/dflasso/reference/aid_routing.md),
[`capital_allocation_demo`](https://Mischa-Hermans.github.io/dflasso/reference/capital_allocation_demo.md),
[`dfl_data()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_data.md),
[`make_instances()`](https://Mischa-Hermans.github.io/dflasso/reference/make_instances.md),
[`prepare_instances()`](https://Mischa-Hermans.github.io/dflasso/reference/prepare_instances.md),
[`simulate_capital_allocation()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_capital_allocation.md),
[`simulate_shortest_path()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_shortest_path.md)

## Examples

``` r
sim <- simulate_knapsack(6, 8, 5, seed = 1)
head(sim$data)
#>       feat_01   feat_02   feat_03    feat_04    feat_05 realized_value
#> 1 -0.04914495 1.2375974 0.3740457 -0.2399296 -0.4655587       5.486274
#> 2 -0.12810481 1.0237045 0.3740457 -0.2399296 -0.4655587       5.966597
#> 3 -0.16050052 0.8949786 0.3740457 -0.2399296 -0.4655587       5.293367
#> 4 -0.24702830 0.6199620 0.3740457 -0.2399296 -0.4655587       5.317898
#> 5 -0.33879132 0.6081586 0.3740457 -0.2399296 -0.4655587       5.231200
#> 6 -0.40293455 0.3672144 0.3740457 -0.2399296 -0.4655587       5.161518
#>      scenario item_id weight
#> 1 scenario_01       1     20
#> 2 scenario_01       2     19
#> 3 scenario_01       3     10
#> 4 scenario_01       4     17
#> 5 scenario_01       5     20
#> 6 scenario_01       6     12
instances <- make_instances(
  sim$scenario, weights = sim$weights, capacity = sim$capacity
)
```
