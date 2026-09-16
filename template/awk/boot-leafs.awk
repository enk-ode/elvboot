# boot-leafs.awk -- the rows of template/tbl/boot-leafs.tbl as words.
#
#   awk -f $ELEBAKE_TEMPLATE_DIR/awk/boot-leafs.awk $ELEBAKE_TEMPLATE_DIR/tbl/boot-leafs.tbl
#
# Every row '<key> <file> <required|optional>' (comments and blank lines
# skipped) becomes one word 'key|file|need', so a for loop can walk the
# table without a nested read (stage boot leafs). Nothing changes.
!/^#/ && NF == 3 { print $1 "|" $2 "|" $3 }
