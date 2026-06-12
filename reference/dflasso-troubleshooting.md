# Troubleshooting: when something goes wrong

A symptom, its likely cause, and what to do. Some entries describe
dflasso working as designed: a reported no-win, a valid but lopsided
optimum, a low match rate. Each fix points at the function or page that
owns it.

## The package will not install

`install_github` ends in compiler, `make`, or `g++` errors rather than a
dflasso message. dflasso compiles a little C++ on install and no C++
toolchain is present. Install a compiler first, then install dflasso. On
Windows that is Rtools, matched to the R major version, then restart R.
On macOS it is the Xcode command-line tools, `xcode-select --install`.
On Linux it is build-essential or the Development Tools group. Check
with
[`pkgbuild::check_build_tools()`](https://pkgbuild.r-lib.org/reference/has_build_tools.html).
With no local toolchain, use the repository's `Dockerfile`.

## It installed but library(dflasso) errors

The error is `unable to load shared object`, or a missing-symbol crash
on the first call. The install is partial or corrupt, or it built
without the compiler so the compiled routines were never registered.
Re-install with a working compiler as above, confirm with
[`pkgbuild::check_build_tools()`](https://pkgbuild.r-lib.org/reference/has_build_tools.html),
then `install.packages(..., type = "source")` again.

## "No scenario has complete realised costs..."

[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md)
stops. Zero instances are fully observed over the elements the solver
looks at, so decision quality cannot be scored. Because it is a
[`stop()`](https://rdrr.io/r/base/stop.html), there is no fit object to
inspect. Read the coverage report the error prints; it ends "See the
coverage report for which elements are missing." The same report is on
`prepare_instances(...)$coverage`. Then make a handful of instances
complete over their solve set by reconstructing the per-element costs
that were not captured; for routing, model-based travel times or
historical arc averages joined by arc and day. A custom solver that
provably inspects only a subset of rows can declare that subset with
`solve_support` on
[`optimization_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/optimization_problem.md);
this does nothing for the built-ins, whose solve set is intrinsic.
Raising `min_elements_per_scenario` does not help; coverage tests
completeness, which is separate.

## "Only N instances have complete cost data..."

A warning; the fit proceeds. Fully covered instances number between 1
and 30, so the scores carry more sampling noise. The fix is more fully
covered instances (reconstruct per-element costs). Short of that, raise
`n_splits` to 30 or 50 in
[`dfl_control()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_control.md)
to average over more resamples. Read the scores cautiously: judge a
feature by its `proxy_score` in `tidy(fit)` rather than its label, and
confirm direction with
[`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md).

## "nfolds must be bigger than 3" or "only N scenarios have enough rows to fit"

dflasso stops with its own message before glmnet can throw the raw
`nfolds must be bigger than 3` error. The cause is too few usable
scenarios after filtering: dflasso models elements within a scenario,
drops any scenario with fewer than `min_elements_per_scenario`
observed-cost rows, then cross-validates across the survivors. A shape
with one row per scenario leaves nothing to fit. The fixes, in order:
give more rows per scenario; for data that really is one row per
scenario set `min_elements_per_scenario = 1` in
[`dfl_control()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_control.md);
or lower `nfolds`. When fewer scenarios survive than the requested
`nfolds` but at least three remain, dflasso reduces the folds and warns
rather than stopping; raise the row count or lower `nfolds` to silence
that.

## The fit is very slow or looks hung

The decision-quality step runs `solve` about 5.5 times for every fully
covered instance, so many instances or a slow `solve` add up. By default
an interactive session prints one start line and a `Done.` for this step
while a script stays silent; change it with `progress` in
[`dfl_control()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_control.md).
To speed it up, move any cost-independent setup out of `solve` and into
the `instance` object (a prebuilt graph, matrix, or index) so each call
does the minimum. Then set `workers = parallel::detectCores() - 1`,
which helps when instances are many or `solve` is slow and adds overhead
on a tiny fit. Last, lower `n_splits` if noisier scores are acceptable.
Sequential and parallel runs give bit-identical results.

## decide() reports many instances infeasible

For those instances `solve` found no valid decision, for example a
destination unreachable after closures. The batch still runs; every
feasible instance returns its decision. Read `infeasible_reasons(out)`,
a tibble of `scenario` and the specific reason, and check that
instance's graph, closures, or capacity. A cut-set that severs every
origin-to-destination path is the usual cause. `feasible(out)` holds
only the instances that decided; `names(which(!is_feasible(out)))` lists
the failing ids.

## decide() or regret() rejects the scenario as a cost vector

The error reads `scenario_new` (or `scenario_test`) "has a different
value in every row". Passed positionally, a cost vector is easy to put
where the scenario id belongs, and a cost has a distinct value per row,
so it groups nothing into instances. Pass the grouping ids, the same
`scenario` given to
[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md).
The fit path catches this through its modelling-set check; at
[`decide()`](https://Mischa-Hermans.github.io/dflasso/reference/decide.md)
and
[`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md)
the guard reports it directly.

## The route comes back as row numbers instead of arc ids

`element_sequence` and `selected_elements` show "1" "2" "3". No
`element_id` was supplied, so ids defaulted to per-scenario row
positions. Supply labels: `element_id` on
[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md)
and `element_id_new` on
[`decide()`](https://Mischa-Hermans.github.io/dflasso/reference/decide.md),
or build inputs with `dfl_data(..., element_id = arc_id)`, or use
[`prepare_instances()`](https://Mischa-Hermans.github.io/dflasso/reference/prepare_instances.md),
which sets `element_id` to `arc_id` automatically.

## prepare_instances matched only a fraction of the rows

This is the coverage report. A row is dropped only when it cannot be
placed (its arc is not in `arcs`, its date is not a delivery-day, or
that arc was closed that day). A low matched percentage is the normal
shape of sparsely observed data. Read the printed report and
`attr(x, "unplaceable")` for example keys, and fix obvious join typos.
Nothing is imputed; every matched cost still trains the model, and only
a few fully covered instances are needed to score.

## Decision-focused looks the same as the baseline

On this data it may not help, which is a possible result rather than a
malfunction. Read the comparison in `summary(fit)` or
`regret(fit, x_test, cost_test, scenario_test)`; the sign is labelled
and lower regret is better. Read `plot(fit, type = "roles")`: if few or
no features were rescued, there was little decision signal to exploit.
If few instances were scored, the proxy had little to learn from, and
more fully covered instances may change the result.

## All the weight landed on one choice

A corner solution is a valid optimum. It can occur when one option
dominates, or when a loose cap or near-identical predicted costs push
the answer to a corner. Inspect the predicted costs with
`as_tibble(out)` or [`predict()`](https://rdrr.io/r/stats/predict.html),
and the constraint (the `max_weight` on
[`capital_allocation_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/capital_allocation_problem.md),
the knapsack capacity). Tighten the cap if a corner solution is
unwanted.
[`decide()`](https://Mischa-Hermans.github.io/dflasso/reference/decide.md)
returns the optimum without smoothing.

## A different route on re-run

Two fits without a fixed seed; `seed = NULL` draws a fresh one each fit.
The one random step is how instances are resampled to score features.
Fix it up front with `dfl_control(seed = <integer>)`. To reproduce an
earlier fit, feed its seed back: `dfl_control(seed = seed(fit))`.
[`decide()`](https://Mischa-Hermans.github.io/dflasso/reference/decide.md)
itself is deterministic; deciding again from one held fit never changes.

## A saved fit will not reload, or the .rds is huge

A custom `solve` captured its enclosing environment (a big data frame or
a database handle), dragging it into the `.rds`; a warning fired at fit
time. Built-ins never hit this. Define `solve` to read only `costs` and
`instance` and pass per-instance data inside `instance` via
[`make_instances()`](https://Mischa-Hermans.github.io/dflasso/reference/make_instances.md);
such a `solve` saves to a few kilobytes. Or share the data plus
`seed(fit)` and let a colleague re-fit, which never serialises the
closure.

## "solve for scenario '...' returned a vector of length m"

`solve` returned the wrong number of values, or a non-numeric, `NA`, or
`Inf` vector. The eager probe caught it before any model was fit. Return
exactly one finite number per element row of that instance, in row order
(0/1, or a weight). For grids, fix on row-major or column-major and use
it both when building rows and when flattening the solution, the
[`t()`](https://rdrr.io/r/base/t.html) discipline from
`?dflasso-solvers`.

## Results differ on a colleague's machine

A re-fit is bit-identical only on the same R, glmnet, and BLAS. Across
versions the selected-feature list can move by a feature or two near the
margin, which is not an error by either machine. Judge a result by each
feature's `proxy_score` and the
[`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md)
comparison rather than the bare feature list. To remove the variation,
reproduce in a pinned environment (the repository's `Dockerfile`, or
`renv::snapshot()` and `renv::restore()`), or hand over the saved object
to reproduce the routes exactly.

## Two mistakes, but only one shows

Structural checks run all at once per phase (structure, then the solver
probe, then coverage), and every check in a phase fires before any model
is fit. Read the whole list (up to about 8 problems with a `(+k more)`
tail) and fix them together in one round-trip.

## See also

[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md),
[`decide()`](https://Mischa-Hermans.github.io/dflasso/reference/decide.md),
[`dfl_control()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_control.md),
[`optimization_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/optimization_problem.md),
[`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md),
[dflasso-validation](https://Mischa-Hermans.github.io/dflasso/reference/dflasso-validation.md)
