# Turn a routing dataset into rows for `dfl_fit()`

Turns a
[`simulate_shortest_path()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_shortest_path.md)-style
routing list (the shape `aid_routing` uses) into the pieces
[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md),
[`decide()`](https://Mischa-Hermans.github.io/dflasso/reference/decide.md),
and
[`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md)
consume, one row per arc per day: the per-arc feature matrix `x`, the
realised travel-time `cost` (with `NA` where an arc was not driven that
day), the `scenario` (the delivery-day id), the `element_id` (the
`arc_id`), the per-day `instances`, and a coverage report. It takes
arcs, nodes, day panels, and observed times.

## Usage

``` r
prepare_instances(
  dataset,
  which = c("training", "holdout", "tomorrow"),
  aggregate = c("mean", "median", "min", "last")
)
```

## Arguments

- dataset:

  A routing list shaped like
  [`simulate_shortest_path()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_shortest_path.md)'s
  return value. See "The five pieces of `dataset`" for the tables and
  columns it must hold; a missing or malformed table stops with a
  message naming it.

- which:

  Which slice to prepare: `"training"` (default), `"holdout"`, or
  `"tomorrow"`. `"tomorrow"` carries no costs.

- aggregate:

  How to combine several observed times on the same (date, arc):
  `"mean"` (default), `"median"`, `"min"`, or `"last"`. Recorded in the
  coverage report.

## Value

A list with `x` (the numeric feature matrix, one row per arc per day),
`cost` (realised travel times, `NA` where unobserved, `NULL`-free),
`scenario` (the delivery-day id per row), `element_id` (the `arc_id` per
row), `instances` (a named list, one
`list(from, to, n_nodes, origin, destination)` per day), and `coverage`
(a `data.frame` of the per-day join report with an `unplaceable`
attribute). Pass the first five straight into
[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md)
/
[`decide()`](https://Mischa-Hermans.github.io/dflasso/reference/decide.md)
/
[`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md).

## Details

