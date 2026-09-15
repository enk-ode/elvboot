# env-doc.awk -- render the documentation lines of a variable template: stop at '# @internal',
# @tags become labelled sections, everything else is prose with the leading '# ' stripped.
/^#[ \t]*@internal/ { exit }
{
        line = $0
        sub(/^#[ \t]?/, "", line)
        if (sub(/^@summary[ \t]+/, "", line))  { print "Summary:  " line; next }
        if (sub(/^@default[ \t]+/, "", line))  { print "Default:  " line; next }
        if (sub(/^@values[ \t]+/, "", line))   { print "Values:   " line; next }
        if (sub(/^@example[ \t]+/, "", line))  { print "Example:  " line; next }
        if (sub(/^@see[ \t]+/, "", line))      { print "See also: " line; next }
        if (line ~ /^@/)                       { next }
        print line
}
