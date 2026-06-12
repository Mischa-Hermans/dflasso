# Wrap a custom solver as a dflasso problem

Builds a problem from a custom solver, for the case where no built-in
fits. Supply one function that turns a vector of predicted costs into a
decision, plus the objective sense, and dflasso treats it like any other
problem.

## Usage

``` r
optimization_problem(
  solve,
  sense = c("min", "max"),
  solve_support = NULL,
  name = NULL
)
```

## Arguments

- solve:

  A function of `(costs, instance)` returning the decision vector for
  that instance. Its length and row order match `costs`.

- sense:

  Objective direction for `cost' decision`, `"min"` (default) or
  `"max"`.

- solve_support:

  Optional function of one argument (the instance) returning the integer
  row indices the solver could use in a feasible decision. This sets the
  coverage rule: a scenario is eligible for the decision-quality step
  only when every row in its support has an observed cost. `NULL`
  (default) assumes every row of an instance may be used, which on
  partially observed data can make scenarios ineligible. Supply one when
  the solver can never use some rows (so those rows being unobserved
  should not disqualify the scenario), most often when only a subset of
  elements can ever enter a feasible decision.

- name:

  Optional character label shown by `show()`. `NULL` (default) uses
  `"custom"`.

## Value

A `FunctionProblem`, one of the concrete
[OptimizationProblem](https://Mischa-Hermans.github.io/dflasso/reference/OptimizationProblem-class.md)
classes. Pass it to
[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md)
as the `problem` argument.

## See also

[`knapsack_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/knapsack_problem.md),
[`shortest_path_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/shortest_path_problem.md),
[`capital_allocation_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/capital_allocation_problem.md),
[`solve_decision()`](https://Mischa-Hermans.github.io/dflasso/reference/solve_decision.md)

Other dflasso problems:
[`OptimizationProblem-class`](https://Mischa-Hermans.github.io/dflasso/reference/OptimizationProblem-class.md),
[`capital_allocation_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/capital_allocation_problem.md),
[`knapsack_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/knapsack_problem.md),
[`sense()`](https://Mischa-Hermans.github.io/dflasso/reference/sense.md),
[`shortest_path_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/shortest_path_problem.md),
[`solve_decision()`](https://Mischa-Hermans.github.io/dflasso/reference/solve_decision.md)

## Examples

``` r
pick_cheapest_half <- function(costs, instance) {
  as.numeric(costs <= stats::median(costs))
}
problem <- optimization_problem(solve = pick_cheapest_half, sense = "min")
problem
#> <FunctionProblem: sense=min, name=custom>
solve_decision(problem, c(3, 1, 4, 2), instance = list())
#> [1] 0 1 0 1
```
