# Capital allocation, a budget-split dataset

A simulated continuous-allocation problem, a portfolio or budget split.
One data frame, one row per (scenario, asset), in the shape
[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md)
takes directly, so it fits in a single `dfl_data` -\> `dfl_fit` -\>
`decide` pass with no instances list and no join. Each scenario is one
rebalancing: the optimiser splits a budget across assets to maximise
predicted return.

## Usage

``` r
capital_allocation_demo
```

## Format

A data frame with 1,350 rows (225 scenarios x 6 assets) and 10 columns:

- feat_01, feat_02:

  numeric. The two decision-relevant features.

- feat_03, feat_04, feat_05, feat_06:

  numeric. The remaining four features.

- realized_return:

  numeric. The realised return per asset, the cost column; needed only
  to fit.

- scenario:

  factor. Which rebalancing this asset belongs to, the instance id, with
  levels `scenario_01` .. `scenario_225`.

- asset_id:

  integer. The per-asset label, carried onto decisions.

- split:

  character. `"train"` for the first 150 scenarios, `"test"` for the
  held-out 75, so the demo fits on train and checks
  [`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md)
  on test.

## Source

Simulated by
`simulate_capital_allocation(n_scenarios = 225, n_assets = 6, n_features = 6, seed = 20260601)`,
then a `split` column added; see `data-raw/make_datasets.R`.

## Details

Two of the six features, `feat_01` and `feat_02`, are decision-relevant
but weak predictors of `realized_return`; the rest range from strong to
noise.

## See also

[`simulate_capital_allocation()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_capital_allocation.md),
[`capital_allocation_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/capital_allocation_problem.md),
[`dfl_data()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_data.md),
[aid_routing](https://Mischa-Hermans.github.io/dflasso/reference/aid_routing.md)

Other dflasso data helpers:
[`aid_routing`](https://Mischa-Hermans.github.io/dflasso/reference/aid_routing.md),
[`dfl_data()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_data.md),
[`make_instances()`](https://Mischa-Hermans.github.io/dflasso/reference/make_instances.md),
[`prepare_instances()`](https://Mischa-Hermans.github.io/dflasso/reference/prepare_instances.md),
[`simulate_capital_allocation()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_capital_allocation.md),
[`simulate_knapsack()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_knapsack.md),
[`simulate_shortest_path()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_shortest_path.md)

## Examples

``` r
problem <- capital_allocation_problem(max_weight = 0.5)
train <- subset(capital_allocation_demo, split == "train")
d <- dfl_data(
  train,
  features = starts_with("feat_"),
  cost = realized_return,
  scenario = scenario,
  element_id = asset_id
)
dim(d$x)
#> [1] 900   6
```
