# The script keeps track of some special situations:
# - 'tags' in comments are not handled well by poxml tools, so these
#   are removed
# - references within comments should not be processed, so we keep
#   a count of opening and closing of comments

BEGIN {
    # Let's first build an array with all the entities (xml files)
    main_count = 0
    while (getline <ENTLIST) {
        delim = index($0, ":")
        i = substr($0, 1, delim - 1)
        
        fname = substr($0, delim + 1, length($0) - delim)
        # Trim any leading and trailing space of filenames
        gsub(/^[[:space:]]*/, "", fname)
        gsub(/[[:space:]]*$/, "", fname)

        ent [i] = fname
        included [i] = 0
    }
}

{
    # In the main loop we only want to process entities that are refered to
    line = $0
    if (match (line, /^[[:space:]]*&.*;[[:space:]]*(<<!.*)*$/) > 0) {
        process_file(line, "main")
    }
}

function process_file(entline, level,   fname, tfname) {
        entname = get_entname(entline)
        if (entname in ent) {
            fname = ent [entname]
            print "Processing: " fname >>LOG
            tfname = TARGET "/in/" fname

            if (level == "main") {
                main_count += 1
                # Change at highest level: change to a new output file
                OUTFILE = tfname
                gsub(/^.*\//, "", OUTFILE)  # strip path
                OUTFILE = TARGET "/" OUTFILE
            } else {
                print "" >>OUTFILE
            }

            if (level == "sub" && included [i] != 0 && included [i] < main_count) {
                print "** Warning: entity '" entname "'was also included in another file." >>LOG
            }
            included [i] = main_count
            parse_file(tfname, fname)

        } else {
            print "** Entity " entname " does not exist and will be skipped!" >>LOG
        }
}

function parse_file(PARSEFILE, FNAME,   fname, nwline, comment_count) {
    comment_count = 0
    fname = FNAME
    
    # Test whether file exists
    getline <PARSEFILE
    if (ERRNO != 0) {
        print "** Error: file '" PARSEFILE "' does not exist!" >>LOG
        return
    }
    
    print "<!-- Start of file " fname " -->" >>OUTFILE
    while (getline <PARSEFILE) {
        nwline = $0

        # Update the count of 'open' comments
        comment_count += count_comments(nwline)

        if (match(nwline, /^[[:space:]]*&.*;[[:space:]]*(<<!.*)*$/) > 0) {
            # If we find another entity reference, we process that file recursively
            if (comment_count != 0) {
                print "** Skipping entity reference '" nwline "' found in comment!" >>LOG
            } else {
                process_file(nwline, "sub")
            }
        } else {
            # Else we just print the line
            if (match(nwline, /<\!--.*<.*>.*<.*>.*-->/) > 0) {
                print "** Comment deleted in line '" nwline "'" >>LOG
                gsub(/<\!--.*<.*>.*<.*>.*-->/, "", nwline)
            }
            print nwline >>OUTFILE
        }
    }
    if (comment_count != 0) {
        print "** Comment count is not zero at end of file: " comment_count >>LOG
    }
    print "<!--   End of file " fname " -->" >>OUTFILE
    close(PARSEFILE)
}

function get_entname(entline,   ename) {
    # Parse the name of the entity out of the entity reference
    ename = entline
    gsub(/^[[:space:]]*&/, "", ename)
    gsub(/;.*$/, "", ename)
    return ename
}

function count_comments(inline,   tmpline, count) {
    # 'abuse' gsub to count them
    tmpline = inline
    count += gsub(/<\!--/, "", tmpline)
    count -= gsub(/-->/, "", tmpline)
    return count
}
