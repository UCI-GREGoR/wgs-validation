library(jsonlite)
library(stringr)

#' Combine data from postprocessed svdb merges into a single file in the
#' same format as hap.py's output
#'
#' @details
#' Input columns are as follows:
#' - CHROM: standard vcf
#' - POS: standard vcf
#' - ID: standard vcf
#' - REF: standard vcf
#' - ALT: standard vcf, though note that alt representations for SVs will be strange
#' - QUAL: standard vcf, though from different SV tools and possibly uninterpretable
#' - FILTER: standard vcf, see same warning as for QUAL
#' - INFO/SVTYPE: in theory, one of the standardized SV types from the newer vcf specs
#'   (e.g. https://samtools.github.io/hts-specs/VCFv4.3.pdf):
#'   - DEL: deletion relative to the reference
#'   - INS: insertion of novel sequence relative to the reference
#'   - DUP: region of elevated copy number relative to the reference
#'   - INV: inversion of reference sequence
#'   - CNV: copy number variable region (may be both deletion and duplication)
#'     - DUP:TANDEM: tandem duplication
#'     - DEL:ME: deletion of mobile element relative to the reference
#'     - INS:ME: insertion of a mobile element relative to the reference
#'   - BND: breakend
#' - INFO: annotated by svdb. contains in part a comma-delimited list of
#'   source files that had variants combined into the current record.
#'   multiple INFO entries with the same tag cause issues upstream, so this is
#'   just the entire INFO block
#'
#' The logic flow is as follows (this is a working model):
#' - variants present in reference and experimental are
#'
#' The output format is as follows. Note that the output headers are fixed requirements,
#' though the order of columns is arbitrary.
#' - Experimental: code of experimental dataset
#' - Reference: code of reference dataset
#' - Region: background for evaluation
#' - Type: SNP, INDEL, or *. this may require some consideration, as the hap.py labels
#'   for this category are obviously intended for a different purpose
#' - Subset: name of bed regions for stratification
#' - Filter: from vcf
#' - METRIC.Recall
#' - METRIC.Precision
#' - METRIC.F1_Score
#'
#' @param input.comparisons character vector; name of input tsv with bcftools parsed
#' data from svdb
#' @param experimental.code character vector; name of experimental dataset
#' @param reference.code character vector; name of reference dataset
#' @param confident.region character vector; name of confident calling region background
#' @param stratification.set character vector; name of NIST stratification sets. there
#' should be at least one of these, but likely more
#' @param output.csv character vector; name of output csv file
run.combine.svdb <- function(input.comparisons,
                             experimental.code,
                             reference.code,
                             confident.region,
                             output.csv) {
  stopifnot(is.character(input.comparisons))
  stopifnot(is.character(experimental.code))
  stopifnot(is.character(reference.code))
  stopifnot(is.character(confident.region))
  stopifnot(is.character(output.csv))
  stratification.set <- unname(sapply(basename(input.comparisons), function(i) {
    strsplit(i, "\\.")[[1]][1]
  }))
  res <- data.frame()
  for (i in seq_len(length(input.comparisons))) {
    in.filename <- input.comparisons[i]
    stratification <- stratification.set[i]
    if (stratification == "all_background") {
      stratification <- "*"
    }
    ## deal with the possibility that there are no variants in a stratification region
    if (file.info(in.filename)$size == 0) {
      next
    }
    h <- read.table(in.filename, header = FALSE, stringsAsFactors = FALSE, sep = "\t", comment.char = "")
    colnames(h) <- c(
      "CHROM",
      "POS",
      "ID",
      "REF",
      "ALT",
      "QUAL",
      "FILTER",
      "SVTYPE",
      "INFO"
    )
    in.experimental <- stringr::str_detect(h$INFO, experimental.code)
    in.reference <- stringr::str_detect(h$INFO, reference.code)
    true.positives <- length(which(in.experimental & in.reference))
    false.positives <- length(which(in.experimental & !in.reference))
    false.negatives <- length(which(!in.experimental & in.reference))
    precision <- true.positives / (true.positives + false.positives)
    recall <- true.positives / (true.positives + false.negatives)
    f1 <- 2 * true.positives / (2 * true.positives + false.positives + false.negatives)

    df <- data.frame(
      Type = "SV",
      Subset = stratification,
      Filter = "PASS",
      METRIC.Recall = recall,
      METRIC.Precision = precision,
      "METRIC.F1_Score" = f1,
      check.names = FALSE
    )
    if (nrow(res) == 0) {
      res <- df
    } else {
      res <- rbind(res, df)
    }
  }
  if (nrow(res) == 0) {
    file.create(output.csv)
  } else {
    write.table(res, output.csv, row.names = FALSE, col.names = TRUE, quote = FALSE, sep = ",")
  }
}


