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
# policy add'); a reference MAY dangle at definition time — add just
# stores, the sharp checks live at the BINDING (stage check policy) and
# before emission (stage foundation check). CRUD is dumb: name syntax,
# and add is IDEMPOTENT-IMMUTABLE — re-adding the identical record is a
# silent no-op (dump replays), re-adding a DIFFERENT record under the
# same name is refused (a name's meaning never shifts under its users;
# change = drop + add). Drop is free — dangling is verify's business.
# 'show' always renders the C that WOULD be emitted.
#
# ARCHITECTURE: TERMINALS — emit ONLY shell / display text.

# fnd_name_ok <name> — generation-time: valid record name?
fnd_name_ok() {
  case "$1" in
    ""|.|..|*[!A-Za-z0-9_.-]*) return 1 ;;
  esac
  return 0
}

# fnd_c_ident_ok <name> — generation-time: names that land in the C output
# (gates) must be C identifiers
fnd_c_ident_ok() {
  case "$1" in
    ""|[0-9]*|*[!A-Za-z0-9_]*) return 1 ;;
  esac
  return 0
}

# fnd_fields_ok <field>... — generation-time: fields land single-quoted in
# emitted shell and space-joined in record files; refuse what would break
# that (quotes; embedded newlines cannot survive "$*" anyway).
fnd_fields_ok() {
  case "$*" in
    *"'"*) return 1 ;;
  esac
  return 0
}

# fnd_record_line <file> — first line of a record file (its full content)
fnd_record_line() {
  head -1 "$1"
}

#-----------------------------------------------------------------------------
# render helpers (generation time; shared by show and the emitters)
#-----------------------------------------------------------------------------

# fnd_render_expectation <base> <name> — echo the C form (or a marker)
fnd_render_expectation() {
  local f="$1/foundation/expectations/$2" type label value
  [ -f "$f" ] || { printf '/* undefined expectation: %s */' "$2"; return 0; }
  read -r type label value < "$f"
  if [ "$type" = "macro" ]; then
    printf '%s' "$value"
  else
    printf 'MEASUREMENT_%s("%s", %s)' "$(printf '%s' "$type" | tr '[:lower:]' '[:upper:]')" "$label" "$value"
  fi
}

# fnd_render_claim <base> <name> — echo the C form (expectation expanded)
fnd_render_claim() {
  local f="$1/foundation/claims/$2" measurement diagnose publish exp
  [ -f "$f" ] || { printf '/* undefined claim: %s */' "$2"; return 0; }
  read -r measurement diagnose publish exp < "$f"
  [ "$diagnose" = "-" ] && diagnose=NULL
  if [ "$publish" = "-" ]; then publish=NULL; else publish="\"$publish\""; fi
  printf 'CLAIM(%s, %s, %s, %s)' "$measurement" "$diagnose" "$publish" "$(fnd_render_expectation "$1" "$exp")"
}

# fnd_render_trigger <base> <name>
fnd_render_trigger() {
  local f="$1/foundation/triggers/$2" when action
  [ -f "$f" ] || { printf '/* undefined trigger: %s */' "$2"; return 0; }
  read -r when action < "$f"
  printf 'FIRE(%s, &%s)' "$when" "$action"
}

# fnd_render_gate <base> <name> — echo GATE_DEFINE (claims expanded).
# The secret expression is the same LOCAL macro the C emission uses
# (show renders what emission WOULD produce — never the raw slot).
fnd_render_gate() {
  local base="$1" name="$2" c
  printf 'GATE_DEFINE(%s, %s' "$name" "$(fnd_gate_secret_expr "$base" "$name")"
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    printf ',\n#     %s' "$(fnd_render_claim "$base" "$c")"
  done < "$base/foundation/gates/$name/claims"
  printf ');'
}

# fnd_render_policy <base> <name>
fnd_render_policy() {
  local base="$1" name="$2" gate line
  gate=$(sed -n 's/^gate //p' "$base/foundation/policies/$name" | head -1)
  printf 'POLICY(%s' "$gate"
  sed -n 's/^trigger //p' "$base/foundation/policies/$name" | while IFS= read -r line; do
    printf ',\n#     %s' "$(fnd_render_trigger "$base" "$line")"
  done
  printf '),'
}

# fnd_macro_name_ok <NAME> — generation-time: valid C macro stem?
fnd_macro_name_ok() {
  case "$1" in
    ""|*[!A-Z0-9_]*|[0-9]*) return 1 ;;
  esac
  return 0
}

