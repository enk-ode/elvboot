#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# elebake foundation - the DATABASE-WIDE trust-configuration arsenal.
#
# Five named record families mirror the C initializer grammar 1:1:
# expectation -> MEASUREMENT_<TYPE>(...), claim -> CLAIM(...), gate ->
# GATE_DEFINE(...), trigger -> FIRE(...), policy -> POLICY(...). Objects
# are DB-wide (backend analogy: stages reference them via 'stage phase
# policy add'); a reference never dangles: add checks its referents,
# the catalog names are checked at the BINDING (stage phase policy add)
# and before emission (stage foundation check). CRUD is dumb: name syntax,
# and add is IDEMPOTENT-IMMUTABLE — re-adding the identical record is a
# silent no-op (dump replays), re-adding a DIFFERENT record under the
# same name is refused (a name's meaning never shifts under its users;
# change = drop + add). Drop is free — dangling is verify's business.
# 'show' always renders the C that WOULD be emitted (the C terminals live
# in render.sh: macro/gate/claim/policy render c).

#@help __macro_add3
# @command macro add <MACRO> <type> <label> [<else>] [<defined>]
# @summary Store a macro record for a compiled baseline: <MACRO> is the C macro stem (BOARD_DIGEST), <type> sha256 | byte, <label> the measurement label. The 4-arg form names the #else alternative (a verbatim C expression, '-' derives MEASUREMENT_NONE), the 5-arg form also the defined name ('-' derives <MACRO> minus _DIGEST plus _EXPECTED). No arsenal record is referenced: the chain is write only
# @group   foundation
# @example elebake macro add BOARD_DIGEST sha256 BoardIdentity
# @see     macro drop
# @see     macro show
# @see     expectation add
#@end
__macro_add3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" macro add '$1' '$2' '$3' - -"
}

#@help __macro_add4
# @internal 4-arg sibling of 'macro add': the #else alternative given, the defined name derived
#@end
__macro_add4() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" macro add '$1' '$2' '$3' '$4' -"
}

#@help __macro_fields_valid5
# @command macro fields valid <a1> <a2> <a3> <a4> <a5>
# @summary The fields of a 'macro add' carry no single quote (they land single-quoted in the batch lines and space-joined in the record): a comment line, else an error line
# @group   foundation
# @internal
# @see     macro add
#@end
__macro_fields_valid5() {
        if fnd_fields_ok "$1" "$2" "$3" "$4" "$5"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'macro fields without single quotes'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'macro add: a field carries a single quote (fields without single quotes): $1'"
        fi
}

#@help ___macro_add5
# @internal 5-arg sibling of 'macro add', the canonical form the dump replays: rewrites to 'macro write'
#@end
___macro_add5() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" macro fields valid $(sq "$1") $(sq "$2") $(sq "$3") $(sq "$4") $(sq "$5")"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" macro write $(sq "$1") $(sq "$2") $(sq "$3") $(sq "$4") $(sq "$5")"
}

#@help __macro_write5
# @command macro write <MACRO> <type> <label> <else> <defined>
# @summary The record is there already: rewrite to 'macro rewrite' (unchanged or refused), else to 'macro store'
# @group   foundation
# @internal
# @see     macro add
#@end
__macro_write5() {
        if test -e "$ELEBAKE_BASE/foundation/macros/$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" macro rewrite '$1' '$2' '$3' '$4' '$5'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" macro store '$1' '$2' '$3' '$4' '$5'"
        fi
}

#@help __macro_rewrite5
# @command macro rewrite <MACRO> <type> <label> <else> <defined>
# @summary An existing record with the identical content is a no-op (a comment line); different content is refused -- records are immutable, drop first
# @group   foundation
# @internal
# @see     macro add
#@end
__macro_rewrite5() {
        if test "$(cat "$ELEBAKE_BASE/foundation/macros/$1" 2>/dev/null)" = "$2 $3 $5 $4"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" note 'macro $1 already stored (unchanged)'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'macro add: $1 exists with different content (immutable; drop first)'"
        fi
}

#@help __macro_store5
# @command macro store <MACRO> <type> <label> <else> <defined>
# @summary the stem and the defined name are C macro names (A-Z, 0-9, _; '-' derives), the fields carry no single quote: rewrite to 'macro record', else an error line
# @group   foundation
# @internal
# @see     macro add
#@end
__macro_store5() {
        if fnd_macro_name_ok "$1" && { test "$5" = - || fnd_macro_name_ok "$5"; } && fnd_fields_ok "$2" "$3" "$4" "$5"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" macro record '$1' '$2' '$3' '$4' '$5'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'macro add: invalid macro name or field (the stem and the defined name are C macro names (A-Z, 0-9, _; '-' derives), fields without single quotes): $1 $2 $3 $4 $5'"
        fi
}

#@help _macro_record5
# @command macro record <MACRO> <type> <label> <else> <defined>
# @summary Act terminal: write the record foundation/macros/<MACRO> ('type label defined else'), mode 0600
# @group   foundation
# @internal
# @see     macro add
#@end
_macro_record5() {
        local rec="$ELEBAKE_BASE/foundation/macros/$1"
        printf '%s\n' "printf '%s\\n' '$2 $3 $5 $4' > '$rec'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$rec'"
        emit_note "macro '$1' stored"
}

#@help __macro_exists1
# @command macro exists <macro>
# @summary The macro record foundation/macros/$1 is there: a comment line, else an error line (the reference never dangles)
# @group   foundation
# @internal
# @see     macro add
#@end
__macro_exists1() {
        if test -f "$ELEBAKE_BASE/foundation/macros/$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'macro $1 exists'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'no such macro $1 (macro add first)'"
        fi
}

#@help ___macro_drop1
# @command macro drop <MACRO>
# @summary Remove a macro record: it exists, no macro expectation names the macro it defines (a referenced record is never dropped), then it is erased
# @group   foundation
# @example elebake macro drop BOARD_DIGEST
# @see     macro add
#@end
___macro_drop1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" macro exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" macro unreferenced '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" macro erase '$1'"
}

#@help __macro_unreferenced1
# @command macro unreferenced <MACRO>
# @summary The name the record defines: its third field when given, else the stem minus _DIGEST plus _EXPECTED -- rewrite to 'macro defined unreferenced <name>'
# @group   foundation
# @internal
# @see     macro drop
#@end
__macro_unreferenced1() {
        local type="" label="" defined="" elsev=""
        read -r type label defined elsev 2>/dev/null < "$ELEBAKE_BASE/foundation/macros/$1"
        if test "${defined:--}" != -; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" macro defined unreferenced '$defined'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" macro defined unreferenced '${1%_DIGEST}_EXPECTED'"
        fi
}

#@help __macro_defined_unreferenced1
# @command macro defined unreferenced <name>
# @summary No macro expectation of the arsenal names the defined macro: a comment line, else an error line -- a referenced record is never dropped
# @group   foundation
# @internal
# @see     macro drop
#@end
__macro_defined_unreferenced1() {
        if ! grep -qs "^macro [^ ]* $1$" "$ELEBAKE_BASE"/foundation/expectations/*; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'macro $1 is unreferenced'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'macro drop: $1 is referenced (a macro expectation names it; drop that first)'"
        fi
}

#@help _macro_erase1
# @command macro erase <MACRO>
# @summary Act terminal: remove the record foundation/macros/<MACRO>
# @group   foundation
# @internal
# @see     macro drop
#@end
_macro_erase1() {
        printf '%s\n' "$MODIFY_FILE_REMOVE '$ELEBAKE_BASE/foundation/macros/$1'"
        emit_note "macro '$1' dropped"
}

#@help ___macro_show0
# @command macro show [<macro>]
# @summary Show every macro record (or one) as the C that WOULD be emitted: one 'macro show <macro>' per record; none is a note
# @group   foundation
# @example elebake macro show
# @see     macro add
#@end
___macro_show0() {
        local r="" lines=0
        for r in "$ELEBAKE_BASE"/foundation/macros/*; do
                [ -f "$r" ] || continue
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" macro show '${r##*/}'"
                lines=$((lines + 1))
        done
        test "$lines" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log 'no macros -- macro add <MACRO> <type> <label>'"
}

#@help ___macro_show1
# @internal 1-arg sibling of 'macro show': the record exists, then the #ifdef baseline block it renders (macro render c), prefixed
#@end
___macro_show1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" macro exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" macro render show '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" macro render c '$1' | sed 's/^/#   /'"
}

#@help _macro_render_show1
# @command macro render show <macro>
# @summary Print the display line of one macro record: the #ifdef baseline block it renders (macro render c), prefixed
# @group   foundation
# @internal
# @see     macro show
#@end
_macro_render_show1() {
        printf '# %s:\n' "$1"
}

#@help __expectation_fields_valid4
# @command expectation fields valid <a1> <a2> <a3> <a4>
# @summary The fields of a 'expectation add' carry no single quote (they land single-quoted in the batch lines and space-joined in the record): a comment line, else an error line
# @group   foundation
# @internal
# @see     expectation add
#@end
__expectation_fields_valid4() {
        if fnd_fields_ok "$1" "$2" "$3" "$4"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'expectation fields without single quotes'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'expectation add: a field carries a single quote (fields without single quotes): $1'"
        fi
}

