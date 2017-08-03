Foldiff
=======

*Easily configurable tool to get the difference between a reference folder and others*

Usage
-----

    $ ruby compare.rb [--exclude=exclude.txt] [-s] [-q] reference folders_to_compare
    
  **-s** skip empty files
  
  **-q** quiet doesn't print the output to the term
  
  **--exclude=filename** file containing rules for comparison
  
  Exclude file
  ------------
  
    # By default, the file diff isn't showed, the report only informs the it differs from the reference.
    # Add a FILE tag to display it :
    FILE "ex.txt" END
    
    # You can alter the behavior for the file by added these options before the END tag
    FILE "example.txt"
       SORT # sort alphabetically the output

       HIDE_MISSING # hide missing files from the reference folder
       HIDE_ADDED # hide the files not in the reference folder

       PARSE ONLY # don't show the diff of the file, just print it
       PARSE ALSO # print the file after the diff

       KEEP_LINES      3,-6 # cut the document before making the diff (negative values begins from the end)

       PRE_REGEX       "s/^[aze]/aze/" # substitution applied before separating lines (there can be as many as you want !)
       REGEX           "s/^[aze]/aze/" # substitution applied after separating lines (there can be as many as you want !)
       
       REGEX 20 "s/a/e/" # apply it twenty times same for PRE_REGEX (not that it may slow down the analysis)
       
       # Those can also be used along with PARSE to change how the file will be parsed
       # (if either PARSE ONLY or PARSE ALSO is set)
       PARSE SORT
       PARSE KEEP_LINES 3,-6
       PARSE REGEX
       PARSE PRE_REGEX

       INCLUDES        "word" # keep only lines including *word* after the regex
       EQUALS          "line" # keep only lines matching exactly *line* after the regex
    END 
