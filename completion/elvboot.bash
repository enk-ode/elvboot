# bash completion for elvboot
#
# The shell side is deliberately thin: it hands the words typed so far to
# 'elvboot complete', which derives the candidates from the #@help corpus
# (command words from the @command usages, placeholder values from the
# database via @completion/@defcompletion). Nothing here needs updating when
# commands are added or renamed.
#
# Install (any one of):
#   /usr/local/share/bash-completion/completions/elvboot     (make install)
#   ~/.local/share/bash-completion/completions/elvboot        (per user)
#   . completion/elvboot.bash                                 (ad hoc)
#
# Protocol: one candidate per line; the lines "@files" and "@dirs" ask the
# shell to complete paths itself. A line with spaces is never a candidate
# (a usage error for a line too long to complete) and is dropped.

_elvboot_complete() {
    local line
    local -a words=("${COMP_WORDS[@]:1:COMP_CWORD}")
    COMPREPLY=()
    while IFS= read -r line; do
        case $line in
            @files)   compopt -o default 2>/dev/null ;;
            @dirs)    compopt -o dirnames 2>/dev/null ;;
            ''|*' '*) ;;
            *)        COMPREPLY+=("$line") ;;
        esac
    done < <(elvboot complete "${words[@]}" 2>/dev/null)
}

complete -F _elvboot_complete elvboot
