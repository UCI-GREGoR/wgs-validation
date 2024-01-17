library(testthat)

## include snakemake.s4 class for script interface
if (!isClass("snakemake.s4")) {
  source("snakemake.R")
}

source("combine_sv_merge_results.R")

#' Construct a series of svdb-format datasets.
#'
#' @param tmpdir character; base temporary directory
#' to which to write test datasets.
#' @param make.empty logical; if true, purge contents
#' of file for empty file handling testing
#' @return list; a list of lists, where each sublist describes
#' the name, codes, and quality metrics of a generated dataset.
make.svdb.data <- function(tmpdir = tempdir(), make.empty = FALSE) {
  filenames <- c(
    tempfile(tmpdir = tmpdir, fileext = ".vcf"),
    tempfile(tmpdir = tmpdir, fileext = ".vcf")
  )
  df <- data.frame(
    CHROM = paste("chr", 1:20, sep = ""),
    POS = 1:20,
    ID = paste("rs", 1:20, sep = ""),
    REF = "A",
    ALT = "CC",
    QUAL = "nonsense",
    FILTER = "PASS",
    SVTYPE = "DEL",
    INFO = c(
      "ref;exp", "ref", "ref", "exp",
      "ref;exp", "ref;exp", "ref;exp", "exp",
      "exp", "exp", "ref", "ref",
      "ref;exp", "ref;exp", "ref", "exp",
      "exp", "ref;exp", "ref;exp", "ref"
    )
  )
  if (make.empty) {
    file.create(filenames[1])
  } else {
    write.table(df, filenames[1], row.names = FALSE, col.names = FALSE, quote = FALSE, sep = "\t")
  }
  df <- data.frame(
    CHROM = paste("chr", 1:12, sep = ""),
    POS = 21:32,
    ID = paste("rs", 21:32, sep = ""),
    REF = "A",
    ALT = "CC",
    QUAL = "nonsense",
    FILTER = "PASS",
    SVTYPE = "INS",
    INFO = c(
      "ref;exp", "ref;exp", "ref;exp", "exp",
      "exp", "exp", "ref", "ref;exp",
      "ref;exp", "exp", "ref", "ref;exp"
    )
  )
  if (make.empty) {
    file.create(filenames[2])
  } else {
    write.table(df, filenames[2], row.names = FALSE, col.names = FALSE, quote = FALSE, sep = "\t")
  }
  list(
    list(
      filename = filenames[1],
      expcode = "exp",
      refcode = "ref",
      fp = 6,
      tp = 8,
      fn = 6,
      prec = 8 / 14,
      recall = 8 / 14,
      f1 = 16 / 28
    ),
    list(
      filename = filenames[2],
      expcode = "exp",
      refcode = "ref",
      fp = 4,
      tp = 6,
      fn = 2,
      prec = 6 / 10,
      recall = 6 / 8,
      f1 = 12 / 18
    )
  )
}

make.truvari.data <- function() {

}

make.svanalyzer.data <- function() {

}

test_that("run.combine.svdb functions with standard input data", {
  test.data <- make.svdb.data()
  out.csv <- tempfile(fileext = ".csv")
  run.combine.svdb(
    sapply(test.data, function(i) {
      i[["filename"]]
    }),
    "exp",
    "ref",
    out.csv
  )
  expect_true(file.exists(out.csv))
  out.df <- read.table(out.csv,
    header = TRUE, stringsAsFactors = FALSE,
    sep = ",", comment.char = "", quote = "",
    check.names = FALSE
  )
  expect_true("Type" %in% colnames(out.df))
  expect_true("Subset" %in% colnames(out.df))
  expect_true("Filter" %in% colnames(out.df))
  expect_true("METRIC.Recall" %in% colnames(out.df))
  expect_true("METRIC.Precision" %in% colnames(out.df))
  expect_true("METRIC.F1_Score" %in% colnames(out.df))
  expect_equal(nrow(out.df), 2)
  for (i in 1:2) {
    expect_equal(out.df[i, "METRIC.Recall"], test.data[[i]]$recall)
    expect_equal(out.df[i, "METRIC.Precision"], test.data[[i]]$prec)
    expect_equal(out.df[i, "METRIC.F1_Score"], test.data[[i]]$f1)
  }
})

test_that("run.combine.svdb can handle input files with no target data", {
  test.data <- make.svdb.data(make.empty = TRUE)
  out.csv <- tempfile(fileext = ".csv")
  run.combine.svdb(
    sapply(test.data, function(i) {
      i[["filename"]]
    }),
    "exp",
    "ref",
    out.csv
  )
  expect_true(file.exists(out.csv))
  expect_equal(file.info(out.csv)$size, 0)
})

test_that("run.combine.svdb can emit empty output files", {
  out.csv <- tempfile(fileext = ".csv")
  run.combine.svdb(
    character(),
    "exp",
    "ref",
    out.csv
  )
  expect_true(file.exists(out.csv))
  expect_equal(file.info(out.csv)$size, 0)
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
