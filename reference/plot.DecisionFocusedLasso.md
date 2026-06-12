# Plot a fitted decision-focused lasso

Three views of a
[DecisionFocusedLasso](https://Mischa-Hermans.github.io/dflasso/reference/DecisionFocusedLasso-class.md)
fit, each a ggplot. The default `"roles"` view shows which features look
weak at predicting cost yet move the decision, so the method kept them.
`"penalty"` shows how much the decision focus eased the penalty on those
features; `"path"` shows the coefficient path of the decision-focused
fit.

## Usage

``` r
# S3 method for class 'DecisionFocusedLasso'
autoplot(object, type = c("roles", "penalty", "path"), ...)

# S4 method for class 'DecisionFocusedLasso,missing'
plot(x, type = c("roles", "penalty", "path"), ...)
```

## Arguments

- object, x:

  A
  [DecisionFocusedLasso](https://Mischa-Hermans.github.io/dflasso/reference/DecisionFocusedLasso-class.md)
  object.

- type:

  Which view to draw: `"roles"` (default), `"penalty"`, or `"path"`.

- ...:

  Unused, present for method compatibility.

## Value

A ggplot object.

## Details

Feature labels use `ggrepel` when it is installed, and ordinary text
labels otherwise.

## See also

[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md),
[`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md)
and its [`plot()`](https://rdrr.io/r/graphics/plot.default.html) for the
held-out spread.

## Examples

``` r
sim <- simulate_capital_allocation(60, 6, 6, seed = 1)
fit <- dfl_fit(
  sim$x, sim$cost, sim$scenario,
  problem = capital_allocation_problem(max_weight = 0.5),
  element_id = sim$element_id,
  control = dfl_control(seed = 1, n_splits = 5L)
)
plot(fit)

plot(fit, type = "penalty")

```