# fnd_macro_defined <NAME> — the DEFINED macro name a macro record produces
# (BOARD_DIGEST -> BOARD_EXPECTED; no _DIGEST suffix -> append _EXPECTED)
fnd_macro_defined() {
  case "$1" in
    *_DIGEST) printf '%s_EXPECTED\n' "${1%_DIGEST}" ;;
    *)        printf '%s_EXPECTED\n' "$1" ;;
  esac
}

# fnd_render_macro <base> <NAME> — the full #ifdef baseline block: guard is
# LOADER_TRUST_<NAME> (the site.mk -D convention); the defined name and the
# #else alternative come from the record ('-' selects the derivations:
# fnd_macro_defined, MEASUREMENT_NONE of the type).
fnd_render_macro() {
  local f="$1/foundation/macros/$2" type label defined elsev guard TYPE
  [ -f "$f" ] || { printf '/* undefined macro: %s */\n' "$2"; return 0; }
  read -r type label defined elsev < "$f"
  guard="LOADER_TRUST_$2"
  TYPE=$(printf '%s' "$type" | tr '[:lower:]' '[:upper:]')
  [ "${defined:--}" = "-" ] && defined=$(fnd_macro_defined "$2")
  [ "${elsev:--}" = "-" ] && elsev="MEASUREMENT_NONE(\"$label\", MEAS_$TYPE)"
  printf '#ifdef %s\n' "$guard"
  printf '#define\t%s\tMEASUREMENT_%s("%s", %s)\n' "$defined" "$TYPE" "$label" "$guard"
  printf '#else\n'
  printf '#define\t%s\t%s\n' "$defined" "$elsev"
  printf '#endif\n'
}