#@help ___expectation_add4
# @command expectation add <expectation> <type> <label> <value>
# @summary Store a named, reusable expectation: <type> byte | sha256 | string | macro | key; a macro expectation names a macro an arsenal macro record defines (the reference never dangles; the type word dispatches the check); a key expectation names the leaf of a kenv record the loader reads at run time, loader.trust.<gate>.<key> -- for a value that includes the loader itself (PcrBank, LoadedImages) and so cannot be compiled into it; stage kenv learn records it, no build follows. Then the record is written -- an identical re-add is a no-op, a different one is refused (immutable; drop first)
# @group   foundation
# @example elebake expectation add fish-0-byte byte AnswerClass 1
# @see     expectation drop
# @see     claim add
# @see     macro add
#@end
___expectation_add4() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" expectation fields valid $(sq "$1") $(sq "$2") $(sq "$3") $(sq "$4")"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" expectation $2 exists '$4'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" expectation write $(sq "$1") $(sq "$2") $(sq "$3") $(sq "$4")"
}

#@help _expectation_macro_exists1
# @command expectation macro exists <macro>
# @summary A macro record of foundation/macros defines the macro (template/awk/macro-defines.awk: the record's third field, or its stem minus _DIGEST plus _EXPECTED)
# @env     ELEBAKE_TEMPLATE_DIR  the template directory (awk programs, tables)
# @group   foundation
# @internal
# @see     expectation add
#@end
_expectation_macro_exists1() {
        printf '%s\n' "awk -v want='$1' -f '$ELEBAKE_TEMPLATE_DIR/awk/macro-defines.awk' '$ELEBAKE_BASE'/foundation/macros/*"
}

#@help __expectation_byte_exists1
# @command expectation byte exists <value>
# @summary A byte expectation references no arsenal record: rewrites to a comment line (lifting -- the type word dispatches totally)
# @group   foundation
# @internal
# @see     expectation add
#@end
__expectation_byte_exists1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'byte expectation $1: no arsenal record to exist'"
}

#@help __expectation_sha256_exists1
# @command expectation sha256 exists <value>
# @summary A sha256 expectation references no arsenal record: rewrites to a comment line (lifting -- the type word dispatches totally)
# @group   foundation
# @internal
# @see     expectation add
#@end
__expectation_sha256_exists1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'sha256 expectation $1: no arsenal record to exist'"
}

#@help __expectation_string_exists1
# @command expectation string exists <value>
# @summary A string expectation references no arsenal record: rewrites to a comment line (lifting -- the type word dispatches totally)
# @group   foundation
# @internal
# @see     expectation add
#@end
__expectation_string_exists1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'string expectation $1: no arsenal record to exist'"
}

#@help __expectation_key_exists1
# @command expectation key exists <key>
# @summary A key expectation references no arsenal record but names the leaf of a kenv record the stage carries -- loader.trust.<gate>.<key>, letters, digits, _ and . -- so it is checked for form: a comment line, else an error line (lifting -- the type word dispatches totally)
# @group   foundation
# @internal
# @see     expectation add
# @see     stage kenv learn
#@end
__expectation_key_exists1() {
        if printf '%s\n' "$1" | grep -qx '[a-z][a-z0-9_.]*'; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'key expectation $1: the loader reads loader.trust.<gate>.$1 at run time (stage kenv learn records it)'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'expectation add: a key is a kenv leaf -- letters, digits, _ and . -- not: $1'"
        fi
}

#@help __expectation_write4
# @command expectation write <expectation> <type> <label> <value>
# @summary The record is there already: rewrite to 'expectation rewrite' (unchanged or refused), else to 'expectation store'
# @group   foundation
# @internal
# @see     expectation add
#@end
__expectation_write4() {
        if test -e "$ELEBAKE_BASE/foundation/expectations/$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" expectation rewrite '$1' '$2' '$3' '$4'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" expectation store '$1' '$2' '$3' '$4'"
        fi
}

#@help __expectation_rewrite4
# @command expectation rewrite <expectation> <type> <label> <value>
# @summary An existing record with the identical content is a no-op (a comment line); different content is refused -- records are immutable, drop first
# @group   foundation
# @internal
# @see     expectation add
#@end
__expectation_rewrite4() {
        if test "$(cat "$ELEBAKE_BASE/foundation/expectations/$1" 2>/dev/null)" = "$2 $3 $4"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" note 'expectation $1 already stored (unchanged)'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'expectation add: $1 exists with different content (immutable; drop first)'"
        fi
}

#@help __expectation_store4
# @command expectation store <expectation> <type> <label> <value>
# @summary the name is a record name, the fields carry no single quote: rewrite to 'expectation record', else an error line
# @group   foundation
# @internal
# @see     expectation add
#@end
__expectation_store4() {
        if fnd_name_ok "$1" && fnd_fields_ok "$2" "$3" "$4"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" expectation record '$1' '$2' '$3' '$4'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'expectation add: invalid name or field (a record name; fields without single quotes): $1 $2 $3 $4'"
        fi
}

#@help _expectation_record4
# @command expectation record <expectation> <type> <label> <value>
# @summary Act terminal: write the record foundation/expectations/<expectation> ('type label value'), mode 0600
# @group   foundation
# @internal
# @see     expectation add
#@end
_expectation_record4() {
        local rec="$ELEBAKE_BASE/foundation/expectations/$1"
        printf '%s\n' "printf '%s\\n' '$2 $3 $4' > '$rec'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$rec'"
        emit_note "expectation '$1' stored"
}

#@help ___expectation_drop1
# @command expectation drop <expectation>
# @summary Remove a expectation: it exists, no claim names it as its expectation (a referenced record is never dropped), then it is erased
# @group   foundation
# @example elebake expectation drop fish-0-byte
# @see     expectation add
#@end
___expectation_drop1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" expectation exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" expectation unreferenced '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" expectation erase '$1'"
}

#@help __expectation_unreferenced1
# @command expectation unreferenced <expectation>
# @summary No record names the expectation: a comment line, else an error line -- a referenced record is never dropped
# @group   foundation
# @internal
# @see     expectation drop
#@end
__expectation_unreferenced1() {
        if ! grep -qs " $1$" "$ELEBAKE_BASE"/foundation/claims/*; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'expectation $1 is unreferenced'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'expectation drop: $1 is referenced (a claim names it; drop that first)'"
        fi
}

#@help _expectation_erase1
# @command expectation erase <expectation>
# @summary Act terminal: remove the expectation record
# @group   foundation
# @internal
# @see     expectation drop
#@end
_expectation_erase1() {
        printf '%s\n' "$MODIFY_FILE_REMOVE '$ELEBAKE_BASE/foundation/expectations/$1'"
        emit_note "expectation '$1' dropped"
}

#@help ___expectation_show0
# @command expectation show [<expectation>]
# @summary Show every expectation record (or one) as the C that WOULD be emitted: one 'expectation show <expectation>' per record; none is a note
# @group   foundation
# @example elebake expectation show
# @see     expectation add
#@end
___expectation_show0() {
        local r="" lines=0
        for r in "$ELEBAKE_BASE"/foundation/expectations/*; do
                [ -f "$r" ] || continue
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" expectation show '${r##*/}'"
                lines=$((lines + 1))
        done
        test "$lines" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log 'no expectations -- expectation add <exp> <type> <label> <value>'"
}

#@help ___expectation_show1
# @internal 1-arg sibling of 'expectation show': the record exists, then its C form: a macro expectation is its macro, the others MEASUREMENT_<TYPE>("label", value)
#@end
___expectation_show1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" expectation exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" expectation render show '$1'"
}

#@help _expectation_render_show1
# @command expectation render show <expectation>
# @summary Print the display line of one expectation record: its C form: a macro expectation is its macro, the others MEASUREMENT_<TYPE>("label", value)
# @group   foundation
# @internal
# @see     expectation show
#@end
_expectation_render_show1() {
        local type="" label="" value=""
        read -r type label value 2>/dev/null < "$ELEBAKE_BASE/foundation/expectations/$1"
        case "$type" in
                macro) printf '# %s: %s\n' "$1" "$value" ;;
                key) printf '# %s: MEASUREMENT_KEY("%s", "%s")\n' "$1" "$label" "$value" ;;
                *) printf '# %s: MEASUREMENT_%s("%s", %s)\n' "$1" "$(printf '%s' "$type" | tr '[:lower:]' '[:upper:]')" "$label" "$value" ;;
        esac
}

#@help __claim_fields_valid5
# @command claim fields valid <a1> <a2> <a3> <a4> <a5>
# @summary The fields of a 'claim add' carry no single quote (they land single-quoted in the batch lines and space-joined in the record): a comment line, else an error line
# @group   foundation
# @internal
# @see     claim add
#@end
__claim_fields_valid5() {
        if fnd_fields_ok "$1" "$2" "$3" "$4" "$5"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'claim fields without single quotes'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'claim add: a field carries a single quote (fields without single quotes): $1'"
        fi
}

#@help ___claim_add5
# @command claim add <claim> <measurement> <diagnose|-> <publish|-> <expectation>
# @summary Store a named, reusable claim: its expectation must exist in the arsenal (the reference never dangles), then the record is written -- an identical re-add is a no-op, a different one is refused (immutable; drop first)
# @group   foundation
# @example elebake claim add fish-0-matched measure_answer_matched - - fish-0-byte
# @see     claim drop
# @see     gate claim add
#@end
___claim_add5() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" claim fields valid $(sq "$1") $(sq "$2") $(sq "$3") $(sq "$4") $(sq "$5")"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" expectation exists '$5'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" claim write $(sq "$1") $(sq "$2") $(sq "$3") $(sq "$4") $(sq "$5")"
}

#@help __claim_write5
# @command claim write <claim> <measurement> <diagnose|-> <publish|-> <expectation>
# @summary The record is there already: rewrite to 'claim rewrite' (unchanged or refused), else to 'claim store'
# @group   foundation
# @internal
# @see     claim add
#@end
__claim_write5() {
        if test -f "$ELEBAKE_BASE/foundation/claims/$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" claim rewrite '$1' '$2' '$3' '$4' '$5'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" claim store '$1' '$2' '$3' '$4' '$5'"
        fi
}

