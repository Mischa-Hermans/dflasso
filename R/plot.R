#' Plot a fitted decision-focused lasso
#'
#' Three views of a [DecisionFocusedLasso-class] fit, each a ggplot. The default
#' `"roles"` view shows which features look weak at predicting cost yet move the
#' decision, so the method kept them. `"penalty"` shows how much the decision
#' focus eased the penalty on those features; `"path"` shows the coefficient
#' path of the decision-focused fit.
#'
#' @details
#' Feature labels use `ggrepel` when it is installed, and ordinary text labels
#' otherwise.
#'
#' @param object,x A [DecisionFocusedLasso-class] object.
#' @param type Which view to draw: `"roles"` (default), `"penalty"`, or
#'   `"path"`.
#' @param ... Unused, present for method compatibility.
#'
#' @return A ggplot object.
#'
#' @examples
#' sim <- simulate_capital_allocation(60, 6, 6, seed = 1)
#' fit <- dfl_fit(
#'   sim$x, sim$cost, sim$scenario,
#'   problem = capital_allocation_problem(max_weight = 0.5),
#'   element_id = sim$element_id,
#'   control = dfl_control(seed = 1, n_splits = 5L)
#' )
#' plot(fit)
#' plot(fit, type = "penalty")
#'
#' @seealso [dfl_fit()], [regret()] and its `plot()` for the held-out spread.
#' @name plot.DecisionFocusedLasso
#' @importFrom ggplot2 autoplot
#' @include fitted-class.R summary-print.R
NULL

dfl_palette <- c(
  "decision-relevant" = "#1f3a5f",
  "prediction-relevant" = "#7a7a7a",
  "both" = "#13263d",
  "neither" = "#c0c0c0",
  "decision-focused" = "#1f3a5f",
  "prediction-focused" = "#9e9e9e"
)

role_shape <- c(
  "decision-relevant" = 19,
  "prediction-relevant" = 17,
  "both" = 15,
  "neither" = 1
)

role_linetype <- c(
  "decision-relevant" = "solid",
  "prediction-relevant" = "longdash",
  "both" = "dotted",
  "neither" = "solid"
)

role_labels <- c(
  "decision-relevant" = "Changes the decision (rescued)",
  "prediction-relevant" = "Predicts cost (the usual reason to keep)",
  "both" = "Does both",
  "neither" = "Neither (left out)"
)

#' @rdname plot.DecisionFocusedLasso
#' @export
autoplot.DecisionFocusedLasso <- function(object,
                                          type = c("roles", "penalty", "path"),
                                          ...) {
  type <- match.arg(type)
  warn_unknown_plot_args(...)
  switch(
    type,
    roles = plot_roles(object),
    penalty = plot_penalty(object),
    path = plot_path(object)
  )
}

warn_unknown_plot_args <- function(...) {
  extra <- names(list(...))
  if (length(extra) == 0L) {
    return(invisible(NULL))
  }
  hint <- if ("which" %in% extra) {
    " The view is chosen with type=, not which=."
  } else {
    ""
  }
  warning(sprintf(
    "plot() ignored unused argument(s): %s.%s",
    paste(sprintf("'%s'", extra), collapse = ", "), hint
  ), call. = FALSE)
  invisible(NULL)
}

#' @rdname plot.DecisionFocusedLasso
#' @export
setMethod("plot", signature(x = "DecisionFocusedLasso", y = "missing"),
          function(x, type = c("roles", "penalty", "path"), ...) {
            autoplot.DecisionFocusedLasso(x, type = type, ...)
          })