# fnd_macro_record_for <base> <defined-name> — which macro record produces
# this defined name? (empty when none does)
fnd_macro_record_for() {
  local base="$1" want="$2" f n type label defined elsev
  for f in "$base"/foundation/macros/*; do
    [ -f "$f" ] || continue
    n=$(basename "$f")
    read -r type label defined elsev < "$f"
    [ "${defined:--}" = "-" ] && defined=$(fnd_macro_defined "$n")
    [ "$defined" = "$want" ] && { printf '%s\n' "$n"; return 0; }
  done
  return 1
}

#-----------------------------------------------------------------------------
# macro (build-provided baseline slot)
#-----------------------------------------------------------------------------
#@help _macro_add3
# @command macro add <MACRO> <type> <label> [<else>] [<defined>]
# @summary Store a build-provided baseline slot: site.mk may deliver -DLOADER_TRUST_<MACRO>, absent selects the #else alternative (identical re-add is a no-op)
# @group   foundation
# @param   type    sha256 | byte (maps to MEASUREMENT_<TYPE>)
# @param   else    the #else alternative as a verbatim C expression; omitted or '-': MEASUREMENT_NONE("<label>", MEAS_<TYPE>) — the claim skips when unprovisioned
# @param   defined the defined macro name; omitted or '-': <MACRO> with _DIGEST replaced by _EXPECTED (else _EXPECTED appended). NOTE: arity order is <else> before <defined>
# @example elebake macro add BOARD_DIGEST sha256 BoardIdentity
# @example elebake macro add BOARD_DIGEST sha256 BoardIdentity 'MEASUREMENT_BYTE("BoardIdentity", 0)' BOARD_BASELINE
# @see     macro show
# @see     expectation add
#@end
_macro_add3() { _macro_add5 "$1" "$2" "$3" "-" "-"; }

#@help _macro_add4
# @internal 4-arg sibling of 'macro add': explicit #else alternative
# (verbatim C expression; '-' selects the MEASUREMENT_NONE derivation)
#@end
_macro_add4() { _macro_add5 "$1" "$2" "$3" "$4" "-"; }

#@help _macro_add5
# @internal 5-arg sibling of 'macro add': explicit defined name AND #else
# alternative ('-' selects the derivation for either). The dump replays
# this canonical form.
#@end
_macro_add5() {
  local name="$1" type="$2" label="$3" elsev="$4" defined="$5" base="$ELEBAKE_BASE" line
  fnd_macro_name_ok "$name" || {
    generate_error "macro add: invalid macro name '$name' (C macro stem: A-Z, 0-9, _)"; return 0; }
  [ "$defined" = "-" ] || fnd_macro_name_ok "$defined" || {
    generate_error "macro add: invalid defined name '$defined' (C macro name required)"; return 0; }
  fnd_fields_ok "$type" "$label" "$defined" "$elsev" || {
    generate_error "macro add: fields must not contain single quotes"; return 0; }
  line="$type $label $defined $elsev"
  if [ -f "$base/foundation/macros/$name" ]; then
    if [ "$(fnd_record_line "$base/foundation/macros/$name")" = "$line" ]; then
      emit_note "macro '$name' already stored (unchanged)"; return 0
    fi
    generate_error "macro add: '$name' exists with different content (immutable; drop first)"; return 0
  fi
  printf '%s\n' "printf '%s\\n' '$line' > '$base/foundation/macros/$name'"
  printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$base/foundation/macros/$name'"
  emit_note "macro '$name' stored"
}

#@help _macro_drop1
# @command macro drop <MACRO>
# @summary Remove a macro record (free; dangling expectation references are verify's business)
# @group   foundation
#@end
_macro_drop1() {
  local name="$1" base="$ELEBAKE_BASE"
  [ -f "$base/foundation/macros/$name" ] || {
    generate_error "macro drop: no such macro '$name'"; return 0; }
  printf '%s\n' "$MODIFY_FILE_REMOVE '$base/foundation/macros/$name'"
  emit_note "macro '$name' dropped"
}

#@help _macro_show0
# @command macro show [<MACRO>]
# @summary Show all macro records (or one) as the #ifdef block that WOULD be emitted
# @group   foundation
#@end
_macro_show0() {
  local base="$ELEBAKE_BASE" f n=0
  for f in "$base"/foundation/macros/*; do
    [ -f "$f" ] || continue; n=$((n+1))
    printf '# %s:\n' "$(basename "$f")"
    fnd_render_macro "$base" "$(basename "$f")" | sed 's/^/#   /'
  done
  [ "$n" -gt 0 ] || printf '# (no macros -- macro add <MACRO> <type> <label>)\n'
}

#@help _macro_show1
# @internal one macro record in detail
#@end
_macro_show1() {
  local base="$ELEBAKE_BASE"
  [ -f "$base/foundation/macros/$1" ] || {
    generate_error "macro show: no such macro '$1'"; return 0; }
  printf '# %s:\n' "$1"
  fnd_render_macro "$base" "$1" | sed 's/^/#   /'
}

#-----------------------------------------------------------------------------
# expectation
#-----------------------------------------------------------------------------
#@help _expectation_add4
# @command expectation add <exp> <type> <label> <value>
# @summary Store a named, reusable measured-value expectation (DB-wide arsenal; identical re-add is a no-op, a differing one is refused)
# @group   foundation
# @param   type   byte | sha256 | string | macro (macro: <value> is a bare C macro, <label> is '-')
# @example elebake expectation add strict-active byte StrictActive 1
# @see     claim add
#@end
_expectation_add4() {
  local name="$1" type="$2" label="$3" value="$4" base="$ELEBAKE_BASE" line
  fnd_name_ok "$name" || { generate_error "expectation add: invalid name '$name'"; return 0; }
  fnd_fields_ok "$type" "$label" "$value" || {
    generate_error "expectation add: fields must not contain single quotes"; return 0; }
  line="$type $label $value"
  if [ -f "$base/foundation/expectations/$name" ]; then
    if [ "$(fnd_record_line "$base/foundation/expectations/$name")" = "$line" ]; then
      emit_note "expectation '$name' already stored (unchanged)"; return 0
    fi
    generate_error "expectation add: '$name' exists with different content (immutable; drop first)"; return 0
  fi
  printf '%s\n' "printf '%s\\n' '$line' > '$base/foundation/expectations/$name'"
  printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$base/foundation/expectations/$name'"
  emit_note "expectation '$name' stored"
}

#@help _expectation_drop1
# @command expectation drop <exp>
# @summary Remove an expectation (free; dangling references are verify's business)
# @group   foundation
#@end
_expectation_drop1() {
  local name="$1" base="$ELEBAKE_BASE"
  [ -f "$base/foundation/expectations/$name" ] || {
    generate_error "expectation drop: no such expectation '$name'"; return 0; }
  printf '%s\n' "$MODIFY_FILE_REMOVE '$base/foundation/expectations/$name'"
  emit_note "expectation '$name' dropped"
}

#@help _expectation_show0
# @command expectation show [<exp>]
# @summary Show all expectations (or one) as the C that WOULD be emitted
# @group   foundation
#@end
_expectation_show0() {
  local base="$ELEBAKE_BASE" f n=0
  for f in "$base"/foundation/expectations/*; do
    [ -f "$f" ] || continue; n=$((n+1))
    printf '# %s: %s\n' "$(basename "$f")" "$(fnd_render_expectation "$base" "$(basename "$f")")"
  done
  [ "$n" -gt 0 ] || printf '# (no expectations -- expectation add <exp> <type> <label> <value>)\n'
}

#@help _expectation_show1
# @internal one expectation in detail
#@end
_expectation_show1() {
  local base="$ELEBAKE_BASE"
  [ -f "$base/foundation/expectations/$1" ] || {
    generate_error "expectation show: no such expectation '$1'"; return 0; }
  printf '# %s: %s\n' "$1" "$(fnd_render_expectation "$base" "$1")"
}

#-----------------------------------------------------------------------------
# claim
#-----------------------------------------------------------------------------
#@help _claim_add5
# @command claim add <claim> <measurement> <diagnose|-> <publish|-> <exp>
# @summary Store a named, reusable claim referencing an expectation (may dangle until bound; identical re-add is a no-op)
# @group   foundation
# @example elebake claim add strict-active measure_strict - strict.active strict-active
# @see     gate claim add
#@end
_claim_add5() {
  local name="$1" base="$ELEBAKE_BASE" line
  fnd_name_ok "$name" || { generate_error "claim add: invalid name '$name'"; return 0; }
  fnd_fields_ok "$2" "$3" "$4" "$5" || {
    generate_error "claim add: fields must not contain single quotes"; return 0; }
  fnd_name_ok "$5" || { generate_error "claim add: invalid expectation name '$5'"; return 0; }
  line="$2 $3 $4 $5"
  if [ -f "$base/foundation/claims/$name" ]; then
    if [ "$(fnd_record_line "$base/foundation/claims/$name")" = "$line" ]; then
      emit_note "claim '$name' already stored (unchanged)"; return 0
    fi
    generate_error "claim add: '$name' exists with different content (immutable; drop first)"; return 0
  fi
  printf '%s\n' "printf '%s\\n' '$line' > '$base/foundation/claims/$name'"
  printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$base/foundation/claims/$name'"
  emit_note "claim '$name' stored"
}

#@help _claim_drop1
# @command claim drop <claim>
# @summary Remove a claim (free; dangling gate references are verify's business)
# @group   foundation
#@end
_claim_drop1() {
  local name="$1" base="$ELEBAKE_BASE"
  [ -f "$base/foundation/claims/$name" ] || {
    generate_error "claim drop: no such claim '$name'"; return 0; }
  printf '%s\n' "$MODIFY_FILE_REMOVE '$base/foundation/claims/$name'"
  emit_note "claim '$name' dropped"
}

#@help _claim_show0
# @command claim show [<claim>]
# @summary Show all claims (or one) as the C that WOULD be emitted
# @group   foundation
#@end
_claim_show0() {
  local base="$ELEBAKE_BASE" f n=0
  for f in "$base"/foundation/claims/*; do
    [ -f "$f" ] || continue; n=$((n+1))
    printf '# %s: %s\n' "$(basename "$f")" "$(fnd_render_claim "$base" "$(basename "$f")")"
  done
  [ "$n" -gt 0 ] || printf '# (no claims -- claim add <claim> <measurement> <diagnose|-> <publish|-> <exp>)\n'
}

#@help _claim_show1
# @internal one claim in detail
#@end
_claim_show1() {
  local base="$ELEBAKE_BASE"
  [ -f "$base/foundation/claims/$1" ] || {
    generate_error "claim show: no such claim '$1'"; return 0; }
  printf '# %s: %s\n' "$1" "$(fnd_render_claim "$base" "$1")"
}

#-----------------------------------------------------------------------------
# trigger
#-----------------------------------------------------------------------------
#@help _trigger_add3
# @command trigger add <trigger> <when> <action>
# @summary Store a named, reusable FIRE(<when>, &<action>) pair (identical re-add is a no-op)
# @group   foundation
# @example elebake trigger add publish-always when_always publish_act
# @see     policy trigger add
#@end
_trigger_add3() {
  local name="$1" base="$ELEBAKE_BASE" line
  fnd_name_ok "$name" || { generate_error "trigger add: invalid name '$name'"; return 0; }
  fnd_fields_ok "$2" "$3" || {
    generate_error "trigger add: fields must not contain single quotes"; return 0; }
  line="$2 $3"
  if [ -f "$base/foundation/triggers/$name" ]; then
    if [ "$(fnd_record_line "$base/foundation/triggers/$name")" = "$line" ]; then
      emit_note "trigger '$name' already stored (unchanged)"; return 0
    fi
    generate_error "trigger add: '$name' exists with different content (immutable; drop first)"; return 0
  fi
  printf '%s\n' "printf '%s\\n' '$line' > '$base/foundation/triggers/$name'"
  printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$base/foundation/triggers/$name'"
  emit_note "trigger '$name' stored"
}

#@help _trigger_drop1
# @command trigger drop <trigger>
# @summary Remove a trigger (free; dangling policy references are verify's business)
# @group   foundation
#@end
_trigger_drop1() {
  local name="$1" base="$ELEBAKE_BASE"
  [ -f "$base/foundation/triggers/$name" ] || {
    generate_error "trigger drop: no such trigger '$name'"; return 0; }
  printf '%s\n' "$MODIFY_FILE_REMOVE '$base/foundation/triggers/$name'"
  emit_note "trigger '$name' dropped"
}

#@help _trigger_show0
# @command trigger show [<trigger>]
# @summary Show all triggers (or one) as the C that WOULD be emitted
# @group   foundation
#@end
_trigger_show0() {
  local base="$ELEBAKE_BASE" f n=0
  for f in "$base"/foundation/triggers/*; do
    [ -f "$f" ] || continue; n=$((n+1))
    printf '# %s: %s\n' "$(basename "$f")" "$(fnd_render_trigger "$base" "$(basename "$f")")"
  done
  [ "$n" -gt 0 ] || printf '# (no triggers -- trigger add <trigger> <when> <action>)\n'
}

#@help _trigger_show1
# @internal one trigger in detail
#@end
_trigger_show1() {
  local base="$ELEBAKE_BASE"
  [ -f "$base/foundation/triggers/$1" ] || {
    generate_error "trigger show: no such trigger '$1'"; return 0; }
  printf '# %s: %s\n' "$1" "$(fnd_render_trigger "$base" "$1")"
}

#-----------------------------------------------------------------------------
# gate (dir record: optional secret SLOT NAME + ordered claims list)
#-----------------------------------------------------------------------------
#@help _gate_add2
# @command gate add <gate> [<secret-slot>]
# @summary Create a gate record (secret-slot NAMES the -D macro, never a value; identical re-add is a no-op)
# @group   foundation
# @example elebake gate add bootlock LOADER_TRUST_BOOTLOCK_SECRET
# @see     gate claim add
#@end
_gate_add2() {
  local name="$1" secret="${2:-}" base="$ELEBAKE_BASE" have=""
  fnd_c_ident_ok "$name" || {
    generate_error "gate add: invalid name '$name' (gates land in the C output: C identifier required)"; return 0; }
  fnd_fields_ok "$secret" || {
    generate_error "gate add: secret slot must not contain single quotes"; return 0; }
  if [ -d "$base/foundation/gates/$name" ]; then
    [ -f "$base/foundation/gates/$name/secret" ] && have=$(fnd_record_line "$base/foundation/gates/$name/secret")
    if [ "$have" = "$secret" ]; then
      emit_note "gate '$name' already created (unchanged; claims list untouched)"; return 0
    fi
    generate_error "gate add: '$name' exists with different secret slot (immutable; drop first)"; return 0
  fi
  printf '%s\n' "$MODIFY_DIR_CREATE '$base/foundation/gates/$name'"
  printf '%s\n' "$MODIFY_FILE_PERMS 0700 '$base/foundation/gates/$name'"
  if [ -n "$secret" ]; then
    printf '%s\n' "printf '%s\\n' '$secret' > '$base/foundation/gates/$name/secret'"
    printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$base/foundation/gates/$name/secret'"
  fi
  printf '%s\n' ": > '$base/foundation/gates/$name/claims'"
  printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$base/foundation/gates/$name/claims'"
  emit_note "gate '$name' created"
}

#@help _gate_add1
# @internal 1-arg sibling of 'gate add' (no secret slot)
#@end
_gate_add1() { _gate_add2 "$1" ""; }

#@help _gate_drop1
# @command gate drop <gate>
# @summary Remove a gate record (free; dangling policy references are verify's business)
# @group   foundation
#@end
_gate_drop1() {
  local name="$1" base="$ELEBAKE_BASE"
  [ -d "$base/foundation/gates/$name" ] || {
    generate_error "gate drop: no such gate '$name'"; return 0; }
  printf '%s\n' "rm -rf '$base/foundation/gates/$name'"
  emit_note "gate '$name' dropped"
}

#@help _gate_claim_add2
# @command gate claim add <gate> <claim> [<position>]
# @summary Append a claim reference to a gate (order = evaluation order; may dangle; 3-arg form inserts at a 1-based position)
# @group   foundation
# @example elebake gate claim add strictwatch strict-active
#@end
_gate_claim_add2() {
  local gate="$1" claim="$2" base="$ELEBAKE_BASE"
  [ -d "$base/foundation/gates/$gate" ] || {
    generate_error "gate claim add: no such gate '$gate' (gate add first)"; return 0; }
  fnd_name_ok "$claim" || { generate_error "gate claim add: invalid claim name '$claim'"; return 0; }
  printf '%s\n' "grep -qxF '$claim' '$base/foundation/gates/$gate/claims' 2>/dev/null || printf '%s\\n' '$claim' >> '$base/foundation/gates/$gate/claims'"
  emit_note "gate '$gate': claim '$claim' appended"
}

#@help _gate_claim_add3
# @internal 3-arg sibling of 'gate claim add': insert at a 1-based position
# (default form appends). Position and duplicate are validated at generation
# time; reordering is drop + add-at-position.
#@end
_gate_claim_add3() {
  local gate="$1" claim="$2" pos="$3" base="$ELEBAKE_BASE" f n
  [ -d "$base/foundation/gates/$gate" ] || {
    generate_error "gate claim add: no such gate '$gate' (gate add first)"; return 0; }
  fnd_name_ok "$claim" || { generate_error "gate claim add: invalid claim name '$claim'"; return 0; }
  f="$base/foundation/gates/$gate/claims"
  grep -qxF "$claim" "$f" 2>/dev/null && {
    generate_error "gate claim add: '$claim' already referenced by '$gate' (position is placement, not a move — drop first)"; return 0; }
  n=$(grep -c '' "$f" 2>/dev/null || true)
  [ -n "$n" ] || n=0
  line_pos_ok "$pos" "$n" || {
    generate_error "gate claim add: position '$pos' out of range (1..$((n + 1)))"; return 0; }
  line_insert_emit "$f" "$pos" "$claim"
  emit_note "gate '$gate': claim '$claim' inserted at $pos"
}

#@help _gate_claim_drop2
# @command gate claim drop <gate> <claim>
# @summary Unlink a claim reference from a gate (the claim itself survives)
# @group   foundation
#@end
_gate_claim_drop2() {
  local gate="$1" claim="$2" base="$ELEBAKE_BASE"
  [ -d "$base/foundation/gates/$gate" ] || {
    generate_error "gate claim drop: no such gate '$gate'"; return 0; }
  grep -qxF "$claim" "$base/foundation/gates/$gate/claims" 2>/dev/null || {
    generate_error "gate claim drop: '$claim' not referenced by '$gate'"; return 0; }
  printf '%s\n' "grep -vxF '$claim' '$base/foundation/gates/$gate/claims' > '$base/foundation/gates/$gate/claims.new'; mv '$base/foundation/gates/$gate/claims.new' '$base/foundation/gates/$gate/claims'"
  emit_note "gate '$gate': claim '$claim' unlinked"
}

#@help _gate_show0
# @command gate show [<gate>]
# @summary Show all gates (or one) as the C that WOULD be emitted
# @group   foundation
#@end
_gate_show0() {
  local base="$ELEBAKE_BASE" g n=0
  for g in "$base"/foundation/gates/*/; do
    [ -d "$g" ] || continue; n=$((n+1))
    printf '# %s\n' "$(fnd_render_gate "$base" "$(basename "$g")")"
  done
  [ "$n" -gt 0 ] || printf '# (no gates -- gate add <gate> [<secret-slot>])\n'
}

