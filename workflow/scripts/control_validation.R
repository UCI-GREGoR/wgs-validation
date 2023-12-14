library(ggplot2, quietly = TRUE)

#' Set common ggplot2 theme data for plots
my.theme <- theme_light() + theme(
  plot.title = element_text(size = 16, hjust = 0.5),
  axis.title = element_text(size = 14),
  axis.text = element_text(size = 12),
  strip.background = element_blank(),
  strip.text = element_text(size = 14, colour = "black")
)


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
  ## the output from hap.py, aggregated in this way, requires some filtering
  ## before use. first, and most simply, only use Filter == "PASS"
  df <- df[df[, "Filter"] == "PASS", ]
  ## aggregate metrics data in tidy format
  plot.data <- data.frame(
    "Experimental" = rep(df[, "Experimental"], 3),
    "Reference" = rep(df[, "Reference"], 3),
    "Region" = rep(df[, "Region"], 3),
    "Type" = rep(df[, "Type"], 3),
    "Subset" = rep(df[, "Subset"], 3),
    "Metric" = c(df[, "METRIC.Precision"], df[, "METRIC.Recall"], df[, "METRIC.F1_Score"]),
    "Metric.Type" = factor(rep(c("Precision", "Recall", "F1"), each = nrow(df)),
      levels = c("Precision", "Recall", "F1")
    )
  )
  plot.data$Metric <- as.numeric(plot.data$Metric)
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
  ## dedup: hap.py reports some top-level metrics every time
  ## it emits a file, so when running stratification regions and
  ## using the extended csvs, you end up with the exact same thing
  ## represented over and over
  res <- res[!duplicated(res[, c(1:5, 7)]), ]
  res
}

#' Add name/label pairs as a named vector for downstream iteration
#'
#' @param stratifications list; flattened configuration input
#' from snakemake describing name/label pairs
#' @param comparison.subjects character vector; experimental subject
#' IDs included in this report
#' @return named character vector; somewhat confusingly, input names are
#' values in return vector, while input labels are names in return vector
construct.targets <- function(stratifications, comparison.subjects) {
  res <- c()
  res.names <- c()
  for (i in seq(1, length(stratifications), 3)) {
    include.pattern <- stratifications[[i + 2]]
    if (length(which(stringr::str_detect(comparison.subjects, include.pattern))) > 0) {
      res <- c(res, strwrap(stratifications[[i]]))
      res.names <- c(res.names, stratifications[[i + 1]])
    }
  }
  names(res) <- res.names
  res
}

#' Filter target variant sets with no available data
#'
#' @param targets character vector; set of target variant sets
#' @param data data.frame; loaded variant data
#' @return character vector; filtered set of input targets
#' with empty target sets removed
filter.targets <- function(targets, data) {
  empty.targets <- c()
  for (target in targets) {
    if (length(which(data$Subset == target)) == 0) {
      warning("Empty target variant set removed: \"", target, "\"", sep = "")
      empty.targets <- c(empty.targets, target)
    }
  }
  res <- targets[!(targets %in% empty.targets)]
  stopifnot("No valid target variant sets left for analysis" = {
    length(res) > 0
  })
  res
}

