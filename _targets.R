# Created by use_targets().
# Follow the comments below to fill in this target script.
# Then follow the manual to check and run the pipeline:
#   https://books.ropensci.org/targets/walkthrough.html#inspect-the-pipeline # nolint

# Load packages required to define the pipeline:
library(targets)
# library(tarchetypes) # Load other packages as needed. # nolint
source("make_citations.R")
# Set target options:
tar_option_set(
  packages = c("tibble"), # packages that your targets need to run
  format = "rds" # default storage format
  # Set other options as needed.
)

# Replace the target list below with your own:
list(
  tar_target(citations_path, "citations.csv", format="file"),
  tar_target(load_citations, read.csv(citations_path)),
  tar_target(split_citations, split(load_citations, ~ directory)),
  tar_target(publications,
             create_citation_index(split_citations[[1L]]),
             pattern=map(split_citations)),
  tar_target(update_publications,
             \(x) {
               rerun <- len(publications)
               build_site()
             }),
  tar_target(md_files,
             {
               qmd_files <- list.files("content/",
                                       pattern = "^index\\.qmd$",
                                       recursive=TRUE)
               paste0("content/", gsub("qmd$", "md", qmd_files))
             }
  ),
  tar_target(fix_quotes,
             command =
               {
                 file_in <- readLines(md_files[[1]])
                 file_out <- gsub("[“”]", '"', file_in)
                 writeLines(file_out, md_files[[1]])
               },
             pattern = map(md_files))
)