#@help __claim_rewrite5
# @command claim rewrite <claim> <measurement> <diagnose|-> <publish|-> <expectation>
# @summary An existing record with the identical line is a no-op (a comment line); a different line is refused -- records are immutable, drop first
# @group   foundation
# @internal
# @see     claim add
#@end
__claim_rewrite5() {
        if test "$(cat "$ELEBAKE_BASE/foundation/claims/$1" 2>/dev/null)" = "$2 $3 $4 $5"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" note 'claim $1 already stored (unchanged)'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'claim add: $1 exists with different content (immutable; drop first)'"
        fi
}

#@help __claim_store5
# @command claim store <claim> <measurement> <diagnose|-> <publish|-> <expectation>
# @summary The names are record names and the fields carry no single quote (they land in a quoted shell line): rewrite to 'claim record', else an error line
# @group   foundation
# @internal
# @see     claim add
#@end
__claim_store5() {
        if fnd_name_ok "$1" && fnd_name_ok "$5" && fnd_fields_ok "$2" "$3" "$4" "$5"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" claim record '$1' '$2' '$3' '$4' '$5'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'claim add: invalid name or field (names: [A-Za-z0-9_.-], fields without single quotes): $1 $2 $3 $4 $5'"
        fi
}

#@help _claim_record5
# @command claim record <claim> <measurement> <diagnose|-> <publish|-> <expectation>
# @summary Act terminal: write the record foundation/claims/<claim> ('measurement diagnose publish expectation'), mode 0600
# @group   foundation
# @internal
# @see     claim add
#@end
_claim_record5() {
        local rec="$ELEBAKE_BASE/foundation/claims/$1"
        printf '%s\n' "printf '%s\\n' '$2 $3 $4 $5' > '$rec'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$rec'"
        emit_note "claim '$1' stored"
}

#@help ___claim_drop1
# @command claim drop <claim>
# @summary Remove a claim: it exists, no gate lists it (a referenced record is never dropped), then it is erased
# @group   foundation
# @example elebake claim drop fish-0-matched
# @see     claim add
# @see     gate claim drop
#@end
___claim_drop1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" claim exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" claim unreferenced '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" claim erase '$1'"
}

#@help __claim_exists1
# @command claim exists <claim>
# @summary The claim record foundation/claims/$1 is there: a comment line, else an error line (the reference never dangles)
# @group   foundation
# @internal
# @see     claim add
#@end
__claim_exists1() {
        if test -f "$ELEBAKE_BASE/foundation/claims/$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'claim $1 exists'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'no such claim $1 (claim add first)'"
        fi
}

#@help __claim_unreferenced1
# @command claim unreferenced <claim>
# @summary No record names the claim: a comment line, else an error line -- a referenced record is never dropped
# @group   foundation
# @internal
# @see     claim drop
#@end
__claim_unreferenced1() {
        if ! grep -qxs "$1" "$ELEBAKE_BASE"/foundation/gates/*/claims; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'claim $1 is unreferenced'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'claim drop: $1 is referenced (a gate lists it; drop that first)'"
        fi
}

#@help _claim_erase1
# @command claim erase <claim>
# @summary Act terminal: remove the record foundation/claims/<claim>
# @group   foundation
# @internal
# @see     claim drop
#@end
_claim_erase1() {
        printf '%s\n' "$MODIFY_FILE_REMOVE '$ELEBAKE_BASE/foundation/claims/$1'"
        emit_note "claim '$1' dropped"
}

#@help __expectation_exists1
# @command expectation exists <expectation>
# @summary The expectation record foundation/expectations/$1 is there: a comment line, else an error line (the reference never dangles)
# @group   foundation
# @internal
# @see     expectation add
#@end
__expectation_exists1() {
        if test -f "$ELEBAKE_BASE/foundation/expectations/$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'expectation $1 exists'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'no such expectation $1 (expectation add first)'"
        fi
}

#@help ___claim_show0
# @command claim show [<claim>]
# @summary Show every claim record (or one) as the C that WOULD be emitted: one 'claim show <claim>' per record; none is a note
# @group   foundation
# @example elebake claim show
# @see     claim add
#@end
___claim_show0() {
        local r="" lines=0
        for r in "$ELEBAKE_BASE"/foundation/claims/*; do
                [ -f "$r" ] || continue
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" claim show '${r##*/}'"
                lines=$((lines + 1))
        done
        test "$lines" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log 'no claims -- claim add <claim> <measurement> <diagnose|-> <publish|-> <exp>'"
}

#@help ___claim_show1
# @internal 1-arg sibling of 'claim show': the record exists, then its C form CLAIM(measurement, diagnose|NULL, "publish"|NULL, expectation)
#@end
___claim_show1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" claim exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" claim render show '$1'"
}

#@help _claim_render_show1
# @command claim render show <claim>
# @summary Print the display line of one claim record: its C form CLAIM(measurement, diagnose|NULL, "publish"|NULL, expectation)
# @group   foundation
# @internal
# @see     claim show
#@end
_claim_render_show1() {
        local measurement diagnose publish expectation type label value TYPE exp
        read -r measurement diagnose publish expectation 2>/dev/null < "$ELEBAKE_BASE/foundation/claims/$1"
        read -r type label value 2>/dev/null < "$ELEBAKE_BASE/foundation/expectations/$expectation"
        TYPE=$(printf '%s' "$type" | tr '[:lower:]' '[:upper:]')
        test "$diagnose" != - || diagnose=NULL
        test "$publish" = - && publish=NULL || publish="\"$publish\""
        case "$type" in
                macro) exp="$value" ;;
                key) exp="MEASUREMENT_KEY(\"$label\", \"$value\")" ;;
                *) exp="MEASUREMENT_$TYPE(\"$label\", $value)" ;;
        esac
        if test "$type" = string; then
                printf '# %s (container form): _m=$(%s %s); _want=%s; diagnose %s; publish %s\n' "$1" "$measurement" "$(sq "$label")" "$(sq "$value")" "$diagnose" "$publish"
        else
                printf '# %s: CLAIM(%s, %s, %s, %s)\n' "$1" "$measurement" "$diagnose" "$publish" "$exp"
        fi
}

#@help __trigger_fields_valid3
# @command trigger fields valid <a1> <a2> <a3>
# @summary The fields of a 'trigger add' carry no single quote (they land single-quoted in the batch lines and space-joined in the record): a comment line, else an error line
# @group   foundation
# @internal
# @see     trigger add
#@end
__trigger_fields_valid3() {
        if fnd_fields_ok "$1" "$2" "$3"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'trigger fields without single quotes'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'trigger add: a field carries a single quote (fields without single quotes): $1'"
        fi
}

#@help ___trigger_add3
# @command trigger add <trigger> <when> <action>
# @summary Store a named, reusable FIRE(<when>, <action>) pair. Each field is a catalog name or a composition without whitespace: the when may be and(a,b,...), or(a,b,...) or not(a), nested at will; the action may be compose(a,b,...) to run several in order. The loader sees AND/OR/NOT and COMPOSE, the sh containers { a && b; }, { a || b; }, ! a and a; b. The leaves are checked against the container's catalog when a policy binds: no arsenal record is referenced, the chain is write only -- an identical re-add is a no-op, a different one is refused (immutable; drop first)
# @group   foundation
# @example elebake trigger add react-halt when_fail react_halt_act
# @example elebake trigger add unlock-measured 'and(when_fail,not(when_skipped))' unlock_act
# @example elebake trigger add silence-duress when_duress 'compose(taint_act,silence_act)'
# @see     trigger drop
# @see     policy trigger add
#@end
___trigger_add3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" trigger fields valid $(sq "$1") $(sq "$2") $(sq "$3")"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" trigger when valid $(sq "$2")"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" trigger action valid $(sq "$3")"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" trigger write $(sq "$1") $(sq "$2") $(sq "$3")"
}

#@help __trigger_when_valid1
# @command trigger when valid <when>
# @summary The when expression parses (a catalog name, or and(a,b,...), or(a,b,...), not(a), nested at will, no whitespace): a comment line, else an error line
# @group   foundation
# @internal
# @see     trigger add
#@end
__trigger_when_valid1() {
        if fnd_expr_ok when "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'trigger when parses: $1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'trigger add: the when does not parse: $1 (a catalog name, and(a,b), or(a,b), not(a); no whitespace)'"
        fi
}

#@help __trigger_action_valid1
# @command trigger action valid <action>
# @summary The action expression parses (a catalog name, or compose(a,b,...), no whitespace): a comment line, else an error line
# @group   foundation
# @internal
# @see     trigger add
#@end
__trigger_action_valid1() {
        if fnd_expr_ok action "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'trigger action parses: $1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'trigger add: the action does not parse: $1 (a catalog name or compose(a,b); no whitespace)'"
        fi
}

#@help __trigger_write3
# @command trigger write <trigger> <when> <action>
# @summary The record is there already: rewrite to 'trigger rewrite' (unchanged or refused), else to 'trigger store'
# @group   foundation
# @internal
# @see     trigger add
#@end
__trigger_write3() {
        if test -e "$ELEBAKE_BASE/foundation/triggers/$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" trigger rewrite '$1' '$2' '$3'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" trigger store '$1' '$2' '$3'"
        fi
}

#@help __trigger_rewrite3
# @command trigger rewrite <trigger> <when> <action>
# @summary An existing record with the identical content is a no-op (a comment line); different content is refused -- records are immutable, drop first
# @group   foundation
# @internal
# @see     trigger add
#@end
__trigger_rewrite3() {
        if test "$(cat "$ELEBAKE_BASE/foundation/triggers/$1" 2>/dev/null)" = "$2 $3"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" note 'trigger $1 already stored (unchanged)'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'trigger add: $1 exists with different content (immutable; drop first)'"
        fi
}

