# Rank features by how strongly they track regret

When per-instance regret is already available, `dfl_score()` ranks
features by how strongly each correlates with that regret, skipping the
model fit and solver that
[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md)
runs.

## Usage

``` r
dfl_score(
  data_or_x,
  features,
  scenario,
  regret,
  sense = c("min", "max"),
  control = dfl_control()
)

# S3 method for class 'dfl_score'
print(x, ...)
```

## Arguments

- data_or_x:

  One data frame read like
  [`dfl_data()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_data.md)
  (with `features` a tidyselect spec and `scenario`/`regret` column
  names), or a numeric feature matrix `x` with loose `scenario`/`regret`
  vectors. In the matrix form `regret` must self-key: a numeric named by
  scenario id, or a two-column `(id, regret)` data frame. A bare
  positional vector is rejected.

- features:

  The feature columns when `data_or_x` is a data frame, a tidyselect
  specification.

- scenario:

  The grouping column (data-frame form) or per-row scenario vector
  (matrix form).

- regret:

  The realised-regret column (data-frame form) or the self-keyed regret
  (matrix form). One value per scenario.

- sense:

  Objective sense of the diagnosed model, `"min"` (default) or `"max"`.
  Recorded and echoed, not used to transform supplied regret.

- control:

  A `dfl_control` list. Only `score_floor` is read here.

- x:

  A `dfl_score` object.

- ...:

  Unused, present for method compatibility.

## Value

An S3 `dfl_score` object: a ranked tibble with columns `rank`, `term`,
`proxy_score`, `role` (an ordered factor, `decision-relevant` or
`neither`), and `reading` (a plain gloss of the score band). Its
[`print()`](https://rdrr.io/r/base/print.html) shows the ranking and the
heuristic-not-validated footer.

## See also

[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md)
to also fit a model,
[`regret_from_objectives()`](https://Mischa-Hermans.github.io/dflasso/reference/regret_from_objectives.md)
and
[`regret_from_decisions()`](https://Mischa-Hermans.github.io/dflasso/reference/regret_from_objectives.md)
to build the regret vector first.

Other dflasso workflow:
[`decide()`](https://Mischa-Hermans.github.io/dflasso/reference/decide.md),
[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md),
[`predict-coef`](https://Mischa-Hermans.github.io/dflasso/reference/predict-coef.md),
[`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md)

## Examples

``` r
set.seed(1)
backtest <- data.frame(
  date = rep(c("d1", "d2", "d3", "d4", "d5", "d6"), each = 4),
  feat_rain = rnorm(24), feat_speed = rnorm(24), feat_hist = rnorm(24),
  regret = rep(c(4.1, 0.0, 7.8, 1.2, 6.5, 0.3), each = 4)
)
dfl_score(
  backtest,
  features = starts_with("feat_"), scenario = date, regret = regret
)
#> Using the supplied regret as-is, not regret from a dflasso fit.
#> Which features track decision failures?  (supplied regret, 3 features)
#> 
#>   rank  feature         score   reading
#>      1  feat_hist        0.96   strongly tracks regret
#>      2  feat_rain        0.76   strongly tracks regret
#>      3  feat_speed       0.54   strongly tracks regret
#> 
#>   score = |correlation(feature, regret)|, 0-1.
#>   Heuristic, not a validated result: with no held-out decisions dflasso can't confirm this ranking.
#>   Valid only if the regret is OUT-OF-SAMPLE from the model being diagnosed (>= 0, not in-sample, not dflasso's).
#>   Association with decision failure, not proof of cause. decide() needs a solver.
```