#' Combine data from truvari into a single file in the
#' same format as hap.py's output
#'
#' @details
#' Files are jsons with the following entries:
#' - TP-base
#' - TP-call
#' - FP
#' - FN
#' - precision
#' - recall
#' - f1
#' - a bunch of other things that are very much ignored
#'
#' The output format is as follows. Note that the output headers are fixed requirements,
#' though the order of columns is arbitrary.
#' - Experimental: code of experimental dataset
#' - Reference: code of reference dataset
#' - Region: background for evaluation
#' - Type: SNP, INDEL, or *. this may require some consideration, as the hap.py labels
#'   for this category are obviously intended for a different purpose
#' - Subset: name of bed regions for stratification
#' - Filter: from vcf
#' - METRIC.Recall
#' - METRIC.Precision
#' - METRIC.F1_Score
#'
#' @param input.comparisons character vector; name of input jsons from truvari
#' @param experimental.code character vector; name of experimental dataset
#' @param reference.code character vector; name of reference dataset
#' @param confident.region character vector; name of confident calling region background
#' @param stratification.set character vector; name of NIST stratification sets. there
#' should be at least one of these, but likely more
#' @param output.csv character vector; name of output csv file
run.combine.truvari <- function(input.comparisons,
                                experimental.code,
                                reference.code,
                                confident.region,
                                output.csv) {
  stopifnot(is.character(input.comparisons))
  stopifnot(is.character(experimental.code))
  stopifnot(is.character(reference.code))
  stopifnot(is.character(confident.region))
  stopifnot(is.character(output.csv))
  stratification.set <- basename(dirname(input.comparisons))
  res <- data.frame()
  for (i in seq_len(length(input.comparisons))) {
    in.filename <- input.comparisons[i]
    stratification <- stratification.set[i]
    if (stratification == "all_background") {
      stratification <- "*"
    }
    ## deal with the possibility that there are no variants in a stratification region
    if (file.info(in.filename)$size == 0) {
      next
    }
    h <- jsonlite::read_json(in.filename)
    precision <- h$precision
    recall <- h$recall
    f1 <- h$f1

    df <- data.frame(
      Type = "SV",
      Subset = stratification,
      Filter = "PASS",
      METRIC.Recall = recall,
      METRIC.Precision = precision,
      "METRIC.F1_Score" = f1,
      check.names = FALSE
    )
    if (nrow(res) == 0) {
      res <- df
    } else {
      res <- rbind(res, df)
    }
  }
  if (nrow(res) == 0) {
    file.create(output.csv)
  } else {
    write.table(res, output.csv, row.names = FALSE, col.names = TRUE, quote = FALSE, sep = ",")
  }
}

