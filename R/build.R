# An optional custom script to run before Hugo builds your site.
# You can delete it if you do not need it.
library(targets)
tar_make()
tar_make() # To make sure the fix_quote targets are noted as up to date