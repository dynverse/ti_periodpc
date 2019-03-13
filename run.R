#!/usr/local/bin/Rscript

task <- dyncli::main()
# task <- dyncli::main(
#   c("--dataset", "./example.h5", "--output", "./output.h5"),
#   "./definition.yml"
# )

library(jsonlite)
library(readr)
library(dplyr)
library(purrr)

#   ____________________________________________________________________________
#   Load data                                                               ####

params <- task$params
expression <- task$expression

#   ____________________________________________________________________________
#   Infer trajectory                                                        ####

# TIMING: done with preproc
checkpoints <- list(method_afterpreproc = Sys.time())

# perform PCA dimred
dimred <- dyndimred::dimred(expression, method = "pca", ndim = params$ndim)

# apply principal curve with periodic lowess smoother
fit <- princurve::principal_curve(dimred, smoother = "periodic.lowess", maxit = params$maxit)

# get pseudotime
pseudotime <- fit$lambda %>% magrittr::set_names(rownames(expression))

# TIMING: done with method
checkpoints$method_aftermethod <- Sys.time()

# creating extra output for visualisation purposes
dimred_segment_points <- fit$s

#   ____________________________________________________________________________
#   Save output                                                             ####
output <-
  dynwrap::wrap_data(cell_ids = rownames(expression)) %>%
  dynwrap::add_cyclic_trajectory(pseudotime = pseudotime) %>%
  dynwrap::add_timings(checkpoints)

dimred_segment_progressions <- output$progressions %>% select(from, to, percentage)

output <- output %>%
  dynwrap::add_dimred(
    dimred = dimred,
    dimred_segment_points = dimred_segment_points,
    dimred_segment_progressions = dimred_segment_progressions,
    connect_segments = TRUE
  )

dyncli::write_output(output, task$output)