#@help _gate_show1
# @internal one gate in detail
#@end
_gate_show1() {
  local base="$ELEBAKE_BASE"
  [ -d "$base/foundation/gates/$1" ] || {
    generate_error "gate show: no such gate '$1'"; return 0; }
  printf '# %s\n' "$(fnd_render_gate "$base" "$1")"
}

#-----------------------------------------------------------------------------
# policy (gate reference + ordered trigger list)
#-----------------------------------------------------------------------------
#@help _policy_add2
# @command policy add <policy> <gate>
# @summary Create a named policy for a gate (triggers appended separately; may dangle; identical re-add is a no-op)
# @group   foundation
# @example elebake policy add watch-strict strictwatch
# @see     policy trigger add
#@end
_policy_add2() {
  local name="$1" gate="$2" base="$ELEBAKE_BASE"
  fnd_name_ok "$name" || { generate_error "policy add: invalid name '$name'"; return 0; }
  fnd_name_ok "$gate" || { generate_error "policy add: invalid gate name '$gate'"; return 0; }
  if [ -f "$base/foundation/policies/$name" ]; then
    if [ "$(sed -n 's/^gate //p' "$base/foundation/policies/$name" | head -1)" = "$gate" ]; then
      emit_note "policy '$name' already created (unchanged; trigger list untouched)"; return 0
    fi
    generate_error "policy add: '$name' exists for a different gate (immutable; drop first)"; return 0
  fi
  printf '%s\n' "printf 'gate %s\\n' '$gate' > '$base/foundation/policies/$name'"
  printf '%s\n' "$MODIFY_FILE_PERMS 0600 '$base/foundation/policies/$name'"
  emit_note "policy '$name' created (gate $gate)"
}

