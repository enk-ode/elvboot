# optdata-offset.awk -- the byte offset of the optional data in an EFI_LOAD_OPTION.
#
#   od -An -tu1 <Boot#### variable> | awk -f $ELEBAKE_TEMPLATE_DIR/awk/optdata-offset.awk
#
# The load option: Attributes (4), FilePathListLength (2, little endian), the
# Description as UTF-16 up to a double zero, the file path list of that
# length, then the optional data. Prints the offset, exits 1 when the header
# does not parse (mirrors secboot.sh _fact_optdata_offset). Nothing changes.
{ for (i = 1; i <= NF; i++) v[n++] = $i }
END {
	if (n <= 8) exit 1
	fplen = v[4] + v[5] * 256
	desc = -1
	for (k = 6; k + 1 < n; k += 2) if (v[k] == 0 && v[k+1] == 0) { desc = k + 2 - 6; break }
	if (desc < 0) exit 1
	off = 6 + desc + fplen
	if (off <= 8 || off > n) exit 1
	print off
}
