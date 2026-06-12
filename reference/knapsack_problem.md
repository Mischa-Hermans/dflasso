# Pick a subset under one budget

A built-in problem for 0/1 selection under a single capacity: a
knapsack. Each instance supplies item weights and a capacity; the solver
returns which items to take to maximise total predicted value.

## Usage

``` r
knapsack_problem(solver = c("dynamic_program", "linear_program"))
```

## Arguments

- solver:

  Which engine solves each instance. `"dynamic_program"` (default) is
  the exact integer dynamic program and needs integer weights.
  `"linear_program"` solves a binary linear program through lpSolve,
  useful when weights are not integers.

## Value

A `KnapsackProblem`, one of the concrete
[OptimizationProblem](https://Mischa-Hermans.github.io/dflasso/reference/OptimizationProblem-class.md)
classes, with sense fixed at `"max"`. Pass it to
[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md)
as the `problem` argument.

## See also

[`shortest_path_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/shortest_path_problem.md),
[`capital_allocation_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/capital_allocation_problem.md),
[`optimization_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/optimization_problem.md),
[`solve_decision()`](https://Mischa-Hermans.github.io/dflasso/reference/solve_decision.md)

Other dflasso problems:
[`OptimizationProblem-class`](https://Mischa-Hermans.github.io/dflasso/reference/OptimizationProblem-class.md),
[`capital_allocation_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/capital_allocation_problem.md),
[`optimization_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/optimization_problem.md),
[`sense()`](https://Mischa-Hermans.github.io/dflasso/reference/sense.md),
[`shortest_path_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/shortest_path_problem.md),
[`solve_decision()`](https://Mischa-Hermans.github.io/dflasso/reference/solve_decision.md)

## Examples

``` r
problem <- knapsack_problem()
problem
#> <KnapsackProblem: sense=max, solver=dynamic_program>
solve_decision(
  problem,
  costs = c(60, 100, 120),
  instance = list(weights = c(10L, 20L, 30L), capacity = 50L)
)
#> [1] 0 1 1
```
