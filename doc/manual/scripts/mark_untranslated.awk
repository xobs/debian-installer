BEGIN {
    STRLINE = ""
    TRANS_STATUS = 9

    if (RANGE != "") {
        # Check input range
        if (match(RANGE, /^[0-9]+(:[0-9]+)?$/) == 1) {
            TPOS = index(RANGE, ":")
            if (TPOS > 0) {
                RANGE_START = strtonum(substr(RANGE, 1, TPOS - 1))
                RANGE_END = strtonum(substr(RANGE, TPOS + 1, length(RANGE)))
            } else {
                RANGE_START = strtonum(RANGE)
                RANGE_END = strtonum(RANGE)
            }
            print "** Untranslating messages in range from " RANGE_START " to " RANGE_END "." >"/dev/stderr"
        } else {
            print "Range should be in format '<number>' or '<start>:<end>'." >"/dev/stderr"
            exit 1
        }
    }
}

/^#: / {
    line = $0
    gsub(/^#: [^:]*:/, "", line)
    TPOS = index(line, ", ")
    if (STRLINE == "") {
        STRLINE_FIRST = line
    }
    STRLINE_PREV = STRLINE
    if (TPOS == 0) {
        STRLINE = line
    } else {
        STRLINE = substr(line, 1, TPOS - 1)
    }
}

/^msgid / {
    line = $0
    gsub(/^msgid /, "", line)
    MSGID = line
}

/^msgstr / {
    line = $0
    gsub(/^msgstr /, "", line)
    MSGSTR = line
    
    if (STRLINE != "") {
        if (MSGID == MSGSTR) {
            IS_TRANSLATED = 0
        } else {
            IS_TRANSLATED = 1
        }
        
        if (RANGE != "" && STRLINE >= RANGE_START && STRLINE <= RANGE_END) {
            if (IS_TRANSLATED == 1) {
                print "** String " STRLINE " looks translated, leaving unchanged!" >"/dev/stderr"
            } else {
                untranslate()
            }
        }
        
        if (TRANS_STATUS == 9) {
            TRANS_STATUS = IS_TRANSLATED
            if (IS_TRANSLATED == 0) {
                UNTRANS_START = STRLINE
            }
        } else {
            if (TRANS_STATUS == 0 && IS_TRANSLATED == 1) {
                # The previous strings were untranslated but this one is
                if (STRLINE_PREV == UNTRANS_START) {
                    print "** String looks untranslated: " STRLINE_PREV >"/dev/stderr"
                } else {
                    print "** Strings look untranslated: " UNTRANS_START " - " STRLINE_PREV >"/dev/stderr"
                }
                TRANS_STATUS = IS_TRANSLATED
            }
            if (TRANS_STATUS == 1 && IS_TRANSLATED == 0) {
                TRANS_STATUS = IS_TRANSLATED
                UNTRANS_START = STRLINE
            }
        }
    }
}

{
    # For all lines: if untranslating, write line to $filename.untrans
    if (RANGE != "") {
        print $0
    }
}

END {
    if (TRANS_STATUS == 0) {
        if (UNTRANS_START == STRLINE_FIRST) {
            print "** File looks untranslated (" UNTRANS_START " - " STRLINE ")" >"/dev/stderr"
        } else {
            print "** Strings look untranslated: " UNTRANS_START " - " STRLINE >"/dev/stderr"
        }
    }
}

function untranslate() {
    print "** Untranslating string " STRLINE >"/dev/stderr"
    print "msgstr \"\""
    getline
    # Skip other lines belonging to this msgstr
    while (match($0, /^[[:space:]]*"/) > 0) {
        getline
    }
    IS_TRANSLATED = 1
}
