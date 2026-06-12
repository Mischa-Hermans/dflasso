# A compiled dflasso environment: build tools, dependencies, the package and its tests.
FROM rocker/r-ver:4.5.2

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        gfortran \
        libxml2-dev \
        libcurl4-openssl-dev \
        libssl-dev \
        libglpk-dev \
        pandoc \
    && rm -rf /var/lib/apt/lists/*

RUN install2.r --error --skipinstalled \
        methods glmnet Matrix Rcpp RcppArmadillo \
        foreach parallel doParallel doRNG iterators \
        dplyr tidyr tibble tidyselect rlang \
        ggplot2 generics lpSolve igraph \
        testthat knitr rmarkdown ggrepel \
        ROI ROI.plugin.glpk

WORKDIR /opt/dflasso
COPY . /opt/dflasso

RUN R CMD INSTALL --install-tests .

CMD ["R", "--no-save"]
