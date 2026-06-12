# Optimisation problem classes

The S4 classes that represent a dflasso problem. `OptimizationProblem`
is the base class, never built directly; each of the four classes that
extend it carries a sense (minimise or maximise) and a solver that turns
predicted costs into a decision. Build them with the lowercase
constructors, not
[`methods::new()`](https://rdrr.io/r/methods/new.html).

## Usage

``` r
# S4 method for class 'FunctionProblem'
show(object)

# S4 method for class 'ShortestPathProblem'
show(object)

# S4 method for class 'KnapsackProblem'
show(object)

# S4 method for class 'CapitalAllocationProblem'
show(object)
```

## Slots

- `sense`:

  Character scalar, either `"min"` or `"max"`. The direction of the
  objective `cost' decision`.

- `solve_function`:

  Function of `(costs, instance)` returning a decision vector, or `NULL`
  for the built-in problems, where the class determines the solver.

- `solve_support_function`:

  Function of one argument returning the integer row indices the solver
  inspects, or `NULL` for the all-rows default.

- `name`:

  Character scalar label shown by `show()`.

## See also

[`optimization_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/optimization_problem.md),
[`shortest_path_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/shortest_path_problem.md),
[`knapsack_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/knapsack_problem.md),
[`capital_allocation_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/capital_allocation_problem.md)

Other dflasso problems:
[`capital_allocation_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/capital_allocation_problem.md),
[`knapsack_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/knapsack_problem.md),
[`optimization_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/optimization_problem.md),
[`sense()`](https://Mischa-Hermans.github.io/dflasso/reference/sense.md),
[`shortest_path_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/shortest_path_problem.md),
[`solve_decision()`](https://Mischa-Hermans.github.io/dflasso/reference/solve_decision.md)