plot_roles <- function(object) {
  data <- roles_data(object)
  rescued <- data[data$role %in% c("decision-relevant", "both"), , drop = FALSE]
  backdrop <- data[!data$role %in% c("decision-relevant", "both"), , drop = FALSE]
  present_roles <- intersect(names(role_labels), as.character(data$role))
  plot_object <- ggplot2::ggplot(
    data,
    ggplot2::aes(x = .data$prediction_relevance, y = .data$proxy_score,
                 colour = .data$role, shape = .data$role)
  ) +
    ggplot2::geom_point(data = backdrop, size = 2.4) +
    ggplot2::geom_point(data = rescued, size = 3.4) +
    ggplot2::scale_colour_manual(
      values = dfl_palette[names(role_labels)], labels = role_labels[present_roles],
      breaks = present_roles, drop = FALSE, name = "Feature role"
    ) +
    ggplot2::scale_shape_manual(
      values = role_shape[names(role_labels)], labels = role_labels[present_roles],
      breaks = present_roles, drop = FALSE, name = "Feature role"
    ) +
    ggplot2::labs(
      title = "Which features were kept for the decision",
      subtitle = paste0(
        "Top-left = rescued: weak at predicting cost, but they change the ",
        "decision."
      ),
      x = "Predicts cost  (lasso predictive strength, 0-1)",
      y = "Changes the decision  (correlation with regret, 0-1)"
    ) +
    dfl_theme() +
    ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = 0.08))
  add_feature_labels(plot_object, rescued, "prediction_relevance",
                     "proxy_score")
}

plot_penalty <- function(object) {
  data <- penalty_data(object)
  if (nrow(data) == 0L) {
    return(empty_penalty_plot())
  }
  data$term <- factor(data$term, levels = data$term[order(data$easing)])
  plot_object <- ggplot2::ggplot(data, ggplot2::aes(y = .data$term)) +
    ggplot2::geom_segment(
      ggplot2::aes(x = .data$adaptive_weight, xend = .data$penalty_factor,
                   yend = .data$term),
      colour = "#555555", linewidth = 1
    ) +
    ggplot2::geom_point(ggplot2::aes(x = .data$adaptive_weight),
                        shape = 21, fill = "white", colour = "#555555",
                        size = 2.6) +
    ggplot2::geom_point(ggplot2::aes(x = .data$penalty_factor,
                                     colour = .data$kept), size = 2.8) +
    ggplot2::scale_x_log10(expand = ggplot2::expansion(mult = c(0.09, 0.13))) +
    ggplot2::scale_colour_manual(
      values = c("Kept by the refit" = dfl_palette[["decision-relevant"]],
                 "Eased, not kept" = "#9e9e9e"),
      drop = FALSE, name = NULL
    ) +
    ggplot2::labs(
      title = "How the decision focus lowers a feature's lasso penalty",
      subtitle = paste0(
        "Each line runs from the usual lasso penalty (open dot) to the eased, ",
        "decision-focused\npenalty (filled dot). Leftward = a lower penalty; the ",
        "refit then keeps some, not all."
      ),
      x = "Lasso penalty on this feature  (log scale; lower = kept more easily)",
      y = NULL
    ) +
    dfl_theme()
  plot_object
}

plot_path <- function(object) {
  data <- path_data(object)
  roles <- stats::setNames(classify_feature_roles(object), object@feature_names)
  data$role <- roles[data$term]
  highlighted <- data[data$role != "neither", , drop = FALSE]
  chosen <- log(object@lambda_min)
  ends <- highlighted[highlighted$log_lambda ==
                        min(highlighted$log_lambda), , drop = FALSE]
  plot_object <- ggplot2::ggplot(
    data, ggplot2::aes(x = .data$log_lambda, y = .data$estimate,
                       group = .data$term)
  ) +
    ggplot2::geom_line(
      data = data[data$role == "neither", , drop = FALSE],
      colour = dfl_palette[["neither"]], linewidth = 0.5
    ) +
    ggplot2::geom_line(
      data = highlighted,
      ggplot2::aes(colour = .data$role, linetype = .data$role), linewidth = 1
    ) +
    ggplot2::geom_vline(xintercept = chosen, linetype = "dashed",
                        colour = "#333333", linewidth = 0.6) +
    ggplot2::annotate("text", x = chosen, y = -Inf, label = "chosen model",
                      hjust = 1.05, vjust = -0.8, size = 3.3, colour = "#333333",
                      fontface = "italic") +
    ggplot2::scale_colour_manual(
      values = dfl_palette[names(role_labels)], labels = role_labels,
      breaks = names(role_labels), drop = FALSE, name = "Feature role"
    ) +
    ggplot2::scale_linetype_manual(
      values = role_linetype[names(role_labels)], labels = role_labels,
      breaks = names(role_labels), drop = FALSE, name = "Feature role"
    ) +
    ggplot2::scale_x_reverse() +
    ggplot2::labs(
      title = "How each feature's effect grows as the lasso penalty relaxes",
      subtitle = paste0(
        "Each line is one feature's coefficient. The penalty is strong at the ",
        "left and relaxes\nrightward; features switch on as it eases, and the ",
        "rescued ones stay small."
      ),
      x = "Lasso penalty  (strong at left, relaxing to the right)",
      y = "Coefficient  (effect on predicted cost)"
    ) +
    dfl_theme() +
    ggplot2::theme(axis.text.x = ggplot2::element_blank(),
                   axis.ticks.x = ggplot2::element_blank())
  add_feature_labels(plot_object, ends, "log_lambda", "estimate")
}

