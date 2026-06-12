# Shape one data frame into the inputs for `dfl_fit()`

The recommended way to feed
[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md).
Pass one data frame, one row per decision element, and name the feature,
cost, and scenario columns. `dfl_data()` slices every piece from the
same rows, so the features, costs and scenarios stay aligned.

## Usage

``` r
dfl_data(
  data,
  features,
  cost = NULL,
  scenario,
  regret = NULL,
  sense = c("min", "max"),
  element_id = NULL
)
```

## Arguments

- data:

  A data frame with one row per decision element.

- features:

  The feature columns, given as a tidyselect specification: a character
  vector, a `c(...)` of bare names, or a selector such as
  `starts_with("feat_")`.

- cost:

  The realised-cost column, an unquoted name or a string. `NULL`
  (default) for the scores-only or supplied-regret path, which needs no
  cost.

- scenario:

  The grouping column, an unquoted name or a string, saying which
  instance each row belongs to.

- regret:

  Optional realised-regret column, an unquoted name or a string, for the
  supplied-regret path. `NULL` on the plain solver path.

- sense:

  Objective sense of the diagnosed model, recorded for the
  supplied-regret path. `"min"` (default) or `"max"`.

- element_id:

  Optional id column, an unquoted name or a string. `NULL` (default)
  uses per-scenario row positions.

## Value

A list with `x` (a numeric matrix), `cost` (a numeric vector or `NULL`),
`scenario`, `regret` (a numeric vector or `NULL`), `element_id` (a
vector or `NULL`), and `sense`. Every piece is sliced from the same rows
of `data`. Pass it straight to
[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md).

## Details

Each row is one decision element in one scenario (for example one asset
in one period), not one row per scenario with its elements spread across
columns. If the table is wide, pivot it long first.

Feature columns are pulled in selection order. Factor or character
feature columns are dummy-expanded with `model.matrix(~ . - 1)`, so `x`
is always numeric. A text feature with many distinct values (more than
50, or more than half the rows) is rejected rather than expanded, since
that is almost always an identifier or free-text column selected by
mistake; drop or bin it. Costs and regret may be missing (`NA`) but are
never imputed.

## See also

[`make_instances()`](https://Mischa-Hermans.github.io/dflasso/reference/make_instances.md),
[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md)

Other dflasso data helpers:
[`aid_routing`](https://Mischa-Hermans.github.io/dflasso/reference/aid_routing.md),
[`capital_allocation_demo`](https://Mischa-Hermans.github.io/dflasso/reference/capital_allocation_demo.md),
[`make_instances()`](https://Mischa-Hermans.github.io/dflasso/reference/make_instances.md),
[`prepare_instances()`](https://Mischa-Hermans.github.io/dflasso/reference/prepare_instances.md),
[`simulate_capital_allocation()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_capital_allocation.md),
[`simulate_knapsack()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_knapsack.md),
[`simulate_shortest_path()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_shortest_path.md)

## Examples

``` r
sim <- simulate_capital_allocation(8, 6, 6, seed = 1)
prepared <- dfl_data(
  sim$data,
  features = starts_with("feat_"),
  cost = realized_return,
  scenario = scenario,
  element_id = asset_id
)
dim(prepared$x)
#> [1] 48  6
```
