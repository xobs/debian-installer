# Extract the preseeding example from appendix/example-preseed.xml.
# During extraction "line continuations" - that were added for improved
# readability - will be removed, rejoining the split lines.

BEGIN {
    sectpreseed="0"
    inexample="0"
    inseq="0"
    totline=""
}

# Ignore everything before the section with id="example-preseed"
/id="example-preseed"/ {
    sectpreseed="1"
}

# Ignore everything before the line opening the example
# Note: this assumes that <informalexample><screen> is on one line
/<informalexample><screen>/ {
    if ( sectpreseed == "1" ) {
        inexample="1"
        getline
    }
}

# Ignore everything after the line closing the example
# Note: this assumes that </screen></informalexample> is on one line
/<\/screen><\/informalexample>/ {
    inexample="0"
    sectpreseed="0"
}

# Handling of lines not ending with a line continuation character
! /\\[[:space:]]*$/ {
    if ( inexample == "1" ) {
        if ( inseq == "1" ) {
            sub(/^[[:space:]]*/, "")
            sub(/^#[[:space:]]*/, "")
        }
        totline = totline $0

        print totline
        totline=""
        inseq="0"
    }
}

# Handling of lines ending with a line continuation character
/\\[[:space:]]*$/ {
    if ( inexample == "1" ) {
        if ( inseq == "1" ) {
            sub(/^[[:space:]]*/, "")
            sub(/^#[[:space:]]*/, "")
        }
        inseq="1"
        gsub(/\\[[:space:]]*$/, "")
        totline = totline $0
    }
}