#' Plot the held-out regret against the baseline
#'
#' Draws the per-instance regret of the decision-focused fit against the
#' prediction-focused baseline on the same held-out instances, lower is better,
#' with the printed average marked.
#'
#' @param object,x A `dfl_regret` object, as returned by [regret()].
#' @param y Not used.
#' @param ... Unused, present for method compatibility.
#'
#' @return A ggplot object.
#'
#' @examples
#' sim <- simulate_capital_allocation(80, 6, 6, seed = 1)
#' fit <- dfl_fit(
#'   sim$x, sim$cost, sim$scenario,
#'   problem = capital_allocation_problem(max_weight = 0.5),
#'   element_id = sim$element_id,
#'   control = dfl_control(seed = 1, n_splits = 5L)
#' )
#' result <- regret(fit, sim$x, sim$cost, sim$scenario)
#' plot(result)
#'
#' @seealso [regret()], [plot.DecisionFocusedLasso]
#' @name plot.dfl_regret
NULL

#' @rdname plot.dfl_regret
#' @export
autoplot.dfl_regret <- function(object, ...) {
  if (length(object$regret_per_instance) == 0L) {
    return(empty_regret_plot())
  }
  data <- regret_spread_data(object)
  means <- regret_means(object)
  fill_values <- stats::setNames(
    dfl_palette[c("decision-focused", "prediction-focused")],
    c("Decision-focused model", "Prediction-focused model")
  )
  ggplot2::ggplot(
    data, ggplot2::aes(x = .data$regret, y = .data$model, fill = .data$model)
  ) +
    ggplot2::geom_vline(xintercept = 0, colour = "#999999") +
    ggplot2::geom_boxplot(alpha = 0.7, outlier.alpha = 0.5, width = 0.5,
                          colour = "#333333") +
    ggplot2::geom_point(position = ggplot2::position_jitter(height = 0.12,
                                                            seed = 1L),
                        alpha = 0.45, size = 1.1, colour = "#333333") +
    ggplot2::geom_point(
      data = means, ggplot2::aes(x = .data$regret, y = .data$model),
      shape = 23, size = 3.6, fill = "white", colour = "#222222",
      inherit.aes = FALSE
    ) +
    ggplot2::scale_fill_manual(values = fill_values, name = "Model") +
    ggplot2::labs(
      title = "Per-instance regret on the held-out data",
      subtitle = "The diamond marks each model's average; lower is better.",
      x = "Regret on one instance  (0 = best possible)",
      y = NULL
    ) +
    dfl_theme() +
    ggplot2::theme(legend.position = "none")
}

#' @rdname plot.dfl_regret
#' @exportS3Method graphics::plot
plot.dfl_regret <- function(x, y, ...) {
  autoplot.dfl_regret(x, ...)
}

methods::setOldClass("dfl_regret")

#' @rdname plot.dfl_regret
#' @export
setMethod("plot", signature(x = "dfl_regret", y = "missing"),
          function(x, ...) {
            autoplot.dfl_regret(x, ...)
          })

roles_data <- function(object) {
  roles <- classify_feature_roles(object)
  data.frame(
    term = object@feature_names,
    prediction_relevance = prediction_relevance(object),
    proxy_score = object@proxy_score,
    role = factor(roles, levels = names(role_labels)),
    stringsAsFactors = FALSE
  )
}

prediction_relevance <- function(object) {
  weight <- object@adaptive_weight
  1 / (1 + weight)
}

