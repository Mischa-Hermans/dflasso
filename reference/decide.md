# Make decisions on new data

Given new feature rows, `decide()` predicts costs and solves each
instance to a decision, returning a
[DecisionSet](https://Mischa-Hermans.github.io/dflasso/reference/DecisionSet-class.md)
to act on. It needs no realised costs.

## Usage

``` r
decide(
  object,
  x_new,
  scenario_new,
  instances_new = NULL,
  element_id_new = NULL,
  problem = NULL,
  s = "lambda.min",
  ...
)

# S4 method for class 'DecisionFocusedLasso'
decide(
  object,
  x_new,
  scenario_new,
  instances_new = NULL,
  element_id_new = NULL,
  problem = NULL,
  s = "lambda.min",
  ...
)
```

## Arguments

- object:

  A
  [DecisionFocusedLasso](https://Mischa-Hermans.github.io/dflasso/reference/DecisionFocusedLasso-class.md)
  object.

- x_new:

  Numeric feature matrix of new rows, columns in the same order (or with
  the same names) as the matrix the fit was trained on.

- scenario_new:

  Vector grouping the new rows into instances, one value per row.

- instances_new:

  Optional named list of per-instance data, one entry per scenario.
  `NULL` (default) auto-builds it from `scenario_new` exactly as
  [`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md)
  does.

- element_id_new:

  Optional per-row element ids, used to name every decision. `NULL`
  (default) uses per-scenario row positions.

- problem:

  Optional
  [OptimizationProblem](https://Mischa-Hermans.github.io/dflasso/reference/OptimizationProblem-class.md)
  to attach to a fit made from supplied regret. `NULL` (default) uses
  the fit's own solver and errors if there is none.

- s:

  Penalty strength for the predicted costs: `"lambda.min"` (default),
  `"lambda.1se"`, or a numeric lambda.

- ...:

  Unused, present for S4 compatibility.

## Value

A
[DecisionSet](https://Mischa-Hermans.github.io/dflasso/reference/DecisionSet-class.md)
object, one record per instance. Read it with
[`decisions()`](https://Mischa-Hermans.github.io/dflasso/reference/decision-set-accessors.md),
[`selected_elements()`](https://Mischa-Hermans.github.io/dflasso/reference/decision-set-accessors.md),
[`objectives()`](https://Mischa-Hermans.github.io/dflasso/reference/decision-set-accessors.md),
[`is_feasible()`](https://Mischa-Hermans.github.io/dflasso/reference/decision-set-accessors.md),
and
[`element_sequence()`](https://Mischa-Hermans.github.io/dflasso/reference/decision-set-accessors.md);
subset it with
[`feasible()`](https://Mischa-Hermans.github.io/dflasso/reference/decision-set-feasibility.md)
/
[`infeasible()`](https://Mischa-Hermans.github.io/dflasso/reference/decision-set-feasibility.md);
list the reasons with
[`infeasible_reasons()`](https://Mischa-Hermans.github.io/dflasso/reference/decision-set-feasibility.md);
and pull a long, join-ready table with
[`as_tibble()`](https://tibble.tidyverse.org/reference/as_tibble.html).

## Details

One infeasible instance never aborts the batch: a scenario the solver
cannot satisfy comes back with `feasible = FALSE` and a reason, while
the others still return their decisions.

A fit made from supplied regret has no solver, so `decide()` errors
unless a solver is attached with `problem =` (no re-fit needed). Passing
`problem =` to a fit that already has one also errors.

Each record carries the per-instance `decision` (named by `element_id`:
`0`/`1` for selection and routing, the weight for allocation),
`selected_elements` (the chosen ids), `element_sequence` (the ordered
ids for graph problems, else `NULL`), `predicted_objective`
(`cost_hat' decision`), `feasible`, and a `message` reason when
infeasible. An infeasible instance carries a typed empty decision
(`numeric(0)`), not a bare `NULL`, so downstream code spots it with
`length(decision) == 0L`.

## See also

[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md),
[`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md)
to trust-check the decisions,
[DecisionSet](https://Mischa-Hermans.github.io/dflasso/reference/DecisionSet-class.md).

Other dflasso workflow:
[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md),
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
picks <- decide(fit, sim$x, sim$scenario, element_id_new = sim$element_id)
picks
#> Decisions for 40 instances (dflasso)
#>   40 reached a decision; 0 had no feasible decision.
#>   Objective sense: maximise value.
#> 
#>   A look at two:
#>     scenario_01  -> 2 of 6 chosen: 1, 2   (predicted total value 1.9)
#>     scenario_02  -> 2 of 6 chosen: 1, 2   (predicted total value 1.0)
#> 
#>   -> decisions(x) for the full action per instance (named by the element ids);
#>      as_tibble(x) for one tidy row per (instance, element), join-ready.
head(as_tibble(picks))
#> # A tibble: 6 × 8
#>   scenario element_id decision chosen predicted_cost contribution feasible  step
#>   <chr>    <chr>         <dbl> <lgl>           <dbl>        <dbl> <lgl>    <int>
#> 1 scenari… 1               0.5 TRUE             1.93        0.967 TRUE        NA
#> 2 scenari… 2               0.5 TRUE             1.94        0.968 TRUE        NA
#> 3 scenari… 3               0   FALSE            1.80        0     TRUE        NA
#> 4 scenari… 4               0   FALSE            1.72        0     TRUE        NA
#> 5 scenari… 5               0   FALSE            1.64        0     TRUE        NA
#> 6 scenari… 6               0   FALSE            1.58        0     TRUE        NA
```
