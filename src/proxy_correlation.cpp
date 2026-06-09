// [[Rcpp::depends(RcppArmadillo)]]
#include <RcppArmadillo.h>

// [[Rcpp::export]]
Rcpp::NumericVector column_correlation_abs(const arma::mat& features,
                                           const arma::vec& response) {
  arma::uword n_rows = features.n_rows;
  arma::uword n_cols = features.n_cols;
  if (response.n_elem != n_rows) {
    Rcpp::stop("response must have one value for each row of features");
  }

  Rcpp::NumericVector scores(n_cols);
  if (n_rows < 2) {
    return scores;
  }

  double response_mean = arma::mean(response);
  arma::vec response_centred = response - response_mean;
  double response_norm = std::sqrt(arma::dot(response_centred,
                                             response_centred));
  if (response_norm == 0.0) {
    return scores;
  }

  for (arma::uword column = 0; column < n_cols; ++column) {
    arma::vec feature = features.col(column);
    double feature_mean = arma::mean(feature);
    arma::vec feature_centred = feature - feature_mean;
    double feature_norm = std::sqrt(arma::dot(feature_centred,
                                              feature_centred));
    if (feature_norm == 0.0) {
      scores[column] = 0.0;
    } else {
      double correlation =
          arma::dot(feature_centred, response_centred) /
          (feature_norm * response_norm);
      scores[column] = std::abs(correlation);
    }
  }

  return scores;
}