#@help _policy_trigger_add2
# @command policy trigger add <policy> <trigger> [<position>]
# @summary Append a trigger (FIRE) reference to a policy; 3-arg form inserts at a 1-based position
# @group   foundation
#@end
_policy_trigger_add2() {
  local name="$1" trigger="$2" base="$ELEBAKE_BASE"
  [ -f "$base/foundation/policies/$name" ] || {
    generate_error "policy trigger add: no such policy '$name' (policy add first)"; return 0; }
  fnd_name_ok "$trigger" || { generate_error "policy trigger add: invalid trigger name '$trigger'"; return 0; }
  printf '%s\n' "grep -qxF 'trigger $trigger' '$base/foundation/policies/$name' || printf 'trigger %s\\n' '$trigger' >> '$base/foundation/policies/$name'"
  emit_note "policy '$name': trigger '$trigger' appended"
}

#@help _policy_trigger_add3
# @internal 3-arg sibling of 'policy trigger add': insert at a 1-based
# position AMONG THE TRIGGER LINES (the gate line stays first). Position and
# duplicate are validated at generation time.
#@end
_policy_trigger_add3() {
  local name="$1" trigger="$2" pos="$3" base="$ELEBAKE_BASE" f n
  [ -f "$base/foundation/policies/$name" ] || {
    generate_error "policy trigger add: no such policy '$name' (policy add first)"; return 0; }
  fnd_name_ok "$trigger" || { generate_error "policy trigger add: invalid trigger name '$trigger'"; return 0; }
  f="$base/foundation/policies/$name"
  grep -qxF "trigger $trigger" "$f" && {
    generate_error "policy trigger add: '$trigger' already in '$name' (position is placement, not a move — drop first)"; return 0; }
  n=$(grep -c '^trigger ' "$f" || true)
  line_pos_ok "$pos" "$n" || {
    generate_error "policy trigger add: position '$pos' out of range (1..$((n + 1)))"; return 0; }
  # trigger position p = file line p+1 (line 1 is the gate line)
  line_insert_emit "$f" "$((pos + 1))" "trigger $trigger"
  emit_note "policy '$name': trigger '$trigger' inserted at $pos"
}

