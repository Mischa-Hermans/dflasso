# Solve a decision from predicted costs

The step that turns a vector of predicted costs into a decision for one
instance. `solve_decision()` solves each problem its own way: the
built-in problems call their own solvers, and a custom problem calls the
solver supplied to it. `solve_support()` reports which element rows a
feasible decision could use for the instance. Those rows set the
coverage rule: a scenario is eligible for the decision-quality step only
when every row in its support has an observed realised cost. The default
is all rows, which can drop scenarios on partially observed data; a
custom problem supplies a narrower set through the `solve_support`
argument of
[`optimization_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/optimization_problem.md)
when its solver can never use some rows.

## Usage

``` r
solve_decision(problem, costs, instance, ...)

solve_support(problem, instance, ...)

# S4 method for class 'ShortestPathProblem'
solve_decision(problem, costs, instance, ...)

# S4 method for class 'ShortestPathProblem'
solve_support(problem, instance, ...)

# S4 method for class 'KnapsackProblem'
solve_decision(problem, costs, instance, ...)

# S4 method for class 'KnapsackProblem'
solve_support(problem, instance, ...)

# S4 method for class 'CapitalAllocationProblem'
solve_decision(problem, costs, instance, ...)

# S4 method for class 'CapitalAllocationProblem'
solve_support(problem, instance, ...)

# S4 method for class 'FunctionProblem'
solve_decision(problem, costs, instance, ...)

# S4 method for class 'FunctionProblem'
solve_support(problem, instance, costs = NULL, ...)
```

## Arguments

- problem:

  An
  [OptimizationProblem](https://Mischa-Hermans.github.io/dflasso/reference/OptimizationProblem-class.md)
  object.

- costs:

  Numeric vector of predicted costs, one per element row of the
  instance.

- instance:

  A list of the per-instance data the solver needs. The built-in
  problems expect named fields documented on their constructors.

- ...:

  Reserved for future use.

## Value

`solve_decision()` returns the decision vector, the same length and row
order as `costs`. `solve_support()` returns an integer vector of row
indices into the instance.

## Details

For
[`shortest_path_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/shortest_path_problem.md)
an unreachable destination raises a classed condition with class
`dflasso_infeasible`, so a caller can catch it and mark the instance
infeasible rather than fail the batch.

## See also

[`knapsack_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/knapsack_problem.md),
[`shortest_path_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/shortest_path_problem.md),
[`capital_allocation_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/capital_allocation_problem.md),
[`optimization_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/optimization_problem.md)

Other dflasso problems:
[`OptimizationProblem-class`](https://Mischa-Hermans.github.io/dflasso/reference/OptimizationProblem-class.md),
[`capital_allocation_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/capital_allocation_problem.md),
[`knapsack_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/knapsack_problem.md),
[`optimization_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/optimization_problem.md),
[`sense()`](https://Mischa-Hermans.github.io/dflasso/reference/sense.md),
[`shortest_path_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/shortest_path_problem.md)

## Examples

``` r
problem <- knapsack_problem()
solve_decision(
  problem,
  costs = c(60, 100, 120),
  instance = list(weights = c(10L, 20L, 30L), capacity = 50L)
)
#> [1] 0 1 1
solve_support(problem, instance = list(weights = c(10L, 20L, 30L)))
#> [1] 1 2 3
```
