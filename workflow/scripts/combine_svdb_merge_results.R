run.combine.svdb.merge.results <- function(input.comparisons, output.csv) {

}

if (exists("snakemake")) {
  run.combine.svdb.merge.results(
    snakemake@input[["comparisons"]],
    snakemake@output[["csv"]]
  )
}
