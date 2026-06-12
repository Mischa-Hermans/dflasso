# Simulate a capital-allocation problem

Builds an example predict-then-optimize dataset for the
capital-allocation problem. Each scenario is one realisation of
uncertain asset returns; the optimiser splits a budget across assets.
The point of the construction is that some features predict returns well
while others barely predict returns yet decide which assets win the
allocation, so the decision focus has something to recover.

## Usage

``` r
simulate_capital_allocation(n_scenarios, n_assets, n_features, seed = NULL)
```

## Arguments

- n_scenarios:

  Number of scenarios, each one optimisation instance.

- n_assets:

  Number of assets per scenario.

- n_features:

  Number of feature columns. The first two are the decision-relevant
  features, the next few predict the return, and the rest are noise.
  Must be at least three.

- seed:

  Single integer, or `NULL` to draw one at random. The same seed gives
  the same data.

## Value

A list with `data` (a data frame: `feat_01` .. `feat_<n_features>`,
`realized_return`, a `scenario` factor with levels `scenario_01` .., and
`asset_id`), plus `x` (the feature matrix), `cost` (the realized
returns), `scenario`, and `element_id` (the asset ids). The
`decision_relevant_features` attribute on `data` records the decision
feature names.

## Details

The true return of asset `i` in scenario `s` is
`mu + sum_pred beta_pred z_sj + sum_dec beta_dec x_dec_isj + noise`. The
prediction-heavy features `z_sj` are scenario-level, shared by every
asset, and predict the return strongly. Each decision-relevant feature
is built per asset as `g_sj loading_i + small noise`, varying across
assets within a scenario but entering with only a small coefficient, so
a prediction-tuned lasso under-selects it while the decision-relevance
proxy reads its scenario-level mean. The remaining features are noise.

## See also

[`simulate_knapsack()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_knapsack.md),
[`simulate_shortest_path()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_shortest_path.md),
[`capital_allocation_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/capital_allocation_problem.md)

Other dflasso data helpers:
[`aid_routing`](https://Mischa-Hermans.github.io/dflasso/reference/aid_routing.md),
[`capital_allocation_demo`](https://Mischa-Hermans.github.io/dflasso/reference/capital_allocation_demo.md),
[`dfl_data()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_data.md),
[`make_instances()`](https://Mischa-Hermans.github.io/dflasso/reference/make_instances.md),
[`prepare_instances()`](https://Mischa-Hermans.github.io/dflasso/reference/prepare_instances.md),
[`simulate_knapsack()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_knapsack.md),
[`simulate_shortest_path()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_shortest_path.md)

## Examples

``` r
sim <- simulate_capital_allocation(8, 6, 6, seed = 1)
head(sim$data)
#>       feat_01     feat_02  feat_03    feat_04     feat_05   feat_06
#> 1 -0.01590698 0.389473360 0.435237 -0.4655587 -0.01291739 0.6418926
#> 2 -0.16226055 0.240961208 0.435237 -0.4655587 -0.01291739 0.6418926
#> 3 -0.27979973 0.153713468 0.435237 -0.4655587 -0.01291739 0.6418926
#> 4 -0.45810341 0.159696497 0.435237 -0.4655587 -0.01291739 0.6418926
#> 5 -0.52102914 0.051688639 0.435237 -0.4655587 -0.01291739 0.6418926
#> 6 -0.58878040 0.002637548 0.435237 -0.4655587 -0.01291739 0.6418926
#>   realized_return    scenario asset_id
#> 1     -0.10036062 scenario_01        1
#> 2      0.36587855 scenario_01        2
#> 3     -0.16284299 scenario_01        3
#> 4     -0.20403233 scenario_01        4
#> 5     -0.23150266 scenario_01        5
#> 6     -0.02268625 scenario_01        6
attr(sim$data, "decision_relevant_features")
#> [1] "feat_01" "feat_02"
```
