# Objective sense of a problem

Reports whether an optimisation problem minimises or maximises.
`sense()` returns the direction as a string; `is_minimization()` returns
a logical, `TRUE` for `"min"`.

## Usage

``` r
sense(object)

is_minimization(object)

# S4 method for class 'OptimizationProblem'
sense(object)

# S4 method for class 'OptimizationProblem'
is_minimization(object)

# S4 method for class 'DecisionFocusedLasso'
sense(object)

# S4 method for class 'DecisionFocusedLasso'
is_minimization(object)
```

## Arguments

- object:

  An
  [OptimizationProblem](https://Mischa-Hermans.github.io/dflasso/reference/OptimizationProblem-class.md)
  object, such as one returned by
  [`knapsack_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/knapsack_problem.md)
  or
  [`optimization_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/optimization_problem.md).

## Value

`sense()` returns a character scalar, `"min"` or `"max"`.
`is_minimization()` returns a single logical, `TRUE` when the sense is
`"min"`.

## See also

[`optimization_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/optimization_problem.md)

Other dflasso problems:
[`OptimizationProblem-class`](https://Mischa-Hermans.github.io/dflasso/reference/OptimizationProblem-class.md),
[`capital_allocation_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/capital_allocation_problem.md),
[`knapsack_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/knapsack_problem.md),
[`optimization_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/optimization_problem.md),
[`shortest_path_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/shortest_path_problem.md),
[`solve_decision()`](https://Mischa-Hermans.github.io/dflasso/reference/solve_decision.md)

## Examples

``` r
problem <- knapsack_problem()
sense(problem)
#> [1] "max"
is_minimization(problem)
#> [1] FALSE
```