#@help __trigger_store3
# @command trigger store <trigger> <when> <action>
# @summary the name is a record name, the fields carry no single quote: rewrite to 'trigger record', else an error line
# @group   foundation
# @internal
# @see     trigger add
#@end
__trigger_store3() {
        if fnd_name_ok "$1" && fnd_fields_ok "$2" "$3"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" trigger record '$1' '$2' '$3'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'trigger add: invalid name or field (a record name; fields without single quotes): $1 $2 $3'"
        fi
}

#@help _trigger_record3
# @command trigger record <trigger> <when> <action>
# @summary Act terminal: write the record foundation/triggers/<trigger> ('when action'), mode 0600
# @group   foundation
# @internal
# @see     trigger add
#@end
_trigger_record3() {
        local rec="$ELEBAKE_BASE/foundation/triggers/$1"
        printf '%s\n' "printf '%s\\n' '$2 $3' > '$rec'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$rec'"
        emit_note "trigger '$1' stored"
}

#@help __trigger_exists1
# @command trigger exists <trigger>
# @summary The trigger record foundation/triggers/$1 is there: a comment line, else an error line (the reference never dangles)
# @group   foundation
# @internal
# @see     trigger add
#@end
__trigger_exists1() {
        if test -f "$ELEBAKE_BASE/foundation/triggers/$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'trigger $1 exists'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'no such trigger $1 (trigger add first)'"
        fi
}

#@help ___trigger_drop1
# @command trigger drop <trigger>
# @summary Remove a trigger: it exists, no policy lists it (a referenced record is never dropped), then it is erased
# @group   foundation
# @example elebake trigger drop react-halt
# @see     trigger add
#@end
___trigger_drop1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" trigger exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" trigger unreferenced '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" trigger erase '$1'"
}

#@help __trigger_unreferenced1
# @command trigger unreferenced <trigger>
# @summary No record names the trigger: a comment line, else an error line -- a referenced record is never dropped
# @group   foundation
# @internal
# @see     trigger drop
#@end
__trigger_unreferenced1() {
        if ! grep -qxs "trigger $1" "$ELEBAKE_BASE"/foundation/policies/*; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'trigger $1 is unreferenced'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'trigger drop: $1 is referenced (a policy lists it; drop that first)'"
        fi
}

#@help _trigger_erase1
# @command trigger erase <trigger>
# @summary Act terminal: remove the trigger record
# @group   foundation
# @internal
# @see     trigger drop
#@end
_trigger_erase1() {
        printf '%s\n' "$MODIFY_FILE_REMOVE '$ELEBAKE_BASE/foundation/triggers/$1'"
        emit_note "trigger '$1' dropped"
}

#@help ___trigger_show0
# @command trigger show [<trigger>]
# @summary Show every trigger record (or one) as the C that WOULD be emitted: one 'trigger show <trigger>' per record; none is a note
# @group   foundation
# @example elebake trigger show
# @see     trigger add
#@end
___trigger_show0() {
        local r="" lines=0
        for r in "$ELEBAKE_BASE"/foundation/triggers/*; do
                [ -f "$r" ] || continue
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" trigger show '${r##*/}'"
                lines=$((lines + 1))
        done
        test "$lines" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log 'no triggers -- trigger add <trigger> <when> <action>'"
}

#@help ___trigger_show1
# @internal 1-arg sibling of 'trigger show': the record exists, then its C form FIRE(<when>, <actions>)
#@end
___trigger_show1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" trigger exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" trigger render show '$1'"
}

#@help _trigger_render_show1
# @command trigger render show <trigger>
# @summary Print the display line of one trigger record: its C form FIRE(<when>, <actions>) with AND/OR/NOT and COMPOSE composed
# @group   foundation
# @internal
# @see     trigger show
#@end
_trigger_render_show1() {
        local when="" action=""
        read -r when action 2>/dev/null < "$ELEBAKE_BASE/foundation/triggers/$1"
        printf '# %s: FIRE(%s, %s)\n' "$1" "$(fnd_expr_render when c "$when")" "$(fnd_expr_render action c "$action")"
}

#@help __gate_add1
# @command gate add <gate> [<secret-slot>] [<duress-slot>]
# @summary Create a gate: <gate> is a C identifier (it lands in foundation.c); the slots are the -D macros carrying the unlock and duress hashes (LOADER_TRUST_BOOTLOCK_SECRET, ..._DURESS), '-' or absent for none. No arsenal record is referenced: the chain is write only -- an identical re-add is a no-op, different slots are refused (immutable; drop first)
# @group   foundation
# @example elebake gate add fish_0
# @see     gate drop
# @see     gate claim add
# @see     stage baseline add
#@end
__gate_add1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate add '$1' - -"
}

#@help __gate_add2
# @internal 2-arg sibling of 'gate add': the secret slot given, no duress slot
#@end
__gate_add2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate add '$1' '$2' -"
}

#@help __gate_fields_valid3
# @command gate fields valid <a1> <a2> <a3>
# @summary The fields of a 'gate add' carry no single quote (they land single-quoted in the batch lines and space-joined in the record): a comment line, else an error line
# @group   foundation
# @internal
# @see     gate add
#@end
__gate_fields_valid3() {
        if fnd_fields_ok "$1" "$2" "$3"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'gate fields without single quotes'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'gate add: a field carries a single quote (fields without single quotes): $1'"
        fi
}

#@help ___gate_add3
# @internal 3-arg sibling of 'gate add', the canonical form: rewrites to 'gate write'
#@end
___gate_add3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate fields valid $(sq "$1") $(sq "$2") $(sq "$3")"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate write $(sq "$1") $(sq "$2") $(sq "$3")"
}

#@help __gate_write3
# @command gate write <gate> <secret-slot|-> <duress-slot|->
# @summary The gate directory is there already: rewrite to 'gate rewrite' (unchanged or refused), else to 'gate store'
# @group   foundation
# @internal
# @see     gate add
#@end
__gate_write3() {
        if test -d "$ELEBAKE_BASE/foundation/gates/$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate rewrite '$1' '$2' '$3'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate store '$1' '$2' '$3'"
        fi
}

#@help __gate_rewrite3
# @command gate rewrite <gate> <secret-slot|-> <duress-slot|->
# @summary An existing gate with the same slots is a no-op (a comment line; its claim list is untouched); different slots are refused -- gates are immutable, drop first
# @group   foundation
# @internal
# @see     gate add
#@end
__gate_rewrite3() {
        local d="$ELEBAKE_BASE/foundation/gates/$1"
        if test "$(sed -n 1p "$d/secret" 2>/dev/null)" = "${2#-}" && test "$(sed -n 1p "$d/duress" 2>/dev/null)" = "${3#-}"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" note 'gate $1 already created (unchanged; claims list untouched)'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'gate add: $1 exists with different slots (immutable; drop first)'"
        fi
}

#@help __gate_store3
# @command gate store <gate> <secret-slot|-> <duress-slot|->
# @summary The name is a C identifier and the slots carry no single quote: rewrite to 'gate record', else an error line
# @group   foundation
# @internal
# @see     gate add
#@end
__gate_store3() {
        if fnd_c_ident_ok "$1" && fnd_fields_ok "$2" "$3"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate record '$1' '$2' '$3'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'gate add: invalid name or slot (a C identifier; slots without single quotes): $1 $2 $3'"
        fi
}

#@help ___gate_record3
# @command gate record <gate> <secret-slot|-> <duress-slot|->
# @summary The gate's records: its directory, its secret slot, its duress slot, its (empty) claim list
# @group   foundation
# @internal
# @see     gate add
#@end
___gate_record3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate dir record '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate slot record '$1' secret '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate slot record '$1' duress '$3'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate claims record '$1'"
}

#@help _gate_dir_record1
# @command gate dir record <gate>
# @summary Act terminal: create foundation/gates/<gate>/, mode 0700
# @group   foundation
# @internal
# @see     gate add
#@end
_gate_dir_record1() {
        printf '%s\n' "$MODIFY_DIR_CREATE '$ELEBAKE_BASE/foundation/gates/$1'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0700 '$ELEBAKE_BASE/foundation/gates/$1'"
}

#@help __gate_slot_record3
# @command gate slot record <gate> <secret|duress> <slot|->
# @summary A slot given is written ('gate slot write'), '-' lifts to a comment line
# @group   foundation
# @internal
# @see     gate add
#@end
__gate_slot_record3() {
        if test "$3" != -; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate slot write '$1' '$2' '$3'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'gate $1: no $2 slot'"
        fi
}

#@help _gate_slot_write3
# @command gate slot write <gate> <secret|duress> <slot>
# @summary Act terminal: write foundation/gates/<gate>/<secret|duress> (the -D macro name), mode 0600
# @group   foundation
# @internal
# @see     gate add
#@end
_gate_slot_write3() {
        printf '%s\n' "printf '%s\\n' '$3' > '$ELEBAKE_BASE/foundation/gates/$1/$2'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$ELEBAKE_BASE/foundation/gates/$1/$2'"
}

#@help _gate_claims_record1
# @command gate claims record <gate>
# @summary Act terminal: create the empty claim list foundation/gates/<gate>/claims, mode 0600
# @group   foundation
# @internal
# @see     gate add
#@end
_gate_claims_record1() {
        printf '%s\n' ": > '$ELEBAKE_BASE/foundation/gates/$1/claims'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$ELEBAKE_BASE/foundation/gates/$1/claims'"
        emit_note "gate '$1' created"
}

