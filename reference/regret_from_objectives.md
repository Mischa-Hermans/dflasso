# Build a regret vector from objective values or decisions

`regret_from_objectives()` and `regret_from_decisions()` return a
per-scenario regret vector that feeds
[`dfl_score()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_score.md)
or
[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md).

## Usage

``` r
regret_from_objectives(
  scenario,
  value_model,
  value_oracle,
  sense = c("min", "max")
)

regret_from_decisions(
  scenario,
  cost,
  decision_model,
  decision_oracle,
  sense = c("min", "max")
)
```

## Arguments

- scenario:

  Per-instance or per-row scenario vector.

- value_model:

  The diagnosed model's achieved objective, one value per instance or
  per row.

- value_oracle:

  The best achievable objective, one value per instance or per row.

- sense:

  Objective sense, `"min"` (default) or `"max"`.

- cost:

  Per-element realised cost vector.

- decision_model:

  The diagnosed model's per-element decision (0/1 or weight).

- decision_oracle:

  The oracle per-element decision.

## Value

A named numeric, one regret per unique scenario, clamped at zero.

## See also

[`dfl_score()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_score.md),
[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md)

## Examples

``` r
regret_from_objectives(
  scenario = c("a", "b", "c"),
  value_model = c(12, 9, 15),
  value_oracle = c(10, 9, 11),
  sense = "min"
)
#> a b c 
#> 2 0 4 
```
