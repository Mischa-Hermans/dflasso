# Split capital across choices

A built-in problem for continuous allocation: spread a budget across
choices so the weights sum to one and no single choice exceeds a maximum
share, maximising total predicted return. The solver is a linear program
through lpSolve.

## Usage

``` r
capital_allocation_problem(max_weight = 0.2)
```

## Arguments

- max_weight:

  Single number in `(0, 1]`. The largest share any one choice may take.
  Default `0.2`. An instance may override it per call.

## Value

A `CapitalAllocationProblem`, one of the concrete
[OptimizationProblem](https://Mischa-Hermans.github.io/dflasso/reference/OptimizationProblem-class.md)
classes, with sense fixed at `"max"`. Pass it to
[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md)
as the `problem` argument.

## See also

[`knapsack_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/knapsack_problem.md),
[`shortest_path_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/shortest_path_problem.md),
[`optimization_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/optimization_problem.md),
[`solve_decision()`](https://Mischa-Hermans.github.io/dflasso/reference/solve_decision.md)

Other dflasso problems:
[`OptimizationProblem-class`](https://Mischa-Hermans.github.io/dflasso/reference/OptimizationProblem-class.md),
[`knapsack_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/knapsack_problem.md),
[`optimization_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/optimization_problem.md),
[`sense()`](https://Mischa-Hermans.github.io/dflasso/reference/sense.md),
[`shortest_path_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/shortest_path_problem.md),
[`solve_decision()`](https://Mischa-Hermans.github.io/dflasso/reference/solve_decision.md)

## Examples

``` r
problem <- capital_allocation_problem(max_weight = 0.5)
problem
#> <CapitalAllocationProblem: sense=max, max_weight=0.5>
solve_decision(
  problem,
  costs = c(0.08, 0.03, 0.05),
  instance = list(n_assets = 3)
)
#> [1] 0.5 0.0 0.5
```