#@help __gate_exists1
# @command gate exists <gate>
# @summary The gate record foundation/gates/$1 is there: a comment line, else an error line (the reference never dangles)
# @group   foundation
# @internal
# @see     gate add
#@end
__gate_exists1() {
        if test -d "$ELEBAKE_BASE/foundation/gates/$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'gate $1 exists'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'no such gate $1 (gate add first)'"
        fi
}

#@help ___gate_drop1
# @command gate drop <gate>
# @summary Remove a gate: it exists, no policy names it (a referenced record is never dropped), then it is erased
# @group   foundation
# @example elebake gate drop fish_0
# @see     gate add
#@end
___gate_drop1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate unreferenced '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate erase '$1'"
}

#@help __gate_unreferenced1
# @command gate unreferenced <gate>
# @summary No record names the gate: a comment line, else an error line -- a referenced record is never dropped
# @group   foundation
# @internal
# @see     gate drop
#@end
__gate_unreferenced1() {
        if ! grep -qxs "gate $1" "$ELEBAKE_BASE"/foundation/policies/*; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'gate $1 is unreferenced'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'gate drop: $1 is referenced (a policy names it; drop that first)'"
        fi
}

#@help _gate_erase1
# @command gate erase <gate>
# @summary Act terminal: remove the gate record
# @group   foundation
# @internal
# @see     gate drop
#@end
_gate_erase1() {
        printf '%s\n' "rm -rf '$ELEBAKE_BASE/foundation/gates/$1'"
        emit_note "gate '$1' dropped"
}

#@help ___gate_claim_add2
# @command gate claim add <gate> <claim> [<position>]
# @summary Append a claim reference to a gate (order = evaluation order): the gate and the claim exist (the reference never dangles), then the claim is appended -- a claim already listed is a no-op; the 3-arg form inserts at a 1-based position instead
# @group   foundation
# @example elebake gate claim add fish_0 fish-0-matched
# @see     gate claim drop
# @see     claim add
#@end
___gate_claim_add2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" claim exists '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate claim write '$1' '$2'"
}

#@help ___gate_claim_add3
# @internal 3-arg sibling of 'gate claim add': insert at a 1-based position (a claim already listed is refused -- position is placement, not a move: drop first)
#@end
___gate_claim_add3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" claim exists '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate claim insert '$1' '$2' '$3'"
}

#@help __gate_claim_write2
# @command gate claim write <gate> <claim>
# @summary The claim is listed already: a comment line, else 'gate claim append'
# @group   foundation
# @internal
# @see     gate claim add
#@end
__gate_claim_write2() {
        if grep -qxF "$2" "$ELEBAKE_BASE/foundation/gates/$1/claims" 2>/dev/null; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" note 'gate $1: claim $2 already listed'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate claim append '$1' '$2'"
        fi
}

#@help _gate_claim_append2
# @command gate claim append <gate> <claim>
# @summary Act terminal: append the claim to foundation/gates/<gate>/claims
# @group   foundation
# @internal
# @see     gate claim add
#@end
_gate_claim_append2() {
        printf '%s\n' "printf '%s\\n' '$2' >> '$ELEBAKE_BASE/foundation/gates/$1/claims'"
        emit_note "gate '$1': claim '$2' appended"
}

#@help __gate_claim_insert3
# @command gate claim insert <gate> <claim> <position>
# @summary The claim is listed already: an error line (drop first), else 'gate claim place'
# @group   foundation
# @internal
# @see     gate claim add
#@end
__gate_claim_insert3() {
        if grep -qxF "$2" "$ELEBAKE_BASE/foundation/gates/$1/claims" 2>/dev/null; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'gate claim add: $2 already referenced by $1 (position is placement, not a move; drop first)'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate claim place '$1' '$2' '$3'"
        fi
}

#@help __gate_claim_place3
# @command gate claim place <gate> <claim> <position>
# @summary The position is within 1..lines+1: 'gate claim splice', else an error line
# @group   foundation
# @internal
# @see     gate claim add
#@end
__gate_claim_place3() {
        local n; n=$(grep -c "" "$ELEBAKE_BASE/foundation/gates/$1/claims" 2>/dev/null)
        if line_pos_ok "$3" "${n:-0}"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate claim splice '$1' '$2' '$3'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'gate claim add: position $3 out of range (1..$((n + 1)))'"
        fi
}

#@help _gate_claim_splice3
# @command gate claim splice <gate> <claim> <position>
# @summary Act terminal: insert the claim at the position of foundation/gates/<gate>/claims
# @group   foundation
# @internal
# @see     gate claim add
#@end
_gate_claim_splice3() {
        line_insert_emit "$ELEBAKE_BASE/foundation/gates/$1/claims" "$3" "$2"
        emit_note "gate '$1': claim '$2' inserted at $3"
}

#@help ___gate_claim_drop2
# @command gate claim drop <gate> <claim>
# @summary Unlink a claim reference from a gate (the claim itself survives): the gate exists and lists the claim, then the line is removed
# @group   foundation
# @example elebake gate claim drop fish_0 fish-0-matched
# @see     gate claim add
#@end
___gate_claim_drop2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate claim listed '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate claim unlink '$1' '$2'"
}

#@help _gate_claim_listed2
# @command gate claim listed <gate> <claim>
# @summary The gate lists the claim (one grep)
# @group   foundation
# @internal
# @see     gate claim drop
#@end
_gate_claim_listed2() {
        printf '%s\n' "grep -qxF '$2' '$ELEBAKE_BASE/foundation/gates/$1/claims'"
}

#@help _gate_claim_unlink2
# @command gate claim unlink <gate> <claim>
# @summary Act terminal: remove the claim's line from foundation/gates/<gate>/claims
# @group   foundation
# @internal
# @see     gate claim drop
#@end
_gate_claim_unlink2() {
        local f="$ELEBAKE_BASE/foundation/gates/$1/claims"
        printf '%s\n' "grep -vxF '$2' '$f' > '$f.new'; mv '$f.new' '$f'"
        emit_note "gate '$1': claim '$2' unlinked"
}

#@help ___gate_show0
# @command gate show [<gate>]
# @summary Show every gate record (or one) as the C that WOULD be emitted: one 'gate show <gate>' per record; none is a note
# @group   foundation
# @example elebake gate show
# @see     gate add
#@end
___gate_show0() {
        local r="" lines=0
        for r in "$ELEBAKE_BASE"/foundation/gates/*; do
                [ -d "$r" ] || continue
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate show '${r##*/}'"
                lines=$((lines + 1))
        done
        test "$lines" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log 'no gates -- gate add <gate> [<secret-slot>] [<duress-slot>]'"
}

#@help ___gate_show1
# @internal 1-arg sibling of 'gate show': the record exists, then the gate as its emitter writes it, prefixed -- the loader's C form (gate render c) for a gate without a string claim, the container form (gate claims show) for a gate with one: the loader has no MEASUREMENT_STRING
#@end
___gate_show1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate render show '$1'"
        if gate_has_string_claim "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate claims show '$1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate render c '$1' | sed 's/^/#   /'"
        fi
}

#@help ___gate_claims_show1
# @command gate claims show <gate>
# @summary One 'claim render show' per claim of the gate (the container form of a gate with a string expectation)
# @group   foundation
# @internal
# @see     gate show
#@end
___gate_claims_show1() {
        local c=""
        grep . "$ELEBAKE_BASE/foundation/gates/$1/claims" 2>/dev/null | while read -r c; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" claim render show '$c'"
        done
        test -s "$ELEBAKE_BASE/foundation/gates/$1/claims" || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log 'gate $1 lists no claim'"
}

#@help _gate_render_show1
# @command gate render show <gate>
# @summary Print the display line of one gate record: GATE_DEFINE with its slot expressions and every claim it lists, as the emission writes it, prefixed
# @group   foundation
# @internal
# @see     gate show
#@end
_gate_render_show1() {
        printf '# gate %s:\n' "$1"
}

#@help __policy_fields_valid2
# @command policy fields valid <a1> <a2>
# @summary The fields of a 'policy add' carry no single quote (they land single-quoted in the batch lines and space-joined in the record): a comment line, else an error line
# @group   foundation
# @internal
# @see     policy add
#@end
__policy_fields_valid2() {
        if fnd_fields_ok "$1" "$2"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'policy fields without single quotes'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'policy add: a field carries a single quote (fields without single quotes): $1'"
        fi
}

#@help ___policy_add2
# @command policy add <policy> <gate>
# @summary Create a named policy for a gate (triggers are appended separately): the gate exists (the reference never dangles), then the record is written -- an identical re-add is a no-op, a different gate is refused (immutable; drop first)
# @group   foundation
# @example elebake policy add fish-0 fish_0
# @see     policy drop
# @see     policy trigger add
#@end
___policy_add2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" policy fields valid $(sq "$1") $(sq "$2")"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate exists '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" policy write $(sq "$1") $(sq "$2")"
}

#@help __policy_write2
# @command policy write <policy> <gate>
# @summary The record is there already: rewrite to 'policy rewrite' (unchanged or refused), else to 'policy store'
# @group   foundation
# @internal
# @see     policy add
#@end
__policy_write2() {
        if test -e "$ELEBAKE_BASE/foundation/policies/$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" policy rewrite '$1' '$2'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" policy store '$1' '$2'"
        fi
}