#@help _policy_trigger_drop2
# @command policy trigger drop <policy> <trigger>
# @summary Remove a trigger reference from a policy (the trigger itself survives)
# @group   foundation
#@end
_policy_trigger_drop2() {
  local name="$1" trigger="$2" base="$ELEBAKE_BASE"
  [ -f "$base/foundation/policies/$name" ] || {
    generate_error "policy trigger drop: no such policy '$name'"; return 0; }
  grep -qxF "trigger $trigger" "$base/foundation/policies/$name" || {
    generate_error "policy trigger drop: '$trigger' not in '$name'"; return 0; }
  printf '%s\n' "grep -vxF 'trigger $trigger' '$base/foundation/policies/$name' > '$base/foundation/policies/$name.new'; mv '$base/foundation/policies/$name.new' '$base/foundation/policies/$name'"
  emit_note "policy '$name': trigger '$trigger' removed"
}

#@help _policy_drop1
# @command policy drop <policy>
# @summary Remove a policy (free; dangling phase references are verify's business)
# @group   foundation
#@end
_policy_drop1() {
  local name="$1" base="$ELEBAKE_BASE"
  [ -f "$base/foundation/policies/$name" ] || {
    generate_error "policy drop: no such policy '$name'"; return 0; }
  printf '%s\n' "$MODIFY_FILE_REMOVE '$base/foundation/policies/$name'"
  emit_note "policy '$name' dropped"
}

