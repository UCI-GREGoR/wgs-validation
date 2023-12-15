library(testthat)

## include snakemake.s4 class for script interface
if (!isClass("snakemake.s4")) {
  source("snakemake.R")
}

source("combine_sv_merge_results.R")

test_that("run.combine.svdb functions with standard input data", {

})

test_that("run.combine.svdb can handle input files with no target data", {

})

test_that("run.combine.svdb can emit empty output files", {

})

test_that("run.combine.truvari functions with standard input data", {

})

test_that("run.combine.truvari can handle input files with no target data", {

})

test_that("run.combine.truvari can emit empty output files", {

})

test_that("run.combine.svanalyzer functions with standard input data", {

})

test_that("run.combine.svanalyzer can handle input files with no target data", {

})

test_that("run.combine.svanalyzer can emit empty output files", {

})

test_that("run.combine can dispatch svdb tasks", {

})

test_that("run.combine can dispatch truvari tasks", {

})

test_that("run.combine can dispatch svanalyzer tasks", {

})

test_that("run.combine can detect invalid toolnames", {

})
