# An optional custom script to run before Hugo builds your site.
# You can delete it if you do not need it.
library(targets)
tar_make()

message(getwd())
qmd_files <- list.files("./content/", pattern = "^index\\.qmd$", recursive=TRUE)
md_files <- paste0("./content/", gsub("qmd$", "md", qmd_files))

for (md_file in md_files) {
file_in <- readLines(md_file)
file_out <- gsub("[“”]", '"', file_in)
writeLines(file_out, md_file)
}