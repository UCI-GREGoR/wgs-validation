library(testthat)

## include snakemake.s4 class for script interface
if (!isClass("snakemake.s4")) {
  source("snakemake.R")
}

source("control_validation.R")

#' Construct a series of hap.py-format datasets.
#'
#' @param tmpdir character; base temporary directory
#' to which to write test datasets.
#' @param make.empty logical; if true, purge contents
#' of file for empty file handling testing
#' @return list; a list of lists, where each sublist describes
#' the name, codes, and quality metrics of a generated dataset.
make.happy.data <- function(tmpdir = tempdir(), make.empty = FALSE) {
  filenames <- c(
    tempfile(tmpdir = tmpdir, fileext = ".csv"),
    tempfile(tmpdir = tmpdir, fileext = ".csv")
  )
  df <- data.frame(
    Experimental = "exp",
    Reference = "ref",
    Region = "all",
    Type = c("*", "SNP", "INDEL", "*", "SNP", "INDEL", "*", "SNP", "INDEL"),
    Subset = c("all", "all", "all", "segdup", "segdup", "segdup", "other", "other", "other"),
    Filter = c("PASS", "PASS", "PASS", "PASS", "PASS", "PASS", "nope", "nope", "nope"),
    METRIC.Recall = c(1 / 10, 2 / 10, 3 / 10, 1 / 11, 2 / 11, 3 / 11, 1 / 12, 2 / 12, 3 / 12),
    METRIC.Precision = c(4 / 10, 5 / 10, 6 / 10, 4 / 11, 5 / 11, 6 / 11, 4 / 12, 5 / 12, 6 / 12),
    METRIC.F1_Score = c(7 / 10, 8 / 10, 9 / 10, 7 / 11, 8 / 11, 9 / 11, 7 / 12, 8 / 12, 9 / 12)
  )
  if (make.empty) {
    file.create(filenames[1])
  } else {
    write.table(df, filenames[1], row.names = FALSE, col.names = TRUE, quote = FALSE, sep = ",")
  }
  df <- data.frame(
    Experimental = "exp",
    Reference = "ref",
    Region = "all",
    Type = c("*", "SNP", "INDEL", "*", "SNP", "INDEL"),
    Subset = c("all", "all", "all", "notindifficult", "notindifficult", "notindifficult"),
    Filter = "PASS",
    METRIC.Recall = c(1 / 10, 2 / 10, 3 / 10, 1 / 12, 2 / 12, 3 / 12),
    METRIC.Precision = c(4 / 10, 5 / 10, 6 / 10, 4 / 12, 5 / 12, 6 / 12),
    METRIC.F1_Score = c(7 / 10, 8 / 10, 9 / 10, 7 / 12, 8 / 12, 9 / 12)
  )
  if (make.empty) {
    file.create(filenames[2])
  } else {
    write.table(df, filenames[2], row.names = FALSE, col.names = TRUE, quote = FALSE, sep = ",")
  }
  list(list(filename = filenames[1]), list(filename = filenames[2]))
}

test_that("load.single.file successfully reformats an input csv file in tidy format", {
  test.data <- make.happy.data()
  df <- load.single.file(test.data[[1]]$filename)
  expected <- data.frame(
    Experimental = rep("exp", 18),
    Reference = rep("ref", 18),
    Region = rep("all", 18),
    Type = rep(c("*", "SNP", "INDEL"), 6),
    Subset = rep(rep(c("all", "segdup"), each = 3), 3),
    Metric = c(
      4 / 10, 5 / 10, 6 / 10, 4 / 11, 5 / 11, 6 / 11,
      1 / 10, 2 / 10, 3 / 10, 1 / 11, 2 / 11, 3 / 11,
      7 / 10, 8 / 10, 9 / 10, 7 / 11, 8 / 11, 9 / 11
    ),
    Metric.Type = rep(c("Precision", "Recall", "F1"), each = 6)
  )
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