#@help __policy_rewrite2
# @command policy rewrite <policy> <gate>
# @summary An existing record with the identical content is a no-op (a comment line); different content is refused -- records are immutable, drop first
# @group   foundation
# @internal
# @see     policy add
#@end
__policy_rewrite2() {
        if test "$(sed -n 's/^gate //p' "$ELEBAKE_BASE/foundation/policies/$1" 2>/dev/null)" = "$2"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" note 'policy $1 already stored (unchanged)'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'policy add: $1 exists with different content (immutable; drop first)'"
        fi
}

#@help __policy_store2
# @command policy store <policy> <gate>
# @summary the name is a record name: rewrite to 'policy record', else an error line
# @group   foundation
# @internal
# @see     policy add
#@end
__policy_store2() {
        if fnd_name_ok "$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" policy record '$1' '$2'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'policy add: invalid name (a record name): $1 $2'"
        fi
}

#@help _policy_record2
# @command policy record <policy> <gate>
# @summary Act terminal: write the record foundation/policies/<policy> (first line 'gate <gate>'), mode 0600
# @group   foundation
# @internal
# @see     policy add
#@end
_policy_record2() {
        local rec="$ELEBAKE_BASE/foundation/policies/$1"
        printf '%s\n' "printf 'gate %s\\n' '$2' > '$rec'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$rec'"
        emit_note "policy '$1' created (gate $2)"
}

#@help __policy_exists1
# @command policy exists <policy>
# @summary The policy record foundation/policies/$1 is there: a comment line, else an error line (the reference never dangles)
# @group   foundation
# @internal
# @see     policy add
#@end
__policy_exists1() {
        if test -f "$ELEBAKE_BASE/foundation/policies/$1"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'policy $1 exists'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'no such policy $1 (policy add first)'"
        fi
}

#@help ___policy_drop1
# @command policy drop <policy>
# @summary Remove a policy: it exists, no phase of any stage binds it (a referenced record is never dropped), then it is erased
# @group   foundation
# @example elebake policy drop fish-0
# @see     policy add
#@end
___policy_drop1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" policy exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" policy unreferenced '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" policy erase '$1'"
}

#@help __policy_unreferenced1
# @command policy unreferenced <policy>
# @summary No record names the policy: a comment line, else an error line -- a referenced record is never dropped
# @group   foundation
# @internal
# @see     policy drop
#@end
__policy_unreferenced1() {
        if ! grep -qxs "$1" "$ELEBAKE_BASE"/stage/*/phases/*; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'policy $1 is unreferenced'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'policy drop: $1 is referenced (a phase of a stage binds it; drop that first)'"
        fi
}

#@help _policy_erase1
# @command policy erase <policy>
# @summary Act terminal: remove the policy record
# @group   foundation
# @internal
# @see     policy drop
#@end
_policy_erase1() {
        printf '%s\n' "$MODIFY_FILE_REMOVE '$ELEBAKE_BASE/foundation/policies/$1'"
        emit_note "policy '$1' dropped"
}

#@help ___policy_trigger_add2
# @command policy trigger add <policy> <trigger> [<position>]
# @summary Append a trigger (FIRE) reference to a policy: the policy and the trigger exist (the reference never dangles), then the trigger line is appended -- a trigger already listed is a no-op; the 3-arg form inserts at a 1-based position among the trigger lines instead
# @group   foundation
# @example elebake policy trigger add fish-0 react-halt
# @see     policy trigger drop
# @see     trigger add
#@end
___policy_trigger_add2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" policy exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" trigger exists '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" policy trigger write '$1' '$2'"
}

#@help ___policy_trigger_add3
# @internal 3-arg sibling of 'policy trigger add': insert at a 1-based position among the trigger lines (the gate line stays first; a trigger already listed is refused -- drop first)
#@end
___policy_trigger_add3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" policy exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" trigger exists '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" policy trigger insert '$1' '$2' '$3'"
}

#@help __policy_trigger_write2
# @command policy trigger write <policy> <trigger>
# @summary The trigger is listed already: a comment line, else 'policy trigger append'
# @group   foundation
# @internal
# @see     policy trigger add
#@end
__policy_trigger_write2() {
        if grep -qxF "trigger $2" "$ELEBAKE_BASE/foundation/policies/$1" 2>/dev/null; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" note 'policy $1: trigger $2 already listed'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" policy trigger append '$1' '$2'"
        fi
}

#@help _policy_trigger_append2
# @command policy trigger append <policy> <trigger>
# @summary Act terminal: append 'trigger <trigger>' to foundation/policies/<policy>
# @group   foundation
# @internal
# @see     policy trigger add
#@end
_policy_trigger_append2() {
        printf '%s\n' "printf 'trigger %s\\n' '$2' >> '$ELEBAKE_BASE/foundation/policies/$1'"
        emit_note "policy '$1': trigger '$2' appended"
}

#@help __policy_trigger_insert3
# @command policy trigger insert <policy> <trigger> <position>
# @summary The trigger is listed already: an error line (drop first), else 'policy trigger place'
# @group   foundation
# @internal
# @see     policy trigger add
#@end
__policy_trigger_insert3() {
        if grep -qxF "trigger $2" "$ELEBAKE_BASE/foundation/policies/$1" 2>/dev/null; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'policy trigger add: $2 already in $1 (position is placement, not a move; drop first)'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" policy trigger place '$1' '$2' '$3'"
        fi
}

#@help __policy_trigger_place3
# @command policy trigger place <policy> <trigger> <position>
# @summary The position is within 1..triggers+1: 'policy trigger splice', else an error line
# @group   foundation
# @internal
# @see     policy trigger add
#@end
__policy_trigger_place3() {
        local n; n=$(grep -c "^trigger " "$ELEBAKE_BASE/foundation/policies/$1" 2>/dev/null)
        if line_pos_ok "$3" "${n:-0}"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" policy trigger splice '$1' '$2' '$3'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'policy trigger add: position $3 out of range (1..$((n + 1)))'"
        fi
}

#@help _policy_trigger_splice3
# @command policy trigger splice <policy> <trigger> <position>
# @summary Act terminal: insert 'trigger <trigger>' at trigger position <position> (file line position+1, the gate line stays first)
# @group   foundation
# @internal
# @see     policy trigger add
#@end
_policy_trigger_splice3() {
        line_insert_emit "$ELEBAKE_BASE/foundation/policies/$1" "$(($3 + 1))" "trigger $2"
        emit_note "policy '$1': trigger '$2' inserted at $3"
}

#@help ___policy_trigger_drop2
# @command policy trigger drop <policy> <trigger>
# @summary Remove a trigger reference from a policy (the trigger itself survives): the policy exists and lists the trigger, then the line is removed
# @group   foundation
# @example elebake policy trigger drop fish-0 react-halt
# @see     policy trigger add
#@end
___policy_trigger_drop2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" policy exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" policy trigger listed '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" policy trigger unlink '$1' '$2'"
}

#@help _policy_trigger_listed2
# @command policy trigger listed <policy> <trigger>
# @summary The policy lists the trigger (one grep)
# @group   foundation
# @internal
# @see     policy trigger drop
#@end
_policy_trigger_listed2() {
        printf '%s\n' "grep -qxF 'trigger $2' '$ELEBAKE_BASE/foundation/policies/$1'"
}

#@help _policy_trigger_unlink2
# @command policy trigger unlink <policy> <trigger>
# @summary Act terminal: remove the 'trigger <trigger>' line from foundation/policies/<policy>
# @group   foundation
# @internal
# @see     policy trigger drop
#@end
_policy_trigger_unlink2() {
        local f="$ELEBAKE_BASE/foundation/policies/$1"
        printf '%s\n' "grep -vxF 'trigger $2' '$f' > '$f.new'; mv '$f.new' '$f'"
        emit_note "policy '$1': trigger '$2' removed"
}

#@help ___policy_show0
# @command policy show [<policy>]
# @summary Show every policy record (or one) as the C that WOULD be emitted: one 'policy show <policy>' per record; none is a note
# @group   foundation
# @example elebake policy show
# @see     policy add
#@end
___policy_show0() {
        local r="" lines=0
        for r in "$ELEBAKE_BASE"/foundation/policies/*; do
                [ -f "$r" ] || continue
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" policy show '${r##*/}'"
                lines=$((lines + 1))
        done
        test "$lines" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log 'no policies -- policy add <policy> <gate>'"
}

#@help ___policy_show1
# @internal 1-arg sibling of 'policy show': the record exists, then its POLICY_TABLE_DEFINE(...) as the emission writes it, prefixed
#@end
___policy_show1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" policy exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" policy render show '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" policy render c '$1' | sed 's/^/#   /'"
}

#@help _policy_render_show1
# @command policy render show <policy>
# @summary Print the display line of one policy record: its name, before the POLICY_TABLE_DEFINE the emission writes
# @group   foundation
# @internal
# @see     policy show
#@end
_policy_render_show1() {
        printf '# policy %s:\n' "$1"
}

#@help ___foundation_dump0
# @command foundation dump
# @summary Emit the foundation portion of a database dump: one block per family in dependency order (macros, expectations, claims, triggers, gates, policies); adds are idempotent-immutable, so replays are safe
# @group   foundation
# @see     dump
#@end
___foundation_dump0() {
        printf '%s\n' "# foundation arsenal - CLI replay per family (dependency order)"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" macro dump"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" expectation dump"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" claim dump"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" trigger dump"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate dump"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" policy dump"
}

