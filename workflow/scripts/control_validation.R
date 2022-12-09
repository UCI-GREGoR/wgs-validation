#' For a single input csv file, load the data,
#' and adjust its format into a tidy format for plotting.
#'
#' @param csv.file character vector; input csv filename
#' @return data.frame; loaded csv data with adjustment into
#' tidy format for ggplot
load.single.file <- function(csv.file) {
  df <- read.table(csv.file,
    header = TRUE, stringsAsFactors = FALSE, sep = ",",
    comment.char = "", quote = "", check.names = FALSE
  )
  plot.data <- data.frame(
    "Experimental" = rep(df[, ""], 3),
    "Reference" = rep(df[, ""], 3),
    "Region" = rep(df[, ""], 3),
    "Metric" = c(df[, ""], df[, ""], df[, ""]),
    "Metric.Type" = factor(rep(c("Precision", "Recall", "F1"), each = nrow(df)),
      levels = c("Precision", "Recall", "F1")
    )
  )
  plot.data
}

#' For a set of input csv files, load everything,
#' and combine into a single tidy data frame for plotting.
#'
#' @param csv.files character vector; set of input csv files
#' for processing
#' @return data.frame; loaded csv data with adjustment into
#' tidy format for ggplot
load.files <- function(csv.files) {
  res <- data.frame()
  df <- NULL
  for (csv.file in csv.files) {
    df <- load.single.file(csv.file)
    if (nrow(res) == 0) {
      res <- df
    } else {
      res <- rbind(res, df)
    }
  }
  res
}
