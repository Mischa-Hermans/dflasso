# Plot the held-out regret against the baseline

Draws the per-instance regret of the decision-focused fit against the
prediction-focused baseline on the same held-out instances, lower is
better, with the printed average marked.

## Usage

``` r
# S3 method for class 'dfl_regret'
autoplot(object, ...)

# S3 method for class 'dfl_regret'
plot(x, y, ...)

# S4 method for class 'dfl_regret,missing'
plot(x, y, ...)
```

## Arguments

- object, x:

  A `dfl_regret` object, as returned by
  [`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md).

- ...:

  Unused, present for method compatibility.

- y:

  Not used.

## Value

A ggplot object.

## See also

[`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md),
[plot.DecisionFocusedLasso](https://Mischa-Hermans.github.io/dflasso/reference/plot.DecisionFocusedLasso.md)

## Examples

``` r
sim <- simulate_capital_allocation(80, 6, 6, seed = 1)
fit <- dfl_fit(
  sim$x, sim$cost, sim$scenario,
  problem = capital_allocation_problem(max_weight = 0.5),
  element_id = sim$element_id,
  control = dfl_control(seed = 1, n_splits = 5L)
)
result <- regret(fit, sim$x, sim$cost, sim$scenario)
plot(result)

```