penalty_data <- function(object) {
  eased <- object@penalty_factor < object@adaptive_weight - 1e-8
  adaptive_weight <- object@adaptive_weight[eased]
  penalty_factor <- object@penalty_factor[eased]
  roles <- classify_feature_roles(object)
  kept <- ifelse(roles[eased] != "neither", "Kept by the refit",
                 "Eased, not kept")
  data.frame(
    term = object@feature_names[eased],
    adaptive_weight = adaptive_weight,
    penalty_factor = penalty_factor,
    easing = (adaptive_weight - penalty_factor) / adaptive_weight,
    kept = factor(kept, levels = c("Kept by the refit", "Eased, not kept")),
    stringsAsFactors = FALSE
  )
}

path_data <- function(object) {
  fit <- object@decision_fit
  beta <- as.matrix(glmnet::coef.glmnet(fit$glmnet.fit))[-1L, , drop = FALSE]
  rownames(beta) <- object@feature_names
  log_lambda <- log(fit$glmnet.fit$lambda)
  per_feature <- lapply(seq_len(nrow(beta)), function(feature_index) {
    data.frame(
      term = rownames(beta)[feature_index],
      log_lambda = log_lambda,
      estimate = beta[feature_index, ],
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, per_feature)
}

regret_spread_data <- function(object) {
  decision <- data.frame(
    model = "Decision-focused model",
    regret = as.numeric(object$regret_per_instance),
    stringsAsFactors = FALSE
  )
  if (is.null(object$regret_baseline_per_instance)) {
    return(model_factor(decision))
  }
  baseline <- data.frame(
    model = "Prediction-focused model",
    regret = as.numeric(object$regret_baseline_per_instance),
    stringsAsFactors = FALSE
  )
  model_factor(rbind(decision, baseline))
}

regret_means <- function(object) {
  rows <- data.frame(
    model = "Decision-focused model",
    regret = object$regret,
    stringsAsFactors = FALSE
  )
  if (!is.null(object$regret_baseline_per_instance) &&
        is.finite(object$regret_baseline)) {
    rows <- rbind(rows, data.frame(
      model = "Prediction-focused model",
      regret = object$regret_baseline,
      stringsAsFactors = FALSE
    ))
  }
  model_factor(rows)
}

model_factor <- function(data) {
  data$model <- factor(
    data$model,
    levels = c("Decision-focused model", "Prediction-focused model")
  )
  data
}

add_feature_labels <- function(plot_object, label_data, x_name, y_name) {
  if (nrow(label_data) == 0L) {
    return(plot_object)
  }
  mapping <- ggplot2::aes(x = .data[[x_name]], y = .data[[y_name]],
                          label = .data$term)
  if (requireNamespace("ggrepel", quietly = TRUE)) {
    return(plot_object +
             ggrepel::geom_text_repel(data = label_data, mapping = mapping,
                                      size = 3, show.legend = FALSE,
                                      max.overlaps = Inf, box.padding = 0.8,
                                      point.padding = 0.3, force = 3,
                                      min.segment.length = 0, seed = 1L))
  }
  plot_object +
    ggplot2::geom_text(data = label_data, mapping = mapping, size = 3,
                       vjust = -0.6, show.legend = FALSE)
}

empty_penalty_plot <- function() {
  ggplot2::ggplot() +
    ggplot2::annotate(
      "text", x = 0, y = 0,
      label = "No feature was eased: the decision focus changed no penalty."
    ) +
    ggplot2::labs(
      title = "Which features the decision focus made easier to keep",
      x = NULL, y = NULL
    ) +
    dfl_theme()
}

empty_regret_plot <- function() {
  ggplot2::ggplot() +
    ggplot2::annotate(
      "text", x = 0, y = 0,
      label = "No instance could be scored: every held-out instance was infeasible."
    ) +
    ggplot2::labs(
      title = "How much worse than the best possible, per instance",
      x = NULL, y = NULL
    ) +
    dfl_theme()
}

dfl_theme <- function() {
  ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold"),
      plot.caption = ggplot2::element_text(colour = "#666666", hjust = 0),
      legend.position = "right"
    )
}
