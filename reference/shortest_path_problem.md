# Shortest path through a graph

A built-in problem for routing decisions: find the least-cost path from
an origin node to a destination node over predicted arc costs. The
solver is a compiled Dijkstra.

## Usage

``` r
shortest_path_problem(allow_unreachable = TRUE)
```

## Arguments

- allow_unreachable:

  Single logical. `TRUE` (default) lets a fit carry instances where the
  destination cannot be reached after closures, marking them infeasible
  rather than failing the batch. `FALSE` treats an unreachable
  destination as a hard error.

## Value

A `ShortestPathProblem`, one of the concrete
[OptimizationProblem](https://Mischa-Hermans.github.io/dflasso/reference/OptimizationProblem-class.md)
classes, with sense fixed at `"min"`. Pass it to
[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md)
as the `problem` argument.

## See also

[`knapsack_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/knapsack_problem.md),
[`capital_allocation_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/capital_allocation_problem.md),
[`optimization_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/optimization_problem.md),
[`solve_decision()`](https://Mischa-Hermans.github.io/dflasso/reference/solve_decision.md)

Other dflasso problems:
[`OptimizationProblem-class`](https://Mischa-Hermans.github.io/dflasso/reference/OptimizationProblem-class.md),
[`capital_allocation_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/capital_allocation_problem.md),
[`knapsack_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/knapsack_problem.md),
[`optimization_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/optimization_problem.md),
[`sense()`](https://Mischa-Hermans.github.io/dflasso/reference/sense.md),
[`solve_decision()`](https://Mischa-Hermans.github.io/dflasso/reference/solve_decision.md)

## Examples

``` r
problem <- shortest_path_problem()
problem
#> <ShortestPathProblem: sense=min, allow_unreachable=TRUE>
instance <- list(
  from = c(1L, 1L, 2L, 3L),
  to = c(2L, 3L, 4L, 4L),
  n_nodes = 4L,
  origin = 1L,
  destination = 4L
)
solve_decision(problem, costs = c(1, 4, 1, 1), instance = instance)
#> [1] 1 0 1 0
```