#@help ___macro_dump0
# @internal dump block (cat-pinned): one 'macro add' replay per record
#@end
___macro_dump0() {
        local base="$ELEBAKE_BASE" f="" type="" label="" value=""
        for f in "$base"/foundation/macros/*; do
                [ -f "$f" ] || continue
                read -r type label value < "$f"   # value = "<defined> <else...>"
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" macro add '$(basename "$f")' '$type' '$label' '${value#* }' '${value%% *}'"
        done
        return 0
}

#@help ___expectation_dump0
# @internal dump block (cat-pinned): one 'expectation add' replay per record
#@end
___expectation_dump0() {
        local base="$ELEBAKE_BASE" f="" type="" label="" value=""
        for f in "$base"/foundation/expectations/*; do
                [ -f "$f" ] || continue
                read -r type label value 2>/dev/null < "$f"
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" expectation add '$(basename "$f")' '$type' '$label' '$value'"
        done
        return 0
}

#@help ___claim_dump0
# @internal dump block (cat-pinned): one 'claim add' replay per record
#@end
___claim_dump0() {
        local base="$ELEBAKE_BASE" f=""
        for f in "$base"/foundation/claims/*; do
                [ -f "$f" ] || continue
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" claim add '$(basename "$f")' $(sed "s/[^ ]*/'&'/g" "$f")"
        done
        return 0
}

#@help ___trigger_dump0
# @internal dump block (cat-pinned): one 'trigger add' replay per record
#@end
___trigger_dump0() {
        local base="$ELEBAKE_BASE" f=""
        for f in "$base"/foundation/triggers/*; do
                [ -f "$f" ] || continue
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" trigger add '$(basename "$f")' $(sed "s/[^ ]*/'&'/g" "$f")"
        done
        return 0
}

#@help ___gate_dump0
# @internal dump block (cat-pinned): per gate the canonical 'gate add <gate> <secret|-> <duress|->' (a missing slot file is '-') and one 'gate claim add' per claim line -- flat, the dump prints what it is given
#@end
___gate_dump0() {
        local g="" secret="" duress=""
        for g in "$ELEBAKE_BASE"/foundation/gates/*/; do
                [ -d "$g" ] || continue
                g=${g%/}; g=${g##*/}
                secret=$(sed -n 1p "$ELEBAKE_BASE/foundation/gates/$g/secret" 2>/dev/null)
                duress=$(sed -n 1p "$ELEBAKE_BASE/foundation/gates/$g/duress" 2>/dev/null)
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate add '$g' '${secret:--}' '${duress:--}'"
                sed "s|^|\"\$ELEBAKE_CONTEXT_SCRIPT\" gate claim add '$g' '|; s|\$|'|" "$ELEBAKE_BASE/foundation/gates/$g/claims" 2>/dev/null
        done
}

#@help ___policy_dump0
# @internal dump block (cat-pinned): per policy 'policy add <policy> <gate>' and one 'policy trigger add' per trigger line -- flat
#@end
___policy_dump0() {
        local f="" p=""
        for f in "$ELEBAKE_BASE"/foundation/policies/*; do
                [ -f "$f" ] || continue
                p=${f##*/}
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" policy add '$p' '$(sed -n "s/^gate //p" "$f" 2>/dev/null)'"
                sed -n "s|^trigger \(.*\)|\"\$ELEBAKE_CONTEXT_SCRIPT\" policy trigger add '$p' '\1'|p" "$f" 2>/dev/null
        done
}

#@help _foundation_collect0
# @command foundation collect
# @summary List the arsenal record files (macros, expectations, claims, triggers, gates, policies) that belong into an archive
# @env     ELEBAKE_ARCHIVE_BASE  the prefix the emitted paths are written against
# @group   foundation
# @see     collect
#@end
_foundation_collect0() {
        local base="$ELEBAKE_BASE" fam="" f=""
        printf '# foundation\n'
        for fam in macros expectations claims triggers gates policies; do
                [ -d "$base/foundation/$fam" ] || continue
                find "$base/foundation/$fam" \( -type f -o -type l \) 2>/dev/null | sort | while IFS= read -r f; do
                        printf '"$ELEBAKE_ARCHIVE_BASE"/%s\n' "${f#"$base/"}"
                done
        done
        return 0
}

#@help ___answer_hash_add6
# @command answer hash add <stage> <phase> <loader-gate> <name> <hash> <policy-template>
# @summary One sentinel answer class in one batch: the hash is 64 hex digits and the template policy exists; then expectation <name> (string, label <loader-gate>, value <hash> = sha256(salt+word) exactly as the loader publishes loader.trust.<loader-gate>.answer), claim <name> over measure_answer, gate <name> with '-' and '.' as '_', policy <name> with the triggers of the template, and the binding to <phase> of <stage>. Assumes the sentinel of <loader-gate> is bound in the loader (sentinel_act, leafs question/salt/display) and the container of <phase> has measure_answer. Names stay neutral (fish-3, not fish-halt): whoever reads the database must not learn the class from the name
# @group   foundation
# @example elebake answer hash add daily-v1 SYSINIT kernellock fish-3 <sha256 hex> react-halt
# @see     answer add
# @see     answer file add
# @see     answer drop
# @see     answer show
#@end
___answer_hash_add6() {
        local g; g=$(printf '%s' "$4" | tr '.-' '__')
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" answer hash valid '$5'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" policy exists '$6'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" expectation add '$4' string '$3' '$5'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" claim add '$4' measure_answer - - '$4'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate add '$g'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate claim add '$g' '$4'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" policy add '$4' '$g'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" answer triggers copy '$4' '$6'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase policy add '$1' '$2' '$4'"
}

#@help __answer_hash_valid1
# @command answer hash valid <hash>
# @summary The hash is 64 lower-case hex digits, sha256 of salt+word: a comment line, else an error line
# @group   foundation
# @internal
# @see     answer hash add
#@end
__answer_hash_valid1() {
        if printf '%s\n' "$1" | grep -qx '[0-9a-f]\{64\}'; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'hash of 64 hex digits'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'answer hash add: hash must be 64 lower-case hex digits (sha256 of salt+word)'"
        fi
}

#@help ___answer_triggers_copy2
# @command answer triggers copy <policy> <policy-template>
# @summary Every 'trigger <trigger>' line of the template policy: one 'policy trigger add <policy> <trigger>' (the template's gate is ignored); a template without triggers says so in a comment
# @group   foundation
# @internal
# @see     answer hash add
#@end
___answer_triggers_copy2() {
        local kind="" name="" lines=0
        while read -r kind name; do
                [ "$kind" = trigger ] || continue
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" policy trigger add '$1' '$name'"
                lines=$((lines + 1))
        done 2>/dev/null < "$ELEBAKE_BASE/foundation/policies/$2"
        test "$lines" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'template $2 carries no trigger: policy $1 reacts with nothing'"
}

#@help ___answer_add5
# @command answer add <stage> <phase> <loader-gate> <name> <policy-template>
# @summary Add one sentinel answer class with the word read HIDDEN from the terminal when the batch runs -- twice, both must match -- and hashed with the stage's salt (stage kenv add <stage> loader.trust.<loader-gate>.salt <hex>). The word reaches neither argv, trace, history, the batch text nor the generator: the running script leaves only sha256(salt+word) in a file of the database, the next line lifts it into 'answer hash add' and removes the file. Write the word down BEFORE typing it (inventory, paper): the database keeps only the hash
# @group   foundation
# @example elebake answer add daily-v1 SYSINIT kernellock fish-3 react-halt
# @see     answer hash add
# @see     answer file add
#@end
___answer_add5() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" answer salt exists '$1' '$3'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" policy exists '$5'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" answer word hash '$1' '$3' '$4'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" answer hashed add '$1' '$2' '$3' '$4' '$5'"
}

#@help __answer_salt_exists2
# @command answer salt exists <stage> <loader-gate>
# @summary The stage's salt record kenv/loader.trust.<loader-gate>.salt is there: a comment line, else an error line
# @group   foundation
# @internal
# @see     answer add
#@end
__answer_salt_exists2() {
        if test -s "$ELEBAKE_BASE/stage/$1/kenv/loader.trust.$2.salt"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'salt of $2 in stage $1 recorded'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'answer add: no salt -- stage kenv add $1 loader.trust.$2.salt <hex> first'"
        fi
}

#@help _answer_word_hash3
# @command answer word hash <stage> <loader-gate> <name>
# @summary Act terminal: the script that asks for the word twice on /dev/tty with echo off, refuses empty or differing entries, hashes salt+word with sha256 (the salt read from the stage's record by the script) and writes the hash to .tmp/answer/<name> of the database -- the word never leaves the script
# @group   foundation
# @internal
# @see     answer add
#@end
_answer_word_hash3() {
        cat <<EOF
{ : < /dev/tty; } 2>/dev/null || { printf '# Error: %s\\n' 'answer add: needs a terminal to read the word hidden -- use answer hash add' >&2; exit 1; }
printf 'Answer for $3 (hidden): ' > /dev/tty; stty -echo < /dev/tty; IFS= read -r a < /dev/tty; stty echo < /dev/tty; printf '\\n' > /dev/tty
printf 'Again: ' > /dev/tty; stty -echo < /dev/tty; IFS= read -r b < /dev/tty; stty echo < /dev/tty; printf '\\n' > /dev/tty
[ -n "\$a" ] && [ "\$a" = "\$b" ] || { unset a b; printf '# Error: %s\\n' 'answer add: the two entries differ or are empty -- nothing done' >&2; exit 1; }
mkdir -p '$ELEBAKE_BASE/.tmp/answer' && chmod 0700 '$ELEBAKE_BASE/.tmp/answer' && printf '%s%s' "\$(head -1 '$ELEBAKE_BASE/stage/$1/kenv/loader.trust.$2.salt')" "\$a" | sha256 -q > '$ELEBAKE_BASE/.tmp/answer/$3'; unset a b
EOF
}

