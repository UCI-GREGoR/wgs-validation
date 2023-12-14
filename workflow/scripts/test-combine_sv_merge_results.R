library(testthat)

## include snakemake.s4 class for script interface
if (!isClass("snakemake.s4")) {
  source("snakemake.R")
}

source("combine_sv_merge_results.R")
