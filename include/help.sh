#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# help.sh - the generated help system (ported from vpn-switch, its source of
# truth for mechanically assembled help).
#
# Help text is assembled from #@help doc-blocks declared above each anchor
# function. This module owns:
#   - the @defgroup taxonomy and @topic entries (below),
#   - the runtime parser + renderer (help_render),
#   - the user-facing entry points (_help0 overview, _help1/_help2 detail).
# A doc-block that lies is a bug; hand-maintained overviews are not accepted.

# --- Help taxonomy: overview sections, ordered by @order ---------------------

#@help
# @defgroup setup  Without a database
# @order   10
#   The only commands that run without an existing database. Start here.
#@end

#@help
# @defgroup configuration  Configuration
# @order   20
#   Read and change elebake environment variables and interpreter pins.
#@end

#@help
# @defgroup database  Database lifecycle
# @order   30
#   Back up, restore and batch-drive the database itself.
#@end

#@help
# @defgroup keys  Keys
# @order   40
#   Key registries. Records hold REFERENCES (paths, URIs, key ids) -- never
#   private material; custody stays with the token, keyring, or root file.
#@end

#@help
# @defgroup stage  Stage pipeline
# @order   50
#   A stage is one named workspace for one boot tree: bind keys, check out a
#   worktree, embed trust, build isolated, curate, sign, attest.
#@end

#@help
# @defgroup provisioning  Provisioning
# @order   60
#   The machine-bound trust expectations: the NVRAM boot marker and the
#   compiled-in baselines (local/site.mk). What turns a generic loader into
#   THIS machine's tamper detector.
#@end

#@help
# @defgroup deploy  Medium
# @order   70
#   The physical boot medium: bind it, back up its loader, swap, roll back.
#@end

#@help
# @defgroup diagnostics  Diagnostics
# @defgroup foundation  Trust foundation (catalogs and, soon, claims/gates/policies)
# @order   80
#   Toolchain readiness checks; each backend answers for itself.
#@end

#@help
# @topic Inspect-by-default
# @group setup
#   Pipeline commands PRINT their shell: review, then append '| sh' to run
#   ('| sudo sh' where the ESP or root-only keys are involved). Bookkeeping
#   (add/bind/setenv/filter) is pinned to sh and acts directly.
#   Experienced users may flip the safety default so EVERY terminal acts:
#   elebake setenv ELEBAKE_TERMINAL_INTERPRETER sh
#   (inspect any single command via setintp <family> cat, or per run
#   under an explicit interpreter).
#@end