#@help __answer_hashed_add5
# @command answer hashed add <stage> <phase> <loader-gate> <name> <policy-template>
# @summary The hash file .tmp/answer/<name> the word script left is there: rewrite to 'answer hash add ... <hash> ...' and remove the file, else an error line
# @group   foundation
# @internal
# @see     answer add
#@end
__answer_hashed_add5() {
        local hash=""
        hash=$(sed -n 1p "$ELEBAKE_BASE/.tmp/answer/$4" 2>/dev/null); rm -f "$ELEBAKE_BASE/.tmp/answer/$4"
        if printf '%s\n' "$hash" | grep -qx '[0-9a-f]\{64\}'; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" answer hash add '$1' '$2' '$3' '$4' '$hash' '$5'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'answer add: no hash for $4 (the word script left none)'"
        fi
}

#@help ___answer_drop3
# @command answer drop <stage> <phase> <name>
# @summary Remove one answer class in reverse order: the binding in <phase>, the policy, the gate, the claim, the expectation
# @group   foundation
# @example elebake answer drop daily-v1 SYSINIT fish-3
# @see     answer hash add
#@end
___answer_drop3() {
        local g; g=$(printf '%s' "$3" | tr '.-' '__')
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase policy drop '$1' '$2' '$3'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" policy drop '$3'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate drop '$g'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" claim drop '$3'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" expectation drop '$3'"
}

#@help ___answer_file_add4
# @command answer file add <stage> <phase> <loader-gate> <file>
# @summary Roll out every answer class of a table file, one line per class '<name> <policy-template> <word...>' (the word is the rest of the line, spaces kept; no word = the empty answer; '#' lines and blank lines skipped): the file is readable by its owner only and the salt exists; then per class line 'answer line hash' (the word hashed when the batch runs, into .tmp/answer/<name>) and 'answer hashed add' (the hash lifted into 'answer hash add') -- the words reach only the running script, never argv, trace, the batch text or the generator. The file IS the written place of the words: keep it on a tmpfs while typing, encrypt and print it, then remove it (rm -P)
# @group   foundation
# @example elebake answer file add daily-v1 SYSINIT kernellock /tmp/ram/sentinel-illyria.txt
# @see     answer file drop
# @see     answer line hash
# @see     answer hash add
#@end
___answer_file_add4() {
        local name="" tmpl="" word="" n=0 lines=0
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" answer file private '$4'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" answer salt exists '$1' '$3'"
        while read -r name tmpl word || [ -n "$name" ]; do
                n=$((n + 1))
                [ -n "$name" ] && [ "${name#\#}" = "$name" ] || continue
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" answer line hash '$1' '$3' '$name' '$4' '$n'"
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" answer hashed add '$1' '$2' '$3' '$name' '$tmpl'"
                lines=$((lines + 1))
        done 2>/dev/null < "$4"
        unset word
        test "$lines" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'answer file add: no class lines in $4'"
}

#@help __answer_file_private1
# @command answer file private <file>
# @summary The file is readable and by its owner only (mode ?00): a comment line, else an error line
# @group   foundation
# @internal
# @see     answer file add
#@end
__answer_file_private1() {
        if test -r "$1" && stat -f %Lp "$1" | grep -qx ".00"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'table $1 readable by its owner only'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'answer file add: $1 must be readable by its owner only (chmod 0600)'"
        fi
}

#@help _answer_line_hash5
# @command answer line hash <stage> <loader-gate> <name> <file> <line>
# @summary Act terminal: the script that takes the word from line <line> of the table (the rest after name and template, spaces kept), hashes salt+word with sha256 and writes the hash to .tmp/answer/<name> of the database; the word stays in the running script
# @group   foundation
# @internal
# @see     answer file add
#@end
_answer_line_hash5() {
        cat <<EOF
mkdir -p '$ELEBAKE_BASE/.tmp/answer' && chmod 0700 '$ELEBAKE_BASE/.tmp/answer' && printf '%s%s' "\$(head -1 '$ELEBAKE_BASE/stage/$1/kenv/loader.trust.$2.salt')" "\$(sed -n '$5p' '$4' | sed 's/^[[:space:]]*[^[:space:]]*[[:space:]]*[^[:space:]]*[[:space:]]*//')" | sha256 -q > '$ELEBAKE_BASE/.tmp/answer/$3'
EOF
}

#@help ___answer_file_drop3
# @command answer file drop <stage> <phase> <file>
# @summary Remove every answer class named in a table file (first field of each class line; the words are not read): one 'answer drop' per line
# @group   foundation
# @example elebake answer file drop daily-v1 SYSINIT /tmp/ram/sentinel-illyria.txt
# @see     answer file add
#@end
___answer_file_drop3() {
        local name="" rest="" lines=0
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" answer file private '$3'"
        while read -r name rest || [ -n "$name" ]; do
                [ -n "$name" ] && [ "${name#\#}" = "$name" ] || continue
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" answer drop '$1' '$2' '$name'"
                lines=$((lines + 1))
        done 2>/dev/null < "$3"
        test "$lines" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'answer file drop: no class lines in $3'"
}

#@help ___answer_catchall_add5
# @command answer catchall add <stage> <phase> <loader-gate> <name> <policy-template>
# @summary The catch-all answer class: expectation <name> (byte, label <loader-gate>, 1), claim over measure_answer_matched, gate, policy with the triggers of the template -- a when_fail template (react-miss: spool-fail, shutdown-fail) -- and the binding. It fails whenever no word class matched: empty and wrong alike. Bind it AFTER the word classes (the phase runs in binding order; a class added later must be followed by 'answer drop' + re-add of the catch-all), and give every class template the trigger for answer_matched_act
# @group   foundation
# @example elebake answer catchall add daily-v1 SYSINIT kernellock fish-any react-miss
# @see     answer hash add
# @see     answer show
#@end
___answer_catchall_add5() {
        local g; g=$(printf '%s' "$4" | tr '.-' '__')
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" policy exists '$5'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" expectation add '$4' byte '$3' 1"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" claim add '$4' measure_answer_matched - - '$4'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate add '$g'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate claim add '$g' '$4'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" policy add '$4' '$g'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" answer triggers copy '$4' '$5'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase policy add '$1' '$2' '$4'"
}

#@help ___answer_show1
# @command answer show <stage>
# @summary List the answer classes seen from the stage, in policy order: every policy whose gate's first claim measures measure_answer (a word class) or measure_answer_matched (the catch-all) -- name, the phase of <stage> that binds it or 'unbound', its triggers. The words are not here and never were: the inventory has them
# @group   foundation
# @example elebake answer show daily-v1
# @see     answer hash add
#@end
___answer_show1() {
        local p=""
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log 'answer classes seen from stage $1 (policy, bound phase, triggers)'"
        for p in "$ELEBAKE_BASE"/foundation/policies/*; do
                [ -f "$p" ] || continue
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" answer policy show '$1' '${p##*/}'"
        done
}

#@help __answer_policy_show2
# @command answer policy show <stage> <policy>
# @summary The measurement of the first claim of the policy's gate decides (lifting): rewrite to 'answer class show <measurement> <stage> <policy>' -- measure_answer and measure_answer_matched have their own anchor, every other measurement falls back to a comment
# @group   foundation
# @internal
# @see     answer class show
#@end
__answer_policy_show2() {
        local gate="" claim="" measurement="" rest=""
        gate=$(sed -n 's/^gate //p' "$ELEBAKE_BASE/foundation/policies/$2" 2>/dev/null)
        claim=$(sed -n 1p "$ELEBAKE_BASE/foundation/gates/$gate/claims" 2>/dev/null)
        read -r measurement rest 2>/dev/null < "$ELEBAKE_BASE/foundation/claims/$claim"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" answer class show '${measurement:-none}' '$1' '$2'"
}

#@help __answer_class_show3
# @command answer class show <measurement> <stage> <policy>
# @summary The total fallback behind the answer measurements (dispatch binds the longer name): a policy over any other measurement is no answer class, a comment line
# @group   foundation
# @internal
# @see     answer show
#@end
__answer_class_show3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'policy $3 measures $1: not an answer class'"
}

#@help __answer_class_show_measure_answer2
# @command answer class show measure_answer <stage> <policy>
# @summary One answer class: a note with the policy, the phase of the stage that binds it (or unbound) and its triggers
# @group   foundation
# @internal
# @see     answer show
#@end
__answer_class_show_measure_answer2() {
        local bound="" trig="" line=""
        bound=$(grep -lx "$2" "$ELEBAKE_BASE/stage/$1/phases"/* 2>/dev/null | sed 's|.*/||' | tr '\n' ' ')
        trig=$(sed -n 's/^trigger //p' "$ELEBAKE_BASE/foundation/policies/$2" 2>/dev/null | tr '\n' ' '); trig=${trig% }
        line=$(printf '%-14s %-10s %s' "$2" "${bound:-unbound}" "${trig:-(no triggers)}")
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log $(sq "$line")"
}

#@help __answer_class_show_measure_answer_matched2
# @command answer class show measure_answer_matched <stage> <policy>
# @summary One answer class -- the catch-all: a note with the policy, the phase of the stage that binds it (or unbound) and its triggers
# @group   foundation
# @internal
# @see     answer show
#@end
__answer_class_show_measure_answer_matched2() {
        local bound="" trig="" line=""
        bound=$(grep -lx "$2" "$ELEBAKE_BASE/stage/$1/phases"/* 2>/dev/null | sed 's|.*/||' | tr '\n' ' ')
        trig=$(sed -n 's/^trigger //p' "$ELEBAKE_BASE/foundation/policies/$2" 2>/dev/null | tr '\n' ' '); trig=${trig% }
        line=$(printf '%-14s %-10s %s' "$2" "${bound:-unbound}" "${trig:-(no triggers)} (catch-all)")
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log $(sq "$line")"
}

