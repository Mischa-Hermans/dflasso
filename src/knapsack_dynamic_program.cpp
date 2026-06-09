#include <Rcpp.h>

using namespace Rcpp;

// [[Rcpp::export]]
IntegerVector knapsack_dynamic_program(NumericVector values,
                                       IntegerVector weights,
                                       int capacity) {
  int n_items = values.size();
  if (weights.size() != n_items) {
    stop("values and weights must have the same length");
  }
  if (capacity < 0) {
    stop("capacity must be nonnegative");
  }

  std::vector<std::vector<double> > best_value(
      n_items + 1, std::vector<double>(capacity + 1, 0.0));

  for (int item = 1; item <= n_items; ++item) {
    int item_weight = weights[item - 1];
    double item_value = values[item - 1];
    for (int budget = 0; budget <= capacity; ++budget) {
      double value_without_item = best_value[item - 1][budget];
      if (item_weight >= 0 && item_weight <= budget) {
        double value_with_item =
            best_value[item - 1][budget - item_weight] + item_value;
        best_value[item][budget] =
            std::max(value_without_item, value_with_item);
      } else {
        best_value[item][budget] = value_without_item;
      }
    }
  }

  IntegerVector selected(n_items, 0);
  int remaining_budget = capacity;
  for (int item = n_items; item >= 1; --item) {
    int item_weight = weights[item - 1];
    if (item_weight >= 0 && item_weight <= remaining_budget) {
      double value_with_item =
          best_value[item - 1][remaining_budget - item_weight] +
          values[item - 1];
      if (value_with_item > best_value[item - 1][remaining_budget]) {
        selected[item - 1] = 1;
        remaining_budget -= item_weight;
      }
    }
  }

  return selected;
}