#@help _policy_show0
# @command policy show [<policy>]
# @summary Show all policies (or one) as the C that WOULD be emitted
# @group   foundation
#@end
_policy_show0() {
  local base="$ELEBAKE_BASE" f n=0
  for f in "$base"/foundation/policies/*; do
    [ -f "$f" ] || continue; n=$((n+1))
    printf '# %s: %s\n' "$(basename "$f")" "$(fnd_render_policy "$base" "$(basename "$f")")"
  done
  [ "$n" -gt 0 ] || printf '# (no policies -- policy add <policy> <gate>)\n'
}

#@help _policy_show1
# @internal one policy in detail
#@end
_policy_show1() {
  local base="$ELEBAKE_BASE"
  [ -f "$base/foundation/policies/$1" ] || {
    generate_error "policy show: no such policy '$1'"; return 0; }
  printf '# %s: %s\n' "$1" "$(fnd_render_policy "$base" "$1")"
}

#-----------------------------------------------------------------------------
# C renderers — the real file layout (used by 'stage foundation make';
# the show families above render the same content in display form)
#-----------------------------------------------------------------------------

# fnd_gate_secret_expr <base> <gate> — the C expression for the gate's
# secret: the LOCAL macro (slot minus LOADER_TRUST_) when a slot is
# recorded, NULL otherwise
fnd_gate_secret_expr() {
  local slot
  if [ -f "$1/foundation/gates/$2/secret" ]; then
    slot=$(fnd_record_line "$1/foundation/gates/$2/secret")
    printf '%s\n' "${slot#LOADER_TRUST_}"
  else
    printf 'NULL\n'
  fi
}

# fnd_render_secret_block <base> <gate> — the #ifdef block mapping the
# gate's secret SLOT to its local macro (slot minus LOADER_TRUST_)
fnd_render_secret_block() {
  local slot local_name
  slot=$(fnd_record_line "$1/foundation/gates/$2/secret")
  local_name="${slot#LOADER_TRUST_}"
  printf '#ifdef %s\n' "$slot"
  printf '#define\t%s\t%s\n' "$local_name" "$slot"
  printf '#else\n'
  printf '#define\t%s\tNULL\n' "$local_name"
  printf '#endif\n'
}

# fnd_render_gate_c <base> <gate> — GATE_DEFINE as it lands in foundation.c
fnd_render_gate_c() {
  local base="$1" name="$2" c first=1
  printf 'GATE_DEFINE(%s, %s' "$name" "$(fnd_gate_secret_expr "$base" "$name")"
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    printf ',\n    %s' "$(fnd_render_claim "$base" "$c")"
  done < "$base/foundation/gates/$name/claims"
  printf ');\n'
}

# fnd_render_policy_c <base> <policy> — one POLICY(...) table entry (tab
# indented, trailing comma) as it lands in a <phase>_policies[] table
fnd_render_policy_c() {
  local base="$1" name="$2" gate line
  gate=$(sed -n 's/^gate //p' "$base/foundation/policies/$name" | head -1)
  printf '\tPOLICY(%s' "$gate"
  sed -n 's/^trigger //p' "$base/foundation/policies/$name" | while IFS= read -r line; do
    printf ',\n\t    %s' "$(fnd_render_trigger "$base" "$line")"
  done
  printf '),\n'
}

#-----------------------------------------------------------------------------
# dump — the arsenal as CLI replays, dependency order (cat-pinned)
#-----------------------------------------------------------------------------
#@help ___foundation_dump0
# @internal building block of the database dump: the five families as CLI
# replays in dependency order (expectations, claims, triggers, gates,
# policies). Order INSIDE a gate/policy is file order, replayed as plain
# appends. Adds are idempotent-immutable, so replays are safe.
#@end
___foundation_dump0() {
  local base="$ELEBAKE_BASE" f g line type label value
  printf '%s\n' "# foundation arsenal - CLI replay per family (dependency order)"
  for f in "$base"/foundation/macros/*; do
    [ -f "$f" ] || continue
    read -r type label value < "$f"   # value = "<defined> <else...>"
    printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" macro add '$(basename "$f")' '$type' '$label' '${value#* }' '${value%% *}'"
  done
  for f in "$base"/foundation/expectations/*; do
    [ -f "$f" ] || continue
    read -r type label value < "$f"
    printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" expectation add '$(basename "$f")' '$type' '$label' '$value'"
  done
  for f in "$base"/foundation/claims/*; do
    [ -f "$f" ] || continue
    printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" claim add '$(basename "$f")' $(sed "s/[^ ]*/'&'/g" "$f")"
  done
  for f in "$base"/foundation/triggers/*; do
    [ -f "$f" ] || continue
    printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" trigger add '$(basename "$f")' $(sed "s/[^ ]*/'&'/g" "$f")"
  done
  for g in "$base"/foundation/gates/*/; do
    [ -d "$g" ] || continue
    if [ -f "$g/secret" ]; then
      printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate add '$(basename "$g")' '$(fnd_record_line "$g/secret")'"
    else
      printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate add '$(basename "$g")'"
    fi
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate claim add '$(basename "$g")' '$line'"
    done < "$g/claims"
  done
  for f in "$base"/foundation/policies/*; do
    [ -f "$f" ] || continue
    printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" policy add '$(basename "$f")' '$(sed -n 's/^gate //p' "$f" | head -1)'"
    sed -n 's/^trigger //p' "$f" | while IFS= read -r line; do
      printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" policy trigger add '$(basename "$f")' '$line'"
    done
  done
  return 0
}
