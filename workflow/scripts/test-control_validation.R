library(testthat)

## include snakemake.s4 class for script interface
if (!isClass("snakemake.s4")) {
  source("snakemake.R")
}

source("control_validation.R")

test_that("load.single.file successfully reformats an input csv file in tidy format", {

})

test_that("load.files aggregates and subsets a set of csv files", {

})

test_that("construct.targets converts flattened input configuration data into a usable format", {

})

test_that("filter.targets removes datasets with no content", {

})

test_that("make.plot creates a plot with consistent structure", {

})

test_that("make.table creates a table with consistent structure", {

})
