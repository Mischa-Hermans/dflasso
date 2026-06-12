# A set of decisions from a fitted model

The object
[`decide()`](https://Mischa-Hermans.github.io/dflasso/reference/decide.md)
returns. It holds one record per instance: the decision named by element
id, the chosen elements, the predicted objective, and whether the
instance was feasible (with a reason if not).

## Usage

``` r
# S4 method for class 'DecisionSet'
show(object)
```

## Slots

- `records`:

  A tibble with one row per instance and the list-columns `decision`,
  `selected_elements`, `element_sequence`, `element_ids`,
  `predicted_cost`, plus `scenario`, `predicted_objective`, `feasible`,
  and `message`.

- `sense`:

  Character scalar, `"min"` or `"max"`, the objective direction.

- `s`:

  Character scalar recording the penalty strength the decisions used.

## See also

[`decide()`](https://Mischa-Hermans.github.io/dflasso/reference/decide.md),
[`decisions()`](https://Mischa-Hermans.github.io/dflasso/reference/decision-set-accessors.md),
[`feasible()`](https://Mischa-Hermans.github.io/dflasso/reference/decision-set-feasibility.md),
[`infeasible_reasons()`](https://Mischa-Hermans.github.io/dflasso/reference/decision-set-feasibility.md)
