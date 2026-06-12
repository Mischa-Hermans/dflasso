# Tuned eligibility thresholds

Tuned eligibility-threshold values, one for each built-in problem. Pass
one to the `eligibility_threshold` argument of
[`dfl_control()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_control.md),
for example
`dfl_control(eligibility_threshold = dflasso_tuned_thresholds[["knapsack"]])`.

## Usage

``` r
dflasso_tuned_thresholds
```

## Format

A named numeric vector with three entries: `shortest_path` (150),
`knapsack` (20), and `capital_allocation` (20).

## See also

[`dfl_control()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_control.md)