#' Combine data from svanalyzer into a single file in the
#' same format as hap.py's output
#'
#' @details
#' Files are _freetext_ of all things, with entries:
#' ^Recall.* ([^ ]+)%$"
#' ^Precision.* ([^ ]+)%$"
#' ^F1.* ([^ ]+)$"
#' - a bunch of other things that are very much ignored
#'
#' The output format is as follows. Note that the output headers are fixed requirements,
#' though the order of columns is arbitrary.
#' - Experimental: code of experimental dataset
#' - Reference: code of reference dataset
#' - Region: background for evaluation
#' - Type: SNP, INDEL, or *. this may require some consideration, as the hap.py labels
#'   for this category are obviously intended for a different purpose
#' - Subset: name of bed regions for stratification
#' - Filter: from vcf
#' - METRIC.Recall
#' - METRIC.Precision
#' - METRIC.F1_Score
#'
#' @param input.comparisons character vector; name of input jsons from truvari
#' @param experimental.code character vector; name of experimental dataset
#' @param reference.code character vector; name of reference dataset
#' @param confident.region character vector; name of confident calling region background
#' @param stratification.set character vector; name of NIST stratification sets. there
#' should be at least one of these, but likely more
#' @param output.csv character vector; name of output csv file
run.combine.svanalyzer <- function(input.comparisons,
                                   experimental.code,
                                   reference.code,
                                   confident.region,
                                   output.csv) {
  stopifnot(is.character(input.comparisons))
  stopifnot(is.character(experimental.code))
  stopifnot(is.character(reference.code))
  stopifnot(is.character(confident.region))
  stopifnot(is.character(output.csv))
  stratification.set <- unname(sapply(basename(input.comparisons), function(i) {
    strsplit(i, "\\.")[[1]][1]
  }))
  res <- data.frame()
  for (i in seq_len(length(input.comparisons))) {
    in.filename <- input.comparisons[i]
    stratification <- stratification.set[i]
    if (stratification == "all_background") {
      stratification <- "*"
    }
    ## deal with the possibility that there are no variants in a stratification region
    if (file.info(in.filename)$size == 0) {
      next
    }
    h <- readLines(in.filename)
    recall.pattern <- "^Recall.* ([^ ]+)%$"
    precision.pattern <- "^Precision.* ([^ ]+)%$"
    f1.pattern <- "^F1.* ([^ ]+)$"
    precision <- NA
    recall <- NA
    f1 <- NA
    for (line in h) {
      if (stringr::str_detect(line, recall.pattern)) {
        recall <- as.numeric(stringr::str_replace(line, recall.pattern, "\\1")) / 100
      } else if (stringr::str_detect(line, precision.pattern)) {
        precision <- as.numeric(stringr::str_replace(line, precision.pattern, "\\1")) / 100
      } else if (stringr::str_detect(line, f1.pattern)) {
        f1 <- as.numeric(stringr::str_replace(line, f1.pattern, "\\1"))
      }
    }
    stopifnot(
      "Recall not detected in svanalyzer report" = !is.na(recall),
      "Precision not detected in svanalyzer report" = !is.na(precision),
      "F1 not detected in svanalyzer report" = !is.na(f1)
    )

    df <- data.frame(
      Type = "SV",
      Subset = stratification,
      Filter = "PASS",
      METRIC.Recall = recall,
      METRIC.Precision = precision,
      "METRIC.F1_Score" = f1,
      check.names = FALSE
    )
    if (nrow(res) == 0) {
      res <- df
    } else {
      res <- rbind(res, df)
    }
  }
  if (nrow(res) == 0) {
    file.create(output.csv)
  } else {
    write.table(res, output.csv, row.names = FALSE, col.names = TRUE, quote = FALSE, sep = ",")
  }
}
if (exists("snakemake")) {
  toolname <- snakemake@params[["toolname"]]
  if (toolname == "svdb") {
    run.combine.svdb(
      snakemake@input[["comparisons"]],
      snakemake@params[["experimental"]],
      snakemake@params[["reference"]],
      snakemake@params[["region"]],
      snakemake@output[["csv"]]
    )
  } else if (toolname == "truvari") {
    run.combine.truvari(
      snakemake@input[["comparisons"]],
      snakemake@params[["experimental"]],
      snakemake@params[["reference"]],
      snakemake@params[["region"]],
      snakemake@output[["csv"]]
    )
  } else if (toolname == "svanalyzer") {
    run.combine.svanalyzer(
      snakemake@input[["comparisons"]],
      snakemake@params[["experimental"]],
      snakemake@params[["reference"]],
      snakemake@params[["region"]],
      snakemake@output[["csv"]]
    )
  } else {
    stop("Unrecognized tool name: ", toolname, sep = "")
  }
}
