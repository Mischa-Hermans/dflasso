# Aid routing, a single-source shortest-path dataset

A simulated single-source shortest-path (routing) problem on a small
road graph: one origin (node 1), one destination (node 5), per-arc
features, and realised travel times. One vehicle and one
origin-to-destination path per day, solved by Dijkstra, not a
vehicle-routing or TSP instance.

## Usage

``` r
aid_routing
```

## Format

A list with the fields
[`simulate_shortest_path()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_shortest_path.md)
returns:

- arcs:

  data frame, one row per directed arc: `arc_id`, `from_node`,
  `to_node`, `surface`, `base_time`, and the static loadings
  `flood_load`, `mud_load`, `region_sign`.

- nodes:

  data frame: `node_id`, `layer`, `region`. Origin is node 1,
  destination is node 5.

- training_days:

  data frame, one row per delivery-day: `date` (the scenario id),
  `origin`, `destination`, and `closed_arc_ids` (a list-column of arc
  ids hard-closed that day).

- arc_day_features:

  data frame, one row per (date, arc): the feature columns `congestion`,
  `rainfall`, `flood_depth`, `mud_depth`, and `noise_01` .. `noise_24`.

- observed_times:

  data frame: `date`, `arc_id`, `travel_time`, a row only where a time
  was observed, about half the (date, arc) pairs. A couple of rows fall
  on closed arcs, so the coverage report has unplaceable rows.

- holdout_days, arc_day_features_holdout, observed_times_holdout:

  the matching tables for the
  [`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md)
  held-out days, disjoint from training.

- tomorrow_days, arc_day_features_tomorrow:

  the decide-time days (no costs), including `2026-08-14`, which closes
  a cut-set severing every origin-to-destination path.

## Source

Simulated by
`simulate_shortest_path(n_days = 250, n_arcs = 30, n_nodes = 12, seed = 7)`;
see `data-raw/make_datasets.R`.

## Details

A list of graph tables, not element rows.
[`prepare_instances()`](https://Mischa-Hermans.github.io/dflasso/reference/prepare_instances.md)
joins them into the pieces
[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md),
[`decide()`](https://Mischa-Hermans.github.io/dflasso/reference/decide.md),
and
[`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md)
consume, one row per arc per day; each delivery-day is one instance over
the day's graph (the arcs minus that day's closures). `flood_depth` and
`mud_depth` are decision-relevant but weak: they predict travel time
poorly yet flip which route is fastest on wet days.

## See also

[`prepare_instances()`](https://Mischa-Hermans.github.io/dflasso/reference/prepare_instances.md),
[`shortest_path_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/shortest_path_problem.md),
[`simulate_shortest_path()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_shortest_path.md),
[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md),
[capital_allocation_demo](https://Mischa-Hermans.github.io/dflasso/reference/capital_allocation_demo.md)

Other dflasso data helpers:
[`capital_allocation_demo`](https://Mischa-Hermans.github.io/dflasso/reference/capital_allocation_demo.md),
[`dfl_data()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_data.md),
[`make_instances()`](https://Mischa-Hermans.github.io/dflasso/reference/make_instances.md),
[`prepare_instances()`](https://Mischa-Hermans.github.io/dflasso/reference/prepare_instances.md),
[`simulate_capital_allocation()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_capital_allocation.md),
[`simulate_knapsack()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_knapsack.md),
[`simulate_shortest_path()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_shortest_path.md)

## Examples

``` r
# \donttest{
prep <- prepare_instances(aid_routing, which = "training")
fit <- dfl_fit(
  prep$x, prep$cost, prep$scenario,
  problem = shortest_path_problem(),
  instances = prep$instances, element_id = prep$element_id,
  control = dfl_control(seed = 1)
)
fit
#> <DecisionFocusedLasso: solver, sense=min, 28 features, 3 kept, 112 instances scored>
# }
```
