# Simulate a shortest-path routing problem

Builds an example single-origin single-destination routing dataset like
the `aid_routing` data. Each day is one instance over a connected
layered graph; some days close arcs so the route must change. Features
are observed per arc per day (the `arc_day_features` panel) because a
router sees that day's forecast on each arc before driving. Network-wide
`congestion` raises every arc's travel time together and predicts it
strongly without changing the route. The two decision-relevant features,
`flood_depth` and `mud_depth`, are built per arc per day as
`weather_day load_arc` with opposite regional signs, so a wet day tilts
north routes against south routes (changing which route is fastest)
while each feature carries only a small marginal effect on travel time.
The prediction-tuned baseline therefore drops them. Because the day's
weather drives both the route tilt and the feature's per-day mean over
the graph, the days where ignoring the feature is costly are the days
its mean is large, which the decision-relevance proxy detects.

## Usage

``` r
simulate_shortest_path(n_days, n_arcs, n_nodes, seed = NULL)
```

## Arguments

- n_days:

  Number of training days, one instance each.

- n_arcs:

  Approximate number of arcs in the graph. The layered construction may
  add a few to keep the graph connected.

- n_nodes:

  Number of nodes. Origin is pinned to node 1, destination to node 5.

- seed:

  Single integer, or `NULL` to draw one at random. The same seed gives
  the same data.

## Value

A list with `arcs` (arc_id, from_node, to_node, `surface`, `base_time`,
the static loadings `flood_load`/`mud_load`, and `region_sign`),
`nodes`, `training_days` (date, origin, destination, `closed_arc_ids`
list-column), `arc_day_features` (date, arc_id, and the per-arc-per-day
feature columns `congestion`, `rainfall`, `flood_depth`, `mud_depth`,
and `noise_01`..`noise_24`), `observed_times` (date, arc_id,
travel_time, ragged with `NA`), the matching `holdout_days`,
`arc_day_features_holdout`, `observed_times_holdout`, and
`tomorrow_days` (decide-time days including the infeasible `2026-08-14`)
with `arc_day_features_tomorrow`.

## Details

The data is built to exercise the package's edge cases: a fixed subset
of days has full coverage of its solved arcs, a couple of observed rows
fall on closed arcs, and one decide-time day (`2026-08-14`) closes every
arc out of the origin, leaving the destination unreachable.

## See also

[`simulate_capital_allocation()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_capital_allocation.md),
[`simulate_knapsack()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_knapsack.md),
[`shortest_path_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/shortest_path_problem.md)

Other dflasso data helpers:
[`aid_routing`](https://Mischa-Hermans.github.io/dflasso/reference/aid_routing.md),
[`capital_allocation_demo`](https://Mischa-Hermans.github.io/dflasso/reference/capital_allocation_demo.md),
[`dfl_data()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_data.md),
[`make_instances()`](https://Mischa-Hermans.github.io/dflasso/reference/make_instances.md),
[`prepare_instances()`](https://Mischa-Hermans.github.io/dflasso/reference/prepare_instances.md),
[`simulate_capital_allocation()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_capital_allocation.md),
[`simulate_knapsack()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_knapsack.md)

## Examples

``` r
routing <- simulate_shortest_path(n_days = 12, n_arcs = 20, n_nodes = 8, seed = 1)
names(routing)
#>  [1] "arcs"                      "nodes"                    
#>  [3] "training_days"             "arc_day_features"         
#>  [5] "observed_times"            "holdout_days"             
#>  [7] "arc_day_features_holdout"  "observed_times_holdout"   
#>  [9] "tomorrow_days"             "arc_day_features_tomorrow"
head(routing$arc_day_features)
#>         date  arc_id congestion rainfall flood_depth mud_depth noise_01
#> 1 2026-06-01 arc_001     0.2846  -0.6047      0.1249   -0.4145   0.0480
#> 2 2026-06-01 arc_002     0.2846  -0.5385      0.1709   -0.0784  -0.3657
#> 3 2026-06-01 arc_003     0.2846  -0.6338      0.1627   -0.2270  -0.4441
#> 4 2026-06-01 arc_004     0.2846  -0.5269      0.1454   -0.2597   0.5751
#> 5 2026-06-01 arc_005     0.2846  -0.6081      0.2043   -0.2049   0.4049
#> 6 2026-06-01 arc_006     0.2846  -0.3660     -0.0855    0.0172  -0.6699
#>   noise_02 noise_03 noise_04 noise_05 noise_06 noise_07 noise_08 noise_09
#> 1  -0.6156  -0.5472   0.9822   0.3292  -0.2726  -0.0277   0.6735  -0.1406
#> 2  -0.4857  -0.7372  -0.6473  -0.3750  -0.1148  -0.8724  -0.8577   0.1285
#> 3  -0.6375   0.9631   0.6269  -0.1886  -0.6866   0.5691   0.4056   0.3123
#> 4  -0.0454  -0.3460  -0.8631   0.9922   0.1644  -0.1634   0.3976   0.9571
#> 5   0.5415   0.0139  -0.1991   0.7102   0.9403   0.9620  -0.0721  -0.5357
#> 6  -0.9444   0.3629  -0.7177   0.9071   0.9790  -0.4342  -0.1261  -0.5184
#>   noise_10 noise_11 noise_12 noise_13 noise_14 noise_15 noise_16 noise_17
#> 1  -0.3034   0.9875  -0.1885  -0.9169   0.3157  -0.0782   0.0045   0.1084
#> 2   0.3196  -0.2852  -0.8294  -0.4120   0.1563   0.9103  -0.6204   0.3766
#> 3  -0.3765   0.4953   0.8651   0.0017   0.9742   0.4251  -0.9963   0.3161
#> 4  -0.2969   0.5858   0.6768   0.2195   0.2076  -0.2057   0.7552   0.3267
#> 5  -0.7043   0.4117   0.7589  -0.4715  -0.8701  -0.7646  -0.7318  -0.0555
#> 6   0.3178  -0.0483   0.8714  -0.1538  -0.6758  -0.5198  -0.9545   0.9391
#>   noise_18 noise_19 noise_20 noise_21 noise_22 noise_23 noise_24
#> 1  -0.6251   0.2129  -0.7693   0.3095   0.0506   0.1070   0.9496
#> 2   0.2921  -0.9412   0.9919  -0.7343   0.3355  -0.5141  -0.2987
#> 3   0.0840  -0.3271  -0.2414  -0.3164  -0.1834   0.5561  -0.2121
#> 4  -0.3294  -0.4447   0.1240   0.4627   0.6852   0.3039   0.9019
#> 5   0.2758  -0.7656   0.4654   0.8146   0.4746   0.6605  -0.7867
#> 6   0.6584  -0.9136   0.7416   0.3924  -0.3036   0.2971   0.8695
```
