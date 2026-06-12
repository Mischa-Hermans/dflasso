# Subset a decision set by feasibility

`feasible()` and `infeasible()` partition a
[DecisionSet](https://Mischa-Hermans.github.io/dflasso/reference/DecisionSet-class.md)
into the instances that did and did not reach a decision, each returning
a `DecisionSet` of the same shape. `infeasible_reasons()` returns the
reasons table for the instances that failed.

## Usage

``` r
feasible(object)

# S4 method for class 'DecisionSet'
feasible(object)

infeasible(object)

# S4 method for class 'DecisionSet'
infeasible(object)

infeasible_reasons(object)

# S4 method for class 'DecisionSet'
infeasible_reasons(object)
```

## Arguments

- object:

  A
  [DecisionSet](https://Mischa-Hermans.github.io/dflasso/reference/DecisionSet-class.md)
  object.

## Value

`feasible()` and `infeasible()` return a
[DecisionSet](https://Mischa-Hermans.github.io/dflasso/reference/DecisionSet-class.md)
object. `infeasible_reasons()` returns a tibble with columns `scenario`
and `message`.

## See also

[`decide()`](https://Mischa-Hermans.github.io/dflasso/reference/decide.md),
[`is_feasible()`](https://Mischa-Hermans.github.io/dflasso/reference/decision-set-accessors.md)
