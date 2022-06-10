# Created by use_targets().
# Follow the comments below to fill in this target script.
# Then follow the manual to check and run the pipeline:
#   https://books.ropensci.org/targets/walkthrough.html#inspect-the-pipeline # nolint

# Load packages required to define the pipeline:
library(targets)
# library(tarchetypes) # Load other packages as needed. # nolint

# Set target options:
tar_option_set(
  packages = c("tibble"), # packages that your targets need to run
  format = "rds" # default storage format
  # Set other options as needed.
)

# Replace the target list below with your own:
list(
  tar_target(
    name = tstdata,
    command = list(1,2,3,4)
#   format = "feather" # efficient storage of large data frames # nolint
  ),
  tar_target(
    name = model,
    command = paste("aaa", tstdata, "aaa"),
    pattern = map(tstdata),
  ),
tar_target(
  name = reports,
 command = paste(model, collapse = "---")
)
)
