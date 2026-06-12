# Fit a decision-focused lasso

Learns a sparse linear cost model whose feature selection is driven by
downstream decision quality, not prediction error alone. It fits a plain
lasso and an adaptive lasso alongside the decision-focused fit, all on
one shared fold structure.

## Usage

``` r
dfl_fit(
  data_or_x,
  cost,
  scenario,
  problem = NULL,
  regret = NULL,
  sense = c("min", "max"),
  instances = NULL,
  element_id = NULL,
  penalty = c("decision", "adaptive", "plain"),
  control = dfl_control(),
  ...
)
```

## Arguments

- data_or_x:

  The numeric feature matrix `x`, one row per element. Build it from a
  data frame with
  [`dfl_data()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_data.md)
  first, then pass `prepared$x`; a data frame is not read here (unlike
  [`dfl_score()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_score.md),
  which takes a `features =` spec).

- cost:

  Numeric vector of realised costs, one per row, `NA` allowed. Required
  on both paths to fit the cost model.

- scenario:

  Vector grouping rows into instances; each distinct value is one
  instance.

- problem:

  An
  [OptimizationProblem](https://Mischa-Hermans.github.io/dflasso/reference/OptimizationProblem-class.md)
  object for the solver path. Supply this or `regret`, not both.

- regret:

  Named per-scenario regret for the supplied-regret path. Supply this or
  `problem`, not both.

- sense:

  Used only with `regret =`, to record and echo the diagnosed
  objective's direction. The solver path reads sense off `problem`.

- instances:

  Optional named list of per-scenario instances. `NULL` auto-builds it
  from `scenario` for built-ins that derive their instance from element
  counts and for custom solvers needing no per-instance data.

- element_id:

  Optional per-row element ids. `NULL` uses per-scenario row positions.

- penalty:

  Which stage is primary for bare `coef`/`predict`/`decide`, one of
  `"decision"` (default), `"adaptive"`, `"plain"`. All three are always
  computed.

- control:

  A `dfl_control` list of settings.

- ...:

  Caught only to give a clear error. `dfl_fit` takes the numeric
  `x`/`cost`/`scenario` that
  [`dfl_data()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_data.md)
  returns, not a `features =` tidyselect spec like
  [`dfl_score()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_score.md);
  an unmatched argument here is reported rather than silently dropped.

## Value

An S4
[DecisionFocusedLasso](https://Mischa-Hermans.github.io/dflasso/reference/DecisionFocusedLasso-class.md)
object.

## Details

One row per decision element per scenario (for example one row per asset
per period), not one row per scenario.
[`dfl_data()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_data.md)
shapes it from one frame; `cost` and `scenario` carry one value per row,
aligned to the rows of `x`.

Two entry modes share this one function. The **solver path**
(`problem =`) computes regret by solving each scenario under predicted
and realised costs, scores how strongly each feature tracks that regret,
and eases the penalty on the features that move the decision. The
**supplied-regret path** (`regret =`) skips the solver entirely and
reads the per-scenario regret supplied; the rest of the fit is the same.
Supply exactly one of `problem` or `regret`.

## See also

[`dfl_control()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_control.md),
[`dfl_data()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_data.md),
[`proxy_score()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl-accessors.md),
[DecisionFocusedLasso](https://Mischa-Hermans.github.io/dflasso/reference/DecisionFocusedLasso-class.md)

Other dflasso workflow:
[`decide()`](https://Mischa-Hermans.github.io/dflasso/reference/decide.md),
[`dfl_score()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_score.md),
[`predict-coef`](https://Mischa-Hermans.github.io/dflasso/reference/predict-coef.md),
[`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md)

## Examples

``` r
sim <- simulate_capital_allocation(40, 6, 6, seed = 1)
fit <- dfl_fit(
  sim$x, sim$cost, sim$scenario,
  problem = capital_allocation_problem(max_weight = 0.5),
  element_id = sim$element_id,
  control = dfl_control(seed = 1, n_splits = 5L)
)
proxy_score(fit)
#>    feat_01    feat_02    feat_03    feat_04    feat_05    feat_06 
#> 0.47584505 0.27799812 0.07739936 0.28721458 0.17080553 0.11768179 
```