`which` picks which slice of the dataset to prepare. `"training"` reads
`training_days` / `arc_day_features` / `observed_times`; `"holdout"`
reads the `*_holdout` fields for the
[`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md)
test set; `"tomorrow"` reads `tomorrow_days` /
`arc_day_features_tomorrow` and has no observed times, so every cost is
`NA` (decide time needs no costs).

For each day the graph is the arcs minus that day's `closed_arc_ids`, so
a closed arc produces no row. Realised cost for a (date, arc) row comes
from an inner join against the observed-times panel on `(date, arc_id)`:
one matching observation gives that travel time, several give the
`aggregate` summary (mean by default), none leaves `cost = NA` (never
imputed). Observed rows whose arc was closed that day, or whose
`(date, arc_id)` is not a row of the day's graph, cannot be placed; they
are dropped, counted, and reported.

## The five pieces of `dataset`

Bring a custom network as a list of these tables:

- `arcs`: one row per directed arc, with `arc_id`, `from_node`,
  `to_node`, and any per-arc columns. `arc_id` may be a string or an
  integer.

- `nodes`: one row per node, with `node_id`.

- a day table (`training_days`, `holdout_days`, or `tomorrow_days`): one
  row per day, with `date`, `origin`, `destination`, and an optional
  `closed_arc_ids` list-column. Origin and destination are read per day
  from this table and can be any node, not a fixed pair.

- a feature panel (`arc_day_features` and its `_holdout` / `_tomorrow`
  variants): one row per (date, arc), with `date`, `arc_id`, and the
  feature columns. Every column other than `date` and `arc_id` becomes a
  feature.

- an observed-times panel (`observed_times` and its `_holdout` variant):
  `date`, `arc_id`, `travel_time`, a row only where a time was observed.
  The `"tomorrow"` slice has none.

The `date` column is the day id: any consistent grouping key, a `Date`,
an integer day index, or a character label. It is not coerced to a
calendar date, so labels such as `"mon"` or `1L` work as well as
`"2026-06-01"`. Use the same type across the day table, the feature
panel, and the observed-times panel so they join. The output keeps the
days in the order the day table gives them. `closed_arc_ids` takes `NA`,
an empty `character(0)`/`integer(0)`, or a vector of arc ids on a
closure day; omit the column entirely for a network that never closes.

## See also

[`shortest_path_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/shortest_path_problem.md),
[aid_routing](https://Mischa-Hermans.github.io/dflasso/reference/aid_routing.md),
[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md),
[`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md)

Other dflasso data helpers:
[`aid_routing`](https://Mischa-Hermans.github.io/dflasso/reference/aid_routing.md),
[`capital_allocation_demo`](https://Mischa-Hermans.github.io/dflasso/reference/capital_allocation_demo.md),
[`dfl_data()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_data.md),
[`make_instances()`](https://Mischa-Hermans.github.io/dflasso/reference/make_instances.md),
[`simulate_capital_allocation()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_capital_allocation.md),
[`simulate_knapsack()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_knapsack.md),
[`simulate_shortest_path()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_shortest_path.md)

## Examples

``` r
routing <- simulate_shortest_path(n_days = 12, n_arcs = 20, n_nodes = 8, seed = 1)
prepared <- prepare_instances(routing, which = "training")
dim(prepared$x)
#> [1] 175  28
prepared$instances[[1]]
#> $from
#>  [1] 1 1 1 2 2 4 6 7 8 8 4 2 4 8
#> 
#> $to
#>  [1] 2 4 8 3 6 3 5 5 3 6 6 7 7 7
#> 
#> $n_nodes
#> [1] 8
#> 
#> $origin
#> [1] 1
#> 
#> $destination
#> [1] 5
#> 
head(prepared$coverage)
#>     scenario n_elements n_cost_observed n_cost_missing coverage_fraction
#> 1 2026-06-01         14              14              0               1.0
#> 2 2026-06-02         15              15              0               1.0
#> 3 2026-06-03         14              14              0               1.0
#> 4 2026-06-04         14              14              0               1.0
#> 5 2026-06-05         15              15              0               1.0
#> 6 2026-06-06         15               3             12               0.2
#>   n_solve_set n_solve_set_missing proxy_eligible
#> 1          14                   0           TRUE
#> 2          15                   0           TRUE
#> 3          14                   0           TRUE
#> 4          14                   0           TRUE
#> 5          15                   0           TRUE
#> 6          15                  12          FALSE
#>                         set_aside_reason
#> 1                                   <NA>
#> 2                                   <NA>
#> 3                                   <NA>
#> 4                                   <NA>
#> 5                                   <NA>
#> 6 12 of 15 solve-set elements unobserved

# Bring a custom network: build the five tables by hand, no simulator.
# A tiny graph 1 -> {2, 3} -> 4, origin 1, destination 4, days as a plain
# integer index (any consistent day id works, not just calendar dates).
arcs <- data.frame(
  arc_id = c("a1", "a2", "a3", "a4"),
  from_node = c(1, 2, 1, 3),
  to_node = c(2, 4, 3, 4)
)
nodes <- data.frame(node_id = 1:4)
days <- data.frame(date = 1:5, origin = 1, destination = 4)
days$closed_arc_ids <- replicate(5, character(0), simplify = FALSE)
set.seed(1)
features <- do.call(rbind, lapply(1:5, function(day) data.frame(
  date = day, arc_id = arcs$arc_id,
  forecast_rain = round(runif(4), 2), forecast_flow = round(runif(4), 2)
)))
observed <- do.call(rbind, lapply(1:5, function(day) data.frame(
  date = day, arc_id = arcs$arc_id, travel_time = round(runif(4, 5, 15), 1)
)))
network <- list(
  arcs = arcs, nodes = nodes,
  training_days = days, arc_day_features = features, observed_times = observed
)
own <- prepare_instances(network, which = "training")
own$scenario
#>  [1] "1" "1" "1" "1" "2" "2" "2" "2" "3" "3" "3" "3" "4" "4" "4" "4" "5" "5" "5"
#> [20] "5"
# \donttest{
fit <- dfl_fit(
  own$x, own$cost, own$scenario,
  problem = shortest_path_problem(),
  instances = own$instances, element_id = own$element_id,
  control = dfl_control(seed = 1, n_splits = 5L)
)
#> Warning: 5 scenarios is fewer than nfolds (10); reduced to 5 folds.
fit
#> <DecisionFocusedLasso: solver, sense=min, 2 features, 2 kept, 5 instances scored>
# }
```