# --- Generated-help engine ---------------------------------------------------
# help_source_files: the files scanned for #@help doc-blocks at runtime.
help_source_files() {
  echo "$ELEBAKE_CONTEXT_SCRIPT"
  local m
  for m in "$ELEBAKE_LIBDIR"/include/*.sh; do
    [ -f "$m" ] || continue
    [ "$m" = "$ELEBAKE_CONTEXT_SCRIPT" ] && continue
    echo "$m"
  done
}

# help_render MODE [TARGET]
#   MODE=overview  -> grouped command summaries (elebake help)
#   MODE=query     -> detail (exact command), group, or prefix match
#   MODE=manpage   -> markdown COMMANDS sections
# Honours ELEBAKE_DISPLAY_ANSI. Pure read of the doc-blocks.
help_render() {
  local mode="$1" target="${2:-}"
  local ch="" cc="" cg="" cr=""
  if [ "${ELEBAKE_DISPLAY_ANSI:-0}" = "1" ]; then
    ch="$COLOR_BLUE"; cc="$COLOR_CYAN"; cg="$COLOR_GRAY"; cr="$COLOR_RESET"
  fi
  help_source_files | tr '\n' '\0' | xargs -0 cat 2>>"$LOG_FILE" | awk \
    -v mode="$mode" -v target="$target" \
    -v ch="$ch" -v cc="$cc" -v cg="$cg" -v cr="$cr" '
    function trim(s){ sub(/^[ \t]+/,"",s); sub(/[ \t]+$/,"",s); return s }
    function pathof(u,  p){ p=u; sub(/[ \t]*[<[].*$/,"",p); return trim(p) }
    function mesc(s){ gsub(/</,"\\<",s); gsub(/>/,"\\>",s); gsub(/\|/,"\\|",s); return s }
    BEGIN{ seq=0 }
    /^#@help/ { inblk=1; kind=""; usage=""; summary=""; ret=""; body="";
                gc=0; pc=0; ec=0; sc=0; vc=0; dgid=""; dgtitle=""; dgord=999; topic="";
                next }
    inblk && /^#@end$/ {
      inblk=0
      if (kind=="command") {
        p=pathof(usage); cu[p]=usage; cs[p]=summary; cr_[p]=ret; cord[p]=(++seq)
        cnp[p]=pc; for(i=1;i<=pc;i++) cp[p,i]=prm[i]
        cne[p]=ec; for(i=1;i<=ec;i++) cex[p,i]=exs[i]
        cns[p]=sc; for(i=1;i<=sc;i++) cse[p,i]=seer[i]
        cnv[p]=vc; for(i=1;i<=vc;i++) cv[p,i]=env[i]
        for(i=1;i<=gc;i++){ g=grp[i]; gmn[g]++; gm[g,gmn[g]]=p }
      } else if (kind=="defgroup") {
        dgt[dgid]=dgtitle; dgo[dgid]=dgord; dgb[dgid]=body; dgall[++ndg]=dgid
      } else if (kind=="topic") {
        for(i=1;i<=gc;i++){ g=grp[i]; tpn[g]++; tpt[g,tpn[g]]=topic; tpb[g,tpn[g]]=body }
      }
      next
    }
    inblk {
      line=$0
      if (match(line,/^#[ \t]*@[a-z]+/)) {
        rest=line; sub(/^#[ \t]*@/,"",rest)
        name=rest; sub(/[ \t].*$/,"",name)
        val=rest; sub(/^[a-z]+[ \t]*/,"",val); val=trim(val)
        if(name=="command"){kind="command"; usage=val}
        else if(name=="summary"){summary=val}
        else if(name=="group"){grp[++gc]=val}
        else if(name=="param"){prm[++pc]=val}
        else if(name=="env"){env[++vc]=val}
        else if(name=="option"){prm[++pc]="--" val}
        else if(name=="returns"){ret=val}
        else if(name=="example"){exs[++ec]=val}
        else if(name=="see"){seer[++sc]=val}
        else if(name=="defgroup"){kind="defgroup"; dgid=val; sub(/[ \t].*$/,"",dgid); dgtitle=val; sub(/^[^ \t]+[ \t]+/,"",dgtitle)}
        else if(name=="order"){dgord=val+0}
        else if(name=="topic"){kind="topic"; topic=val}
        else if(name=="internal"){kind="internal"}
        next
      }
      if (match(line,/^#[ \t][ \t]/)) { t=line; sub(/^#[ \t]+/,"",t); body=(body==""?t:body "\n" t) }
      next
    }
    END{
      if (mode=="query") {
        if (target in cu) mode="detail"
        else { isg=0; for(a=1;a<=ndg;a++) if(dgall[a]==target) isg=1
               if (isg) mode="group"; else mode="prefix" }
      }
      w=0; for(p in cu){ if(length("elebake " cu[p]) > w) w=length("elebake " cu[p]) }
      w+=2
      if (mode=="detail") {
        if (!(target in cu)) { print "Unknown command: " target; exit 1 }
        print ch "elebake " cu[target] cr
        print "  " cs[target]
        if (cnp[target]>0){ print ""; print ch "Arguments:" cr; for(i=1;i<=cnp[target];i++) print "  " cp[target,i] }
        if (cr_[target]!=""){ print ""; print ch "Output:" cr "  " cr_[target] }
        if (cnv[target]>0){ print ""; print ch "Environment:" cr; for(i=1;i<=cnv[target];i++) print "  " cv[target,i]; print "  " cg "(details: elebake help env <VAR>)" cr }
        if (cne[target]>0){ print ""; print ch "Examples:" cr; for(i=1;i<=cne[target];i++) print "  " cc cex[target,i] cr }
        if (cns[target]>0){ print ""; print ch "See also:" cr; for(i=1;i<=cns[target];i++) print "  " cc "elebake " cse[target,i] cr }
        exit 0
      }
      if (mode=="prefix") {
        n=0; for(p in cu) if (index(p, target)==1) n++
        if (n==0) { print "No help for: " target; exit 1 }
        for(p in cu) if (index(p, target)==1) { pad=w-length("elebake " cu[p]); s=sprintf("%-"pad"s",""); print "  " cc "elebake " cu[p] cr s cg cs[p] cr }
        exit 0
      }
      for(a=1;a<=ndg;a++) ord[a]=dgall[a]
      for(a=2;a<=ndg;a++){ k=ord[a]; b=a-1; while(b>=1 && dgo[ord[b]]>dgo[k]){ ord[b+1]=ord[b]; b-- } ord[b+1]=k }
      if (mode=="manpage") {
        for(a=1;a<=ndg;a++){
          g=ord[a]
          if (gmn[g]==0 && tpn[g]==0) continue
          print "## " dgt[g]; print ""
          if (dgb[g]!=""){ nn=split(dgb[g],bl,"\n"); for(i=1;i<=nn;i++) print mesc(bl[i]); print "" }
          for(i=1;i<=gmn[g];i++){ p=gm[g,i]; print "**" mesc(cu[p]) "**"; print ":   " mesc(cs[p]); print "" }
          for(i=1;i<=tpn[g];i++){ print "**" mesc(tpt[g,i]) "**"; print ":   "; m=split(tpb[g,i],tl,"\n"); for(j=1;j<=m;j++) print "    " mesc(tl[j]); print "" }
        }
        exit 0
      }
      first=1
      for(a=1;a<=ndg;a++){
        g=ord[a]
        if (mode=="group" && g!=target) continue
        if (gmn[g]==0 && tpn[g]==0) continue
        if (!first) print ""
        first=0
        print ch dgt[g] cr
        print ""
        if (dgb[g]!="") { intro=dgb[g]; gsub(/\n/," ",intro); print "  " cg intro cr; print "" }
        for(i=1;i<=gmn[g];i++){ p=gm[g,i]; pad=w-length("elebake " cu[p]); s=sprintf("%-"pad"s",""); print "  " cc "elebake " cu[p] cr s cg cs[p] cr }
        for(i=1;i<=tpn[g];i++){ print "  " ch tpt[g,i] cr; m=split(tpb[g,i],tl,"\n"); for(j=1;j<=m;j++) print "    " cg tl[j] cr }
      }
    }
  '
}

