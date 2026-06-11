test_that("the fit plot views each return a ggplot object", {
  skip_if_not_installed("ggplot2")
  fit <- capital_fit()
  expect_s3_class(plot(fit), "ggplot")
  expect_s3_class(plot(fit, type = "penalty"), "ggplot")
  expect_s3_class(plot(fit, type = "path"), "ggplot")
  expect_s3_class(ggplot2::autoplot(fit), "ggplot")
})

test_that("plot warns on an unknown argument such as which=", {
  skip_if_not_installed("ggplot2")
  fit <- capital_fit()
  expect_warning(plot(fit, which = "roles"), "which")
})

test_that("the regret comparison returns a ggplot object", {
  skip_if_not_installed("ggplot2")
  simulation <- capital_fixture()
  fit <- capital_fit(simulation)
  comparison <- suppressMessages(suppressWarnings(
    regret(
      fit, simulation$x, simulation$cost, simulation$scenario,
      element_id_test = simulation$element_id
    )
  ))
  expect_s3_class(plot(comparison), "ggplot")
  expect_s3_class(ggplot2::autoplot(comparison), "ggplot")
})
