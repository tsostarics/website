citations <- read.csv('citations.csv')

create_citation_index <- function(citation) {
  citation[which(is.na(citation))] <- "" # Remove NAs from output
  names(citation)[names(citation)=="author"] <- "subtitle"
  arg_names <- names(citation)[-1] # Remove directory

  # Create an entry directory if it doesn't already exist
  cite_dir <- paste0("./content/talk/", citations[["directory"]])
  if (!dir.exists(cite_dir)) {
    dir.create(cite_dir)
  }

  # Make index file, will overwrite
  filepath <- paste0(cite_dir, "/index.md")
  file.create(filepath)

  con <- file(filepath, "a")
  link_section <-  "links:\n"
  write("---", file = con)
  write("author: Thomas Sostarics", con)
  for (arg in arg_names) {

    if (arg == "categories"){
      # Split the categories and write as a vector with \n sep
      categories <- strsplit(citations[["categories"]], ";")[[1]]
      write("categories:", con)
      write(paste0("  - ", categories), con)
    } else if (grepl("link_", arg)) {
      # Make the link buttons (code, pdf, etc.)
      if (citation[[arg]] != ""){
        link_button <- make_link_button(citation, arg, cite_dir, link_section)
        write(link_button, con)
        link_section <- ""
      }

    } else if (arg == "description") {
      next
    } else {
      # Else do a key: value pair
      write(glue::glue("{arg}: {citation[[arg]]}"), con)
    }
  }
  write("---\n", con)
  write(citation[['description']], con)
  close(con)
}

make_link_button <- function(citation, arg, cite_dir, link_section) {
  # Split to get the button type
  linkto <- strsplit(arg, "_")[[1]][[2]]
  linkval <- citation[[arg]]
  icon_pack = ifelse(linkto=='osf', 'ai', 'fab') # Change later to named vector

  # Check if this is a file, if so append the citation directory
  linkval <-
    ifelse(
      !grepl(":/", linkval), # i.e., http://
      # Need to chop off the content portion
      gsub("\\./content", "", paste(cite_dir, linkval, sep = "/")),
      linkval
    )

  link_button <-
    c(
      paste0(
        link_section,
        paste("  - icon: ", linkto)
      ),
      paste("    icon_pack: ", icon_pack),
      paste0("    name: ", linkto),
      paste0("    url: ", linkval)
    )

  link_button
}