#' Create a simple comparison plot. I'm not currently sure
#' what this plot will look like.
#'
#' @param plot.data data frame of plotting data from post-processed
#' hap.py data
#' @param data.panels character vector, either SNP or INDEL or both
#' @param data.subset character vector, name of bed region used to subset
#' variants for this comparison. examples: "*", "TS_boundary", "refseq_cds".
#' @param data.label character vector, human-legible label of region used
#' to subset variants for this comparison. examples: "All available variants",
#' "RefSeq coding sequence." defaults to NULL. if non-null, the name will
#' be used as the title of the plot
#' @return ggplot2 plot object
make.plot <- function(plot.data, data.panels, data.subset, data.label = NULL) {
  stopifnot("Invalid variant types selected" = {
    length(which(plot.data$Type %in% data.panels)) > 0
  })
  plot.data <- plot.data[plot.data$Type %in% data.panels & plot.data$Subset == data.subset, ]
  subject.label <- paste(plot.data$Experimental, "vs\n", plot.data$Reference)
  plot.data$Type <- factor(plot.data$Type, levels = data.panels)
  plot.data[, "subject.label"] <- subject.label
  my.plot <- ggplot(aes(x = Metric.Type, y = Metric, group = Type, colour = subject.label), data = plot.data)
  my.plot <- my.plot + my.theme + geom_point()
  my.plot <- my.plot + xlab("Evaluation Metric") + ylab("Metric Value")
  my.plot <- my.plot + scale_colour_manual(
    name = "Control",
    values = brewer.pal(8, "Dark2")[seq_len(length(unique(subject.label)))]
  )
  my.plot <- my.plot + scale_y_continuous(limits = c(0, 1))
  my.plot <- my.plot + facet_grid(cols = vars(Type))
  if (!is.null(names(data.label))) {
    my.plot <- my.plot + ggtitle(data.label)
  }
  my.plot
}

#' Create a table of performance statistics
#' based on requested target regions
#'
#' @param plot.data data frame of input data
#' aggregated across hap.py csv output
#' @param variant.types character vector, either SNP or INDEL or both
#' @param targets character vector; entries
#' are "Subset", names are human-legible labels
#' @return kable of report data
make.table <- function(plot.data, variant.types, targets) {
  variants.all <- list()
  variants.final <- list()
  for (variant.type in variant.types) {
    stopifnot("No data for requested variant type" = {
      length(which(plot.data$Type == variant.type)) > 0
    })
    variants.all[[variant.type]] <- plot.data[plot.data$Type == variant.type, ]
    variants.final[[variant.type]] <- data.frame()
  }
  block.cutoffs <- c()
  for (i in seq_len(length(targets))) {
    for (variant.type in variant.types) {
      variants <- variants.all[[variant.type]][variants.all[[variant.type]]$Subset == targets[i], ]
      variants <- data.frame(
        Experimental = variants[variants[, "Metric.Type"] == "Precision", "Experimental"],
        Reference = variants[variants[, "Metric.Type"] == "Precision", "Reference"],
        Precision = variants[variants[, "Metric.Type"] == "Precision", "Metric"],
        Recall = variants[variants[, "Metric.Type"] == "Recall", "Metric"],
        F1 = variants[variants[, "Metric.Type"] == "F1", "Metric"]
      )
      if (nrow(variants.final[[variant.type]]) > 0) {
        variants.final[[variant.type]] <- rbind(variants.final[[variant.type]], variants)
      } else {
        variants.final[[variant.type]] <- variants
      }
      if (length(block.cutoffs) < i) {
        block.cutoffs <- c(block.cutoffs, nrow(variants.final[[variant.type]]))
      }
    }
  }
  ## truncate decimal precision, because come now
  res <- variants.final[[1]]
  if (length(variants.final) > 1) {
    for (i in seq(2, length(variants.final))) {
      res <- cbind(res, variants.final[[i]][, 3:5])
    }
  }
  for (i in seq(3, ncol(res))) {
    res[, i] <- signif(res[, i], 4)
  }
  res <- knitr::kable(res) %>%
    kableExtra::kable_styling("condensed", position = "left", full_width = FALSE)
  ## add mid-table subheaders denoting different stratification sets
  for (i in seq_len(length(targets))) {
    res <- res %>% kableExtra::pack_rows(
      names(targets)[i],
      ifelse(i == 1, 1, block.cutoffs[i - 1] + 1),
      block.cutoffs[i]
    )
  }
  headers <- c("Comparison" = 2)
  headers.per.variant <- rep(3, length(variant.types))
  names(headers.per.variant) <- variant.types
  headers <- c(headers, headers.per.variant)
  res <- res %>% kableExtra::add_header_above(headers)
  res
}