#@help _help0
# @command help [<command|group|topic>]
# @summary Show the grouped overview, or detail for a command, group or topic
# @group   setup
# @param   command  any command path (e.g. 'stage sign'), a group (keys, stage,
# @param            provisioning, deploy, ...) or a topic (environment)
# @returns help text (no database required)
# @env     ELEBAKE_DISPLAY_ANSI  0 disables colored output
# @example elebake help stage
# @example elebake help stage sign
#@end
_help0() {
  local c_reset="" c_heading="" c_gray=""
  if [ "${ELEBAKE_DISPLAY_ANSI:-0}" = "1" ]; then
    c_reset="$COLOR_RESET"; c_heading="$COLOR_BLUE"; c_gray="$COLOR_GRAY"
  fi
  printf '%b\n' "${c_heading}elebake${c_reset} - emit-and-inspect tooling for verified boot / tamper detection"
  echo ""
  printf '%b\n' "${c_gray}Usage:${c_reset} elebake <command> [arguments]"
  printf '%b\n' "${c_gray}Detail for any command:${c_reset} elebake help <command>   ${c_gray}(e.g. elebake help stage sign)${c_reset}"
  echo ""
  help_render overview
  echo ""
  printf '%b\n' "${c_gray}Concept topic:${c_reset} elebake help environment"
}

#@help _help1
# @internal arity-1 sibling of 'help' (group/topic/one-word command dispatch)
#@end
_help1() {
  local topic="$1"
  case "$topic" in
    environment)
      cat <<'EOF' >&2

===============================================================================
Environment System and Safety-First Design
===============================================================================

elebake displays commands instead of executing them. That is intentional and
controlled by interpreter variables, resolved per function (first match wins):

1. Arity-specific pin:   ELEBAKE_INTERPRETER_<function><arity>
2. Arity-agnostic pin:   ELEBAKE_INTERPRETER_<function>
3. Class fallback:       _f   -> ELEBAKE_TERMINAL_INTERPRETER          (cat)
                         __f  -> ELEBAKE_COMBINATOR_INTERPRETER
                         ___f -> ELEBAKE_BATCH_COMBINATOR_INTERPRETER

The class fallback is a safety net, not a place to declare behaviour: commands
whose effect must not depend on a global toggle (bookkeeping, help) carry their
own pin. Inspect and set them with:

  elebake getintp <function>
  elebake setintp <function> <interpreter>

Variables resolve through a three-layer cascade; the first layer that has the
file wins:

  .env/local/            machine overrides (setenv writes here)
  .env/default/          installed by bootstrap from the chosen profile
  template/environment/  shipped baseline

  elebake getenv <VAR>       effective value + which layer answered
  elebake printenv           the whole effective environment

Profiles (bootstrap <name> minimal|all) are files in template/environment/
(ELEBAKE_PROFILE_*): line 1 lists the variables to install into .env/default.
After adding a variable to the templates, add it to BOTH profile lists —
an uninstalled interpreter pin silently falls back to cat.

Logs and traces of every invocation: .log/YYYY-MM-DD/ inside the database,
retention via ELEBAKE_RETENTION_DAYS_LOG / _TRACE.
===============================================================================
EOF
      ;;
    *)
      help_render query "$topic"
      ;;
  esac
}

#@help _help2
# @internal arity-2 sibling of 'help' (detail for two-word command paths)
#@end
_help2() {
  help_render query "$1 $2"
}
