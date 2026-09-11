#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Dr. Johannes Brügmann
# elebake render - the userland phase containers earlboot and elvbootd,
# rendered from the bindings into ONE hardened script per artifact.
#
# A container HOSTS phases (docs/DESIGN_STAGE_FOUNDATION.md §1): the loader is
# the C container (foundation.c, stage foundation), earlboot and elvbootd are
# sh containers whose catalogs live in the checkout under
# stand/efi/loader/local/<container>/ (policy.sh: PHASES + when_*; measure.sh:
# measure_*/diagnose_*; action.sh: <name>_act). The user binds the SAME
# arsenal records to a container's phases; the emitters compose the
# referenced functions with the bindings:
#
#   stage earlboot mk <stage>     hooks/earlboot          rc.d, SYSINIT + MOUNTED
#   stage elvbootd mk <stage>     hooks/hook.<phase>.sh   one per bound runtime phase
#                                 hooks/elvbootd          glue for STARTUP (rc.d)
#                                 hooks/elvboot.devd.conf  glue for MEDIA (devd)
#   stage earlboot|elvbootd install <stage>   copy into place (sudo)
#   stage earlboot test <stage> <dump>        the same rendering with mocks, run
#
# Top down: an mk is a batch -- the preconditions as lines (the stage, its
# checkout, the demands of the bound measurements on the boot tree), the
# parts of the script as lines appended to <file>.new, the install as the
# last line. A part is a terminal printing script text (cat pin) or a batch
# of such terminals; where a part has nothing to say, 'comment' says why and
# prints nothing into the script (sh pin). The container is in the NAME of
# every anchor that knows container specifics (rc.d keywords, catalog files,
# phases); the generic parts take no container at all. Every function is one
# step, nesting level 1, arguments <stage> <container> ... <smallest>.
#
# Knowledge in tables: template/tbl/boot-tree-demands.tbl (what a measurement
# demands of the boot tree), the checkout's earlboot/tools.sh (the external
# commands with their '# test:' mock classes).

#@help ___stage_earlboot_mk1
# @command stage earlboot mk <stage>
# @summary Generate the earlboot rc.d script of the stage into its hooks/earlboot: the stage and its checkout exist, the bound measurements' demands on the boot tree are met (stage require <stage> earlboot), then header, constants, state, tools, the catalog functions, the prologue, the phases SYSINIT and MOUNTED in that order, the footer, and the install. Assumes: the record LOADER_TRUST_WORD_SECRET is present when a word claim or handover is bound; mac_bootlock keeps loader.trust.* immutable; the script is installed with 'stage earlboot install' and covered by mac_veriexec
# @group   foundation
# @example elebake stage earlboot mk daily-v1
# @see     stage earlboot test
# @see     stage earlboot install
# @see     stage elvbootd mk
# @see     stage require
#@end
___stage_earlboot_mk1() {
        local f="$ELEBAKE_BASE/stage/$1/hooks/earlboot"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage checkout exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage requirements ensure earlboot '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage container prepare '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage container render header earlboot '$1' > '$f.new'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage container render constants '$1' >> '$f.new'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage container render state >> '$f.new'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage container render tools '$1' >> '$f.new'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage container render functions earlboot '$1' >> '$f.new'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage container render prologue >> '$f.new'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage container render phase '$1' SYSINIT >> '$f.new'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage container render phase '$1' MOUNTED >> '$f.new'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage container render footer >> '$f.new'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage hook install '$1' '$f'"
}

#@help ___stage_earlboot_test2
# @command stage earlboot test <stage> <dump>
# @summary Replay a captured boot through the CURRENT earlboot of the stage, without root and without side effects: the same rendering as 'stage earlboot mk' but with mocks for state and tools -- kenv/sysctl/kldstat answer from <dump>, shutdown and logger become notes on stderr, the state lives under hooks/ and is removed after -- then the run: exit code, every file the run left (appraisal, book, spool, marks). Never run the INSTALLED earlboot by hand: book_act appends to the book. Capture a dump after a boot with: { kenv; sysctl kern.osrelease kern.ident kern.securelevel | sed 's/^/sysctl./'; kldstat -q -m mac_bootlock && echo 'kldstat.mac_bootlock=1'; } > /tmp/ram/boot.kenv
# @group   foundation
# @example elebake stage earlboot test daily-v1 /tmp/ram/boot.kenv
# @see     stage earlboot mk
# @see     stage container render mocks
#@end
___stage_earlboot_test2() {
        local f="$ELEBAKE_BASE/stage/$1/hooks/earlboot.test"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage checkout exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage dump readable '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage container prepare '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage container render header earlboot '$1' > '$f'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage container render constants '$1' >> '$f'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage container render mocks '$1' earlboot '$2' >> '$f'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage container render functions earlboot '$1' >> '$f'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage container render prologue >> '$f'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage container render phase '$1' SYSINIT >> '$f'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage container render phase '$1' MOUNTED >> '$f'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage container render footer >> '$f'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage hook test run '$1' earlboot '$f'"
}

#@help ___stage_earlboot_install1
# @command stage earlboot install <stage>
# @summary Install the generated earlboot script as /etc/rc.d/earlboot (root:wheel 0500; the root dataset, so the earliest userland does not depend on a mounted /usr/local) and enable it in /etc/rc.conf.d/earlboot; refused while none was generated. Run as root
# @group   foundation
# @env     ELEBAKE_STATE_DB  the target state directory of the scripts (created 0700 root)
# @example elebake stage earlboot install daily-v1
# @see     stage earlboot mk
#@end
___stage_earlboot_install1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage earlboot generated '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage state dir mk"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage earlboot place '$1'"
}

#@help _stage_earlboot_generated1
# @command stage earlboot generated <stage>
# @summary The generated script hooks/earlboot of the stage is there and not empty (one test)
# @group   foundation
# @internal
# @see     stage earlboot install
#@end
_stage_earlboot_generated1() {
        printf '%s\n' "test -s '$ELEBAKE_BASE/stage/$1/hooks/earlboot'"
}

#@help _stage_earlboot_place1
# @command stage earlboot place <stage>
# @summary Act terminal: install hooks/earlboot as /etc/rc.d/earlboot (root:wheel 0500) and enable it in /etc/rc.conf.d/earlboot
# @group   foundation
# @internal
# @see     stage earlboot install
#@end
_stage_earlboot_place1() {
        printf '%s\n' "install -o root -g wheel -m 0500 '$ELEBAKE_BASE/stage/$1/hooks/earlboot' /etc/rc.d/earlboot"
        printf '%s\n' "mkdir -p /etc/rc.conf.d && printf 'earlboot_enable=\\"YES\\"\\n' > /etc/rc.conf.d/earlboot"
        printf '%s\n' "printf '# earlboot installed from stage %s\\n' '$1' >&2"
}

#@help _stage_state_dir_mk0
# @command stage state dir mk
# @summary Act terminal: create the target state directory ELEBAKE_STATE_DB (0700 root) the hooks write to
# @group   foundation
# @internal
# @env     ELEBAKE_STATE_DB  the target state directory
# @see     stage earlboot install
# @see     stage elvbootd install
#@end
_stage_state_dir_mk0() {
        printf '%s\n' "mkdir -p '${ELEBAKE_STATE_DB}' && chmod 0700 '${ELEBAKE_STATE_DB}'"
}

#@help ___stage_elvbootd_mk1
# @command stage elvbootd mk <stage>
# @summary Generate the elvbootd hooks of the stage into its hooks/: the stage and its checkout exist, the bound measurements' demands on the boot tree are met, at least one runtime phase is bound; then one self-contained hook.<phase>.sh per BOUND runtime phase (STARTUP rc.d start, PERIODIC periodic/security, RESUME rc.resume, MEDIA devd with $1 = the cdev, SHUTDOWN rc.d stop), each with header, constants, state, tools, the catalog functions (earlboot's palette inherited), the prologue and its phase; plus the glue that plugs a hook into its mechanism: hooks/elvbootd (rc.d) when STARTUP or SHUTDOWN is bound, hooks/elvboot.devd.conf (devd) when MEDIA is bound
# @group   foundation
# @example elebake stage elvbootd mk daily-v1
# @see     stage elvbootd install
# @see     stage earlboot mk
# @see     stage require
#@end
___stage_elvbootd_mk1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage checkout exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage requirements ensure elvbootd '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage elvbootd bound '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage container prepare '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage elvbootd hook mk '$1' STARTUP"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage elvbootd hook mk '$1' PERIODIC"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage elvbootd hook mk '$1' RESUME"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage elvbootd hook mk '$1' MEDIA"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage elvbootd hook mk '$1' SHUTDOWN"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage elvbootd glue rcd mk '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage elvbootd glue devd mk '$1'"
}

#@help __stage_elvbootd_bound1
# @command stage elvbootd bound <stage>
# @summary At least one runtime phase of the stage binds a policy (STARTUP, PERIODIC, RESUME, MEDIA, SHUTDOWN): a comment line, else an error line
# @group   foundation
# @internal
# @see     stage elvbootd mk
#@end
__stage_elvbootd_bound1() {
        if cat "$ELEBAKE_BASE/stage/$1/phases/STARTUP" "$ELEBAKE_BASE/stage/$1/phases/PERIODIC" "$ELEBAKE_BASE/stage/$1/phases/RESUME" "$ELEBAKE_BASE/stage/$1/phases/MEDIA" "$ELEBAKE_BASE/stage/$1/phases/SHUTDOWN" 2>/dev/null | grep -q .; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'stage $1 binds a runtime phase'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage elvbootd mk $1: no runtime phase bound (stage phase policy add $1 STARTUP|PERIODIC|RESUME|MEDIA|SHUTDOWN <policy>)'"
        fi
}

#@help __stage_elvbootd_hook_mk2
# @command stage elvbootd hook mk <stage> <phase>
# @summary The runtime phase binds a policy: rewrite to 'stage elvbootd hook render <stage> <phase>', else a comment line (no hook for an unbound phase)
# @group   foundation
# @internal
# @see     stage elvbootd mk
#@end
__stage_elvbootd_hook_mk2() {
        if test -s "$ELEBAKE_BASE/stage/$1/phases/$2"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage elvbootd hook render '$1' '$2'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'stage $1: phase $2 binds no policy, no hook'"
        fi
}

#@help ___stage_elvbootd_hook_render2
# @command stage elvbootd hook render <stage> <phase>
# @summary The parts of one elvbootd hook, hooks/hook.<phase>.sh (lower case): header, constants, state, tools, the catalog functions with earlboot's inherited, the prologue, the one phase, the footer, then the install
# @group   foundation
# @internal
# @see     stage elvbootd mk
#@end
___stage_elvbootd_hook_render2() {
        local f="$ELEBAKE_BASE/stage/$1/hooks/hook.$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]').sh"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage container render header elvbootd '$1' > '$f.new'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage container render constants '$1' >> '$f.new'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage container render state >> '$f.new'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage container render tools '$1' >> '$f.new'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage container render functions elvbootd '$1' >> '$f.new'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage container render prologue >> '$f.new'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage container render phase '$1' '$2' >> '$f.new'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage container render footer >> '$f.new'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage hook install '$1' '$f'"
}

#@help ___stage_elvbootd_glue_rcd_mk1
# @command stage elvbootd glue rcd mk <stage>
# @summary STARTUP or SHUTDOWN binds a policy: the one line that writes hooks/elvbootd from 'stage elvbootd glue rcd' (.new then mv: the installed file is 0500), else a comment line -- a batch, because the line carries a redirection
# @group   foundation
# @internal
# @see     stage elvbootd glue rcd
#@end
___stage_elvbootd_glue_rcd_mk1() {
        if cat "$ELEBAKE_BASE/stage/$1/phases/STARTUP" "$ELEBAKE_BASE/stage/$1/phases/SHUTDOWN" 2>/dev/null | grep -q .; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage elvbootd glue rcd '$1' > '$ELEBAKE_BASE/stage/$1/hooks/elvbootd.new' && mv '$ELEBAKE_BASE/stage/$1/hooks/elvbootd.new' '$ELEBAKE_BASE/stage/$1/hooks/elvbootd' && chmod 0500 '$ELEBAKE_BASE/stage/$1/hooks/elvbootd'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'stage $1: neither STARTUP nor SHUTDOWN binds a policy, no rcd glue'"
        fi
}

#@help ___stage_elvbootd_glue_devd_mk1
# @command stage elvbootd glue devd mk <stage>
# @summary MEDIA binds a policy: the one line that writes hooks/elvboot.devd.conf from 'stage elvbootd glue devd' (.new then mv: the installed file is 0500), else a comment line -- a batch, because the line carries a redirection
# @group   foundation
# @internal
# @see     stage elvbootd glue devd
#@end
___stage_elvbootd_glue_devd_mk1() {
        if test -s "$ELEBAKE_BASE/stage/$1/phases/MEDIA"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage elvbootd glue devd '$1' > '$ELEBAKE_BASE/stage/$1/hooks/elvboot.devd.conf.new' && mv '$ELEBAKE_BASE/stage/$1/hooks/elvboot.devd.conf.new' '$ELEBAKE_BASE/stage/$1/hooks/elvboot.devd.conf'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'stage $1: MEDIA binds no policy, no devd glue'"
        fi
}

#@help _stage_elvbootd_glue_rcd1
# @command stage elvbootd glue rcd <stage>
# @summary Print the rc.d glue of the STARTUP and SHUTDOWN hooks: the rc script /usr/local/etc/rc.d/elvbootd (PROVIDE elvbootd, REQUIRE NETWORKING, KEYWORD shutdown) whose start runs hook.startup.sh and whose stop runs hook.shutdown.sh -- each ':' when its phase binds nothing
# @group   foundation
# @internal
# @see     stage elvbootd mk
# @see     stage elvbootd glue devd
#@end
_stage_elvbootd_glue_rcd1() {
        local start=":" stop=":"
        test -s "$ELEBAKE_BASE/stage/$1/phases/STARTUP" && start=/usr/local/etc/elvboot/hook.startup.sh
        test -s "$ELEBAKE_BASE/stage/$1/phases/SHUTDOWN" && stop=/usr/local/etc/elvboot/hook.shutdown.sh
        printf '#!/bin/sh\n# generated by elebake stage elvbootd mk (stage %s) -- do not edit\n' "$1"
        printf '# PROVIDE: elvbootd\n# REQUIRE: NETWORKING\n# KEYWORD: nojail shutdown\n\n. /etc/rc.subr\n\n'
        printf 'name=elvbootd\nrcvar=elvbootd_enable\nstart_cmd="%s"\nstop_cmd="%s"\n\n' "$start" "$stop"
        printf 'load_rc_config $name\nrun_rc_command "$1"\n'
}

#@help _stage_elvbootd_glue_devd1
# @command stage elvbootd glue devd <stage>
# @summary Print the devd glue for the MEDIA hook: every appearing da[0-9]+ cdev runs /usr/local/etc/elvboot/hook.media.sh <cdev>
# @group   foundation
# @internal
# @see     stage elvbootd mk
# @see     stage elvbootd glue rcd
#@end
_stage_elvbootd_glue_devd1() {
        printf '# generated by elebake stage elvbootd mk (stage %s) -- do not edit\n' "$1"
        printf 'notify 100 {\n\tmatch "system" "DEVFS";\n\tmatch "type" "CREATE";\n\tmatch "cdev" "da[0-9]+";\n\taction "/usr/local/etc/elvboot/hook.media.sh $cdev";\n};\n'
}

#@help ___stage_elvbootd_install1
# @command stage elvbootd install <stage>
# @summary Install the generated hooks under /usr/local/etc/elvboot/ (0500) and wire each into its mechanism with the generated glue: STARTUP as /usr/local/etc/rc.d/elvbootd (enabled), PERIODIC as /usr/local/etc/periodic/security/900.elvboot, RESUME as a line in /etc/rc.resume, MEDIA via /usr/local/etc/devd/elvboot.conf (devd restarted). Refused while nothing was generated. Run as root
# @group   foundation
# @env     ELEBAKE_STATE_DB  the target state directory of the hooks (created 0700 root)
# @example elebake stage elvbootd install daily-v1
# @see     stage elvbootd mk
#@end
___stage_elvbootd_install1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage elvbootd generated '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage state dir mk"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage elvbootd hook install '$1' startup"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage elvbootd hook install '$1' periodic"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage elvbootd hook install '$1' resume"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage elvbootd hook install '$1' media"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage elvbootd hook install '$1' shutdown"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage marker place '$1'"
}

#@help _stage_elvbootd_generated1
# @command stage elvbootd generated <stage>
# @summary At least one generated hook hooks/hook.<phase>.sh of the stage is there (one test)
# @group   foundation
# @internal
# @see     stage elvbootd install
#@end
_stage_elvbootd_generated1() {
        printf '%s\n' "ls '$ELEBAKE_BASE/stage/$1/hooks'/hook.*.sh > /dev/null 2>&1"
}

#@help __stage_elvbootd_hook_install2
# @command stage elvbootd hook install <stage> <startup|periodic|resume|media|shutdown>
# @summary The hook was generated: rewrite to 'stage elvbootd <phase> place <stage>' (dispatch binds the phase's own act terminal), else a comment line
# @group   foundation
# @internal
# @see     stage elvbootd install
#@end
__stage_elvbootd_hook_install2() {
        if test -s "$ELEBAKE_BASE/stage/$1/hooks/hook.$2.sh"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage elvbootd '$2' place '$1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'stage $1: no $2 hook generated, nothing to install'"
        fi
}

#@help _stage_elvbootd_startup_place1
# @command stage elvbootd startup place <stage>
# @summary Act terminal: install the STARTUP hook and its rc.d glue hooks/elvbootd as /usr/local/etc/rc.d/elvbootd, enabled in /etc/rc.conf.d/elvbootd
# @group   foundation
# @internal
# @see     stage elvbootd install
#@end
_stage_elvbootd_startup_place1() {
        printf '%s\n' "mkdir -p /usr/local/etc/elvboot"
        printf '%s\n' "install -o root -g wheel -m 0500 '$ELEBAKE_BASE/stage/$1/hooks/hook.startup.sh' /usr/local/etc/elvboot/hook.startup.sh"
        printf '%s\n' "install -o root -g wheel -m 0500 '$ELEBAKE_BASE/stage/$1/hooks/elvbootd' /usr/local/etc/rc.d/elvbootd"
        printf '%s\n' "mkdir -p /etc/rc.conf.d && printf 'elvbootd_enable=\\"YES\\"\\n' > /etc/rc.conf.d/elvbootd"
        printf '%s\n' "printf '# elvbootd: startup hook installed from stage %s\\n' '$1' >&2"
}

#@help _stage_elvbootd_periodic_place1
# @command stage elvbootd periodic place <stage>
# @summary Act terminal: install the PERIODIC hook and link it as /usr/local/etc/periodic/security/900.elvboot
# @group   foundation
# @internal
# @see     stage elvbootd install
#@end
_stage_elvbootd_periodic_place1() {
        printf '%s\n' "mkdir -p /usr/local/etc/elvboot"
        printf '%s\n' "install -o root -g wheel -m 0500 '$ELEBAKE_BASE/stage/$1/hooks/hook.periodic.sh' /usr/local/etc/elvboot/hook.periodic.sh"
        printf '%s\n' "mkdir -p /usr/local/etc/periodic/security && ln -sfn /usr/local/etc/elvboot/hook.periodic.sh /usr/local/etc/periodic/security/900.elvboot"
        printf '%s\n' "printf '# elvbootd: periodic hook installed from stage %s\\n' '$1' >&2"
}

#@help _stage_elvbootd_resume_place1
# @command stage elvbootd resume place <stage>
# @summary Act terminal: install the RESUME hook and add its line to /etc/rc.resume once
# @group   foundation
# @internal
# @see     stage elvbootd install
#@end
_stage_elvbootd_resume_place1() {
        printf '%s\n' "mkdir -p /usr/local/etc/elvboot"
        printf '%s\n' "install -o root -g wheel -m 0500 '$ELEBAKE_BASE/stage/$1/hooks/hook.resume.sh' /usr/local/etc/elvboot/hook.resume.sh"
        printf '%s\n' "grep -q '/usr/local/etc/elvboot/hook.resume.sh' /etc/rc.resume 2>/dev/null || printf '/usr/local/etc/elvboot/hook.resume.sh\\n' >> /etc/rc.resume"
        printf '%s\n' "printf '# elvbootd: resume hook installed from stage %s\\n' '$1' >&2"
}

#@help _stage_elvbootd_media_place1
# @command stage elvbootd media place <stage>
# @summary Act terminal: install the MEDIA hook and its devd glue as /usr/local/etc/devd/elvboot.conf, devd restarted
# @group   foundation
# @internal
# @see     stage elvbootd install
#@end
_stage_elvbootd_media_place1() {
        printf '%s\n' "mkdir -p /usr/local/etc/elvboot"
        printf '%s\n' "install -o root -g wheel -m 0500 '$ELEBAKE_BASE/stage/$1/hooks/hook.media.sh' /usr/local/etc/elvboot/hook.media.sh"
        printf '%s\n' "mkdir -p /usr/local/etc/devd && install -o root -g wheel -m 0444 '$ELEBAKE_BASE/stage/$1/hooks/elvboot.devd.conf' /usr/local/etc/devd/elvboot.conf && service devd restart"
        printf '%s\n' "printf '# elvbootd: media hook installed from stage %s\\n' '$1' >&2"
}

#@help _stage_elvbootd_shutdown_place1
# @command stage elvbootd shutdown place <stage>
# @summary Act terminal: install the SHUTDOWN hook as /usr/local/etc/elvboot/hook.shutdown.sh and its rc.d glue hooks/elvbootd as /usr/local/etc/rc.d/elvbootd (the stop method runs the hook), enabled in /etc/rc.conf.d/elvbootd
# @group   foundation
# @internal
# @see     stage elvbootd install
# @see     stage marker place
#@end
_stage_elvbootd_shutdown_place1() {
        printf '%s\n' "mkdir -p /usr/local/etc/elvboot"
        printf '%s\n' "install -o root -g wheel -m 0500 '$ELEBAKE_BASE/stage/$1/hooks/hook.shutdown.sh' /usr/local/etc/elvboot/hook.shutdown.sh"
        printf '%s\n' "install -o root -g wheel -m 0500 '$ELEBAKE_BASE/stage/$1/hooks/elvbootd' /usr/local/etc/rc.d/elvbootd"
        printf '%s\n' "mkdir -p /etc/rc.conf.d && printf 'elvbootd_enable=\\"YES\\"\\n' > /etc/rc.conf.d/elvbootd"
        printf '%s\n' "printf '# elvbootd: shutdown hook installed from stage %s\\n' '$1' >&2"
}

#@help _stage_container_render_header_earlboot1
# @command stage container render header earlboot <stage>
# @summary Print the hardened prologue of a generated earlboot script: rc.d keywords, readonly PATH, sealed IFS/umask, set -f, DETERMINISTIC provenance (stage, checkout ref, worktree HEAD)
# @group   foundation
# @internal
# @see     stage earlboot mk
#@end
_stage_container_render_header_earlboot1() {
        local ref="" head=""
        ref=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/checkout" 2>/dev/null)
        head=$(git -C "$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local" rev-parse --short HEAD 2>/dev/null)
        printf '#!/bin/sh\n'
        printf '#\n# PROVIDE: earlboot\n# REQUIRE: mountcritlocal\n# BEFORE: NETWORKING netif\n# KEYWORD: nojail\n'
        printf '#\n# generated by elebake stage earlboot mk -- do not edit\n# stage: %s  checkout: %s (%s)\n#\n' "$1" "${ref:--}" "${head:-unknown}"
        printf 'PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin; readonly PATH; export PATH\n'
        printf "IFS=' \t\n'; umask 077; set -f\n"
}

#@help _stage_container_render_header_elvbootd1
# @command stage container render header elvbootd <stage>
# @summary Print the hardened prologue of a generated elvbootd script: readonly PATH, sealed IFS/umask, set -f, DETERMINISTIC provenance (stage, checkout ref, worktree HEAD)
# @group   foundation
# @internal
# @see     stage elvbootd mk
#@end
_stage_container_render_header_elvbootd1() {
        local ref="" head=""
        ref=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/checkout" 2>/dev/null)
        head=$(git -C "$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local" rev-parse --short HEAD 2>/dev/null)
        printf '#!/bin/sh\n'
        printf '#\n# generated by elebake stage elvbootd mk -- do not edit\n# stage: %s  checkout: %s (%s)\n#\n' "$1" "${ref:--}" "${head:-unknown}"
        printf 'PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin; readonly PATH; export PATH\n'
        printf "IFS=' \t\n'; umask 077; set -f\n"
}

#@help __stage_container_render_header2
# @command stage container render header <container> <stage>
# @summary The total fallback behind the container-specific headers (dispatch binds the longer name): a container without its own header is an error line
# @group   foundation
# @internal
# @see     stage earlboot mk
#@end
__stage_container_render_header2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage container render header: no anchor for container $1 (elebake has no stage container render header $1)'"
}

#@help ___stage_container_render_constants1
# @command stage container render constants <stage>
# @summary The readonly constants of a generated container script from the stage records, one terminal each: the word secret, the loader gate publishing the word, the deployed loader digest, the ESP of the first medium, the arm directory, the beacon, the verdict variables
# @group   foundation
# @internal
# @see     stage earlboot mk
#@end
___stage_container_render_constants1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage constant word secret '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage constant loader gate '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage constant loader digest '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage constant esp '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage constant arm dir '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage constant beacon '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage constant marker '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage constant verdicts"
}

#@help _stage_constant_word_secret1
# @command stage constant word secret <stage>
# @summary Print readonly ELV_WORD_SECRET from the stage's baseline LOADER_TRUST_WORD_SECRET (its value field; empty without the record)
# @group   foundation
# @internal
# @see     stage container render constants
#@end
_stage_constant_word_secret1() {
        local type="" value=""
        read -r type value 2>/dev/null < "$ELEBAKE_BASE/stage/$1/baselines/LOADER_TRUST_WORD_SECRET"
        printf 'readonly ELV_WORD_SECRET=%s\n' "$(sq "$value")"
}

#@help _stage_constant_arm_dir1
# @command stage constant arm dir <stage>
# @summary Print readonly ELV_ARM_DIR from the stage's baseline LOADER_TRUST_EARLBOOT_ARM_DIR (its value field; empty without the record)
# @group   foundation
# @internal
# @see     stage container render constants
#@end
_stage_constant_arm_dir1() {
        local type="" value=""
        read -r type value 2>/dev/null < "$ELEBAKE_BASE/stage/$1/baselines/LOADER_TRUST_EARLBOOT_ARM_DIR"
        printf 'readonly ELV_ARM_DIR=%s\n' "$(sq "$value")"
}

#@help _stage_constant_beacon1
# @command stage constant beacon <stage>
# @summary Print readonly ELV_BEACON from the stage's baseline LOADER_TRUST_EARLBOOT_BEACON (its value field; empty without the record)
# @group   foundation
# @internal
# @see     stage container render constants
#@end
_stage_constant_beacon1() {
        local type="" value=""
        read -r type value 2>/dev/null < "$ELEBAKE_BASE/stage/$1/baselines/LOADER_TRUST_EARLBOOT_BEACON"
        printf 'readonly ELV_BEACON=%s\n' "$(sq "$value")"
}

#@help _stage_constant_loader_gate1
# @command stage constant loader gate <stage>
# @summary Print readonly ELV_GATE_LOADER: the gate of the first BOUND policy whose trigger fires handover_act (the word publisher) -- the triggers naming handover_act, the policies listing one of them, intersected with the stage's bound policies; empty when none
# @group   foundation
# @internal
# @see     stage container render constants
#@end
_stage_constant_loader_gate1() {
        local bound="" firing="" t="" p="" gate="" when="" action=""
        bound=$(cat "$ELEBAKE_BASE/stage/$1"/phases/* 2>/dev/null)
        firing=$(for t in "$ELEBAKE_BASE"/foundation/triggers/*; do [ -f "$t" ] || continue; read -r when action 2>/dev/null < "$t"; fnd_expr_render action leaves "$action" | grep -qx handover_act && printf '%s\n' "${t##*/}"; done)
        p=$(for t in $firing; do grep -lx "trigger $t" "$ELEBAKE_BASE"/foundation/policies/* 2>/dev/null; done | sed "s|.*/||" | grep -Fx "${bound:-/}" | head -1)
        gate=$(sed -n "s/^gate //p" "$ELEBAKE_BASE/foundation/policies/${p:-/}" 2>/dev/null)
        printf 'readonly ELV_GATE_LOADER=%s\n' "$(sq "$gate")"
}

#@help _stage_constant_loader_digest1
# @command stage constant loader digest <stage>
# @summary Print readonly ELV_LOADER_DIGEST: sha256 of the stage's signed loader boot/loader.efi.signed (empty without it)
# @group   foundation
# @internal
# @see     stage container render constants
#@end
_stage_constant_loader_digest1() {
        local digest=""
        digest=$(sha256 -q "$ELEBAKE_BASE/stage/$1/boot/loader.efi.signed" 2>/dev/null)
        printf 'readonly ELV_LOADER_DIGEST=%s\n' "$(sq "$digest")"
}

#@help _stage_constant_esp1
# @command stage constant esp <stage>
# @summary Print readonly ELV_ESP: the node of the stage's first medium record without /dev/ (its node IS the ESP partition, what deploy mounts); empty without a medium
# @group   foundation
# @internal
# @see     stage container render constants
#@end
_stage_constant_esp1() {
        local node=""
        node=$(cat "$ELEBAKE_BASE/stage/$1"/media/*/node 2>/dev/null | sed -n 1p)
        printf 'readonly ELV_ESP=%s\n' "$(sq "${node#/dev/}")"
}

#@help _stage_constant_marker1
# @command stage constant marker <stage>
# @summary Print readonly ELV_MARKER_VAR and ELV_MARKER_FILE: the load option the stage's marker record names and the root-side copy of its value (/usr/local/etc/elvboot/marker.<BootXXXX>, placed by stage marker install) that marker_heal_act writes back; both empty without a marker record
# @group   foundation
# @internal
# @see     stage container render constants
# @see     stage marker record
#@end
_stage_constant_marker1() {
        local bootvar=""
        bootvar=$(head -n1 "$ELEBAKE_BASE/stage/$1/marker/bootvar" 2>/dev/null)
        printf 'readonly ELV_MARKER_VAR=%s\n' "$(sq "$bootvar")"
        printf 'readonly ELV_MARKER_FILE=%s\n' "$(sq "${bootvar:+/usr/local/etc/elvboot/marker.$bootvar}")"
}

#@help _stage_constant_verdicts0
# @command stage constant verdicts
# @summary Print the verdict variables a container script appraises into: GATE, GATE_VERDICT, PASSED, FAILED, SKIPPED, DIAG
# @group   foundation
# @internal
# @see     stage container render constants
#@end
_stage_constant_verdicts0() {
        printf 'GATE=""; GATE_VERDICT=""; PASSED=""; FAILED=""; SKIPPED=""; DIAG=""\n'
}

#@help _stage_container_render_state0
# @command stage container render state
# @summary Print the readonly state directory of the real script (ELV_STATE = ELEBAKE_STATE_DB)
# @group   foundation
# @internal
# @env     ELEBAKE_STATE_DB  the target state directory baked into the script
# @see     stage container render mocks
#@end
_stage_container_render_state0() {
        printf 'readonly ELV_STATE=%s\n' "$(sq "${ELEBAKE_STATE_DB}")"
}

#@help _stage_container_render_tools1
# @command stage container render tools <stage>
# @summary Print the tools table of the checkout (earlboot/tools.sh: every external command the catalogs run) as readonly constants with their absolute paths -- the hardening of the generated script in one block
# @group   foundation
# @internal
# @see     stage container render mocks
#@end
_stage_container_render_tools1() {
        sed -n "s/^\([A-Z][A-Z0-9]*\)=\([^ #]*\).*/readonly \1='\2'/p" "$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local/earlboot/tools.sh"
}

#@help ___stage_container_render_mocks3
# @command stage container render mocks <stage> <container> <dump>
# @summary The test-run stand-ins for state and tools: ELV_STATE under the stage's hooks/ (<container>.test.state, removed after the run), the dump path, the mock functions, and per tools.sh entry either a mock by its '# test:' class (kenv/sysctl/kldstat answer from the dump, silent tools return nothing, note tools print 'mock: <args>' on stderr, tee passes through) or its real path. Nothing touches the state directory or the machine
# @group   foundation
# @internal
# @see     stage earlboot test
#@end
___stage_container_render_mocks3() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage mock state '$1' '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage mock dump '$3'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage mock functions"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage mock tools '$1'"
}

#@help _stage_mock_state2
# @command stage mock state <stage> <container>
# @summary Print readonly ELV_STATE for a test run: hooks/<container>.test.state of the stage
# @group   foundation
# @internal
# @see     stage container render mocks
#@end
_stage_mock_state2() {
        printf 'readonly ELV_STATE=%s\n' "$(sq "$ELEBAKE_BASE/stage/$1/hooks/$2.test.state")"
}

#@help _stage_mock_dump1
# @command stage mock dump <dump>
# @summary Print readonly ELV_MOCK_DUMP: the captured kenv dump the mocks answer from
# @group   foundation
# @internal
# @see     stage container render mocks
#@end
_stage_mock_dump1() {
        printf 'readonly ELV_MOCK_DUMP=%s\n' "$(sq "$1")"
}

#@help _stage_mock_functions0
# @command stage mock functions
# @summary Print the mock functions elv_mock_<class> for the classes of tools.sh: kenv, sysctl, kldstat (answer from the dump), silent, note, tee
# @group   foundation
# @internal
# @see     stage container render mocks
#@end
_stage_mock_functions0() {
        printf '%s\n' 'elv_mock_lookup() { /usr/bin/sed -n "s/^$1=\"\(.*\)\"\$/\1/p" "$ELV_MOCK_DUMP" | /usr/bin/head -1; }'
        printf '%s\n' 'elv_mock_kenv() { [ "$1" = -q ] && shift; [ $# -gt 0 ] || { /bin/cat "$ELV_MOCK_DUMP"; return 0; }; /usr/bin/grep -q "^$1=" "$ELV_MOCK_DUMP" || return 1; elv_mock_lookup "$1"; }'
        printf '%s\n' 'elv_mock_sysctl() { [ "$1" = -n ] && shift; /usr/bin/grep -q "^sysctl.$1=" "$ELV_MOCK_DUMP" || return 1; elv_mock_lookup "sysctl.$1"; }'
        printf '%s\n' 'elv_mock_kldstat() { /usr/bin/grep -q "^kldstat.$3=" "$ELV_MOCK_DUMP"; }'
        printf '%s\n' 'elv_mock_silent() { return 1; }'
        printf '%s\n' 'elv_mock_note() { printf "mock: %s\n" "$*" >&2; return 0; }'
        printf '%s\n' 'elv_mock_tee() { /bin/cat; }'
}

#@help _stage_mock_tools1
# @command stage mock tools <stage>
# @summary Print the tools table of the checkout for a test run: an entry with a '# test:<class>' names its mock elv_mock_<class>, an entry without keeps its real path (a class without a mock function is a broken table and fails at the run)
# @group   foundation
# @internal
# @see     stage container render mocks
#@end
_stage_mock_tools1() {
        sed -n "s/^\([A-Z][A-Z0-9]*\)=\([^ #]*\).*# test:\([a-z]*\).*/readonly \1='elv_mock_\3'/p" "$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local/earlboot/tools.sh"
        sed -n "/# test:/!s/^\([A-Z][A-Z0-9]*\)=\([^ #]*\).*/readonly \1='\2'/p" "$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local/earlboot/tools.sh"
}

#@help _stage_container_render_functions_earlboot1
# @command stage container render functions earlboot <stage>
# @summary Print the earlboot catalog sources verbatim (earlboot/policy.sh, earlboot/measure.sh, earlboot/action.sh) -- the functions the bindings reference live in the generated script itself
# @group   foundation
# @internal
# @see     stage earlboot mk
#@end
_stage_container_render_functions_earlboot1() {
        local f=""
        for f in earlboot/policy.sh earlboot/measure.sh earlboot/action.sh; do
                printf '\n# --- %s ---\n' "$f"
                grep -v '^#!/bin/sh' "$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local/$f"
        done
}

#@help _stage_container_render_functions_elvbootd1
# @command stage container render functions elvbootd <stage>
# @summary Print the elvbootd catalog sources verbatim (elvbootd/policy.sh, elvbootd/measure.sh, elvbootd/action.sh, earlboot/measure.sh, earlboot/action.sh) -- the functions the bindings reference live in the generated script itself (earlboot's measure.sh and action.sh inherited)
# @group   foundation
# @internal
# @see     stage elvbootd mk
#@end
_stage_container_render_functions_elvbootd1() {
        local f=""
        for f in elvbootd/policy.sh elvbootd/measure.sh elvbootd/action.sh earlboot/measure.sh earlboot/action.sh; do
                printf '\n# --- %s ---\n' "$f"
                grep -v '^#!/bin/sh' "$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local/$f"
        done
}

#@help __stage_container_render_functions2
# @command stage container render functions <container> <stage>
# @summary The total fallback behind the container-specific function listings (dispatch binds the longer name): an error line
# @group   foundation
# @internal
# @see     stage earlboot mk
#@end
__stage_container_render_functions2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage container render functions: no anchor for container $1'"
}

#@help _stage_container_render_prologue0
# @command stage container render prologue
# @summary Print the one call that runs after the functions and before the phases: elv_prologue, which every container's policy.sh defines
# @group   foundation
# @internal
# @see     stage earlboot mk
#@end
_stage_container_render_prologue0() {
        printf '\nelv_prologue\n'
}

#@help _stage_container_render_footer0
# @command stage container render footer
# @summary Print the closing line of a generated container script (exit 0: a hook never fails its mechanism, findings went through the actions)
# @group   foundation
# @internal
# @see     stage earlboot mk
#@end
_stage_container_render_footer0() {
        printf '\nexit 0\n'
}

#@help ___stage_container_render_phase2
# @command stage container render phase <stage> <phase>
# @summary One bound phase of a generated container script: the phase marker, then per bound policy 'stage policy render <policy>'; an unbound phase renders the marker only
# @group   foundation
# @internal
# @see     stage policy render
#@end
___stage_container_render_phase2() {
        local p="" lines=0
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase render marker '$2'"
        while read -r p; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage policy render '$p'"
                lines=$((lines + 1))
        done 2>/dev/null < "$ELEBAKE_BASE/stage/$1/phases/$2"
        test "$lines" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'phase $2 of stage $1 binds no policy'"
}

#@help _stage_phase_render_marker1
# @command stage phase render marker <phase>
# @summary Print the phase marker line '# ===== phase <phase> =====' (the install checks for it)
# @group   foundation
# @internal
# @see     stage container render phase
#@end
_stage_phase_render_marker1() {
        printf '\n# ===== phase %s =====\n' "$1"
}

#@help ___stage_policy_render1
# @command stage policy render <policy>
# @summary The sh lines of one bound policy: the gate appraisal ('stage gate render'), then per trigger line of the record the binding ('stage trigger render')
# @group   foundation
# @internal
# @see     stage gate render
# @see     stage trigger render
#@end
___stage_policy_render1() {
        local kind="" name=""
        while read -r kind name; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage $kind render '$name'"
        done 2>/dev/null < "$ELEBAKE_BASE/foundation/policies/$1"
}

#@help ___stage_gate_render1
# @command stage gate render <gate>
# @summary The appraisal of one gate: the head (GATE and the empty lists), per claim its measurement and diagnose lines, the verdict
# @group   foundation
# @internal
# @see     stage claim render
#@end
___stage_gate_render1() {
        local claim=""
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage gate render head '$1'"
        while read -r claim; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage claim render '$claim'"
        done 2>/dev/null < "$ELEBAKE_BASE/foundation/gates/$1/claims"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage gate render verdict"
}

#@help _stage_gate_render_head1
# @command stage gate render head <gate>
# @summary Print the head of a gate appraisal: the comment, GATE, and the emptied PASSED/FAILED/SKIPPED/DIAG
# @group   foundation
# @internal
# @see     stage gate render
#@end
_stage_gate_render_head1() {
        printf '# gate %s\nGATE=%s; PASSED=""; FAILED=""; SKIPPED=""; DIAG=""\n' "$1" "$(sq "$1")"
}

#@help _stage_gate_render_verdict0
# @command stage gate render verdict
# @summary Print the verdict line of a gate appraisal: pass when nothing failed and something passed, else fail
# @group   foundation
# @internal
# @see     stage gate render
#@end
_stage_gate_render_verdict0() {
        printf 'if [ -z "$FAILED" ] && [ -n "$PASSED" ]; then GATE_VERDICT=pass; else GATE_VERDICT=fail; fi\n'
}

#@help ___stage_claim_render1
# @command stage claim render <claim>
# @summary The sh lines measuring one claim: the measurement against the expectation ('stage claim render measure'), and the diagnose when the record names one ('stage claim render diagnose')
# @group   foundation
# @internal
# @see     stage gate render
#@end
___stage_claim_render1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage claim render measure '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage claim render diagnose '$1'"
}

#@help _stage_claim_render_measure1
# @command stage claim render measure <claim>
# @summary Print the two lines that measure a claim: _m from its measurement with the expectation's label, _want from the expectation's value, then the PASSED/FAILED bookkeeping
# @group   foundation
# @internal
# @see     stage claim render
#@end
_stage_claim_render_measure1() {
        local measurement="" diagnose="" publish="" expectation="" type="" label="" value=""
        read -r measurement diagnose publish expectation 2>/dev/null < "$ELEBAKE_BASE/foundation/claims/$1"
        read -r type label value 2>/dev/null < "$ELEBAKE_BASE/foundation/expectations/$expectation"
        printf '_m=$(%s %s 2>/dev/null); _want=%s\n' "$measurement" "$(sq "$label")" "$(sq "$value")"
        printf 'if [ -z "$_m" ]; then FAILED="$FAILED %s"; elif [ "$_m" = "$_want" ]; then PASSED="$PASSED %s"; else FAILED="$FAILED %s"; fi\n' "$1" "$1" "$1"
}

#@help __stage_claim_render_diagnose1
# @command stage claim render diagnose <claim>
# @summary The claim names a diagnose ('-' is none): rewrite to 'stage claim render diagnose line', else a comment line (nothing rendered)
# @group   foundation
# @internal
# @see     stage claim render
#@end
__stage_claim_render_diagnose1() {
        local measurement="" diagnose="" rest=""
        read -r measurement diagnose rest 2>/dev/null < "$ELEBAKE_BASE/foundation/claims/$1"
        if test "$diagnose" != -; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage claim render diagnose line '$1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'claim $1 has no diagnose'"
        fi
}

#@help _stage_claim_render_diagnose_line1
# @command stage claim render diagnose line <claim>
# @summary Print the DIAG line of a claim: its diagnose function with the expectation's label, newlines stripped
# @group   foundation
# @internal
# @see     stage claim render diagnose
#@end
_stage_claim_render_diagnose_line1() {
        local measurement="" diagnose="" publish="" expectation="" type="" label="" value=""
        read -r measurement diagnose publish expectation 2>/dev/null < "$ELEBAKE_BASE/foundation/claims/$1"
        read -r type label value 2>/dev/null < "$ELEBAKE_BASE/foundation/expectations/$expectation"
        printf 'DIAG="$DIAG %s=$(%s %s 2>/dev/null | tr -d \\\\n)"\n' "$1" "$diagnose" "$(sq "$label")"
}

#@help _stage_trigger_render1
# @command stage trigger render <trigger>
# @summary Print the binding line of one trigger: if <when>; then <action> "$GATE"; fi -- a composed when as { a && b; }, { a || b; }, ! a, composed actions in order
# @group   foundation
# @internal
# @see     stage policy render
#@end
_stage_trigger_render1() {
        local when="" action=""
        read -r when action 2>/dev/null < "$ELEBAKE_BASE/foundation/triggers/$1"
        printf 'if %s; then %s; fi\n' "$(fnd_expr_render when sh "$when")" "$(fnd_expr_render action sh "$action")"
}

#@help __stage_checkout_exists1
# @command stage checkout exists <stage>
# @summary The stage's checkout holds the catalogs (stand/efi/loader/local of its worktree): a comment line, else an error line
# @group   foundation
# @internal
# @see     stage earlboot mk
#@end
__stage_checkout_exists1() {
        if test -d "$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'stage $1 is checked out'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage $1: no worktree (stage checkout $1 <ref> first)'"
        fi
}

#@help _stage_dump_readable1
# @command stage dump readable <dump>
# @summary The captured dump is an absolute path and readable: one test
# @group   foundation
# @internal
# @see     stage earlboot test
#@end
_stage_dump_readable1() {
        printf '%s\n' "test -r '$1' && test \"\${1#/}\" != '$1'"
}

#@help _stage_container_prepare1
# @command stage container prepare <stage>
# @summary Act terminal: the hooks/ directory of the stage, 0700
# @group   foundation
# @internal
# @see     stage earlboot mk
#@end
_stage_container_prepare1() {
        printf '%s\n' "$MODIFY_DIR_CREATE '$ELEBAKE_BASE/stage/$1/hooks'"
        printf '%s\n' "$MODIFY_FILE_PERMS 0700 '$ELEBAKE_BASE/stage/$1/hooks'"
}

#@help ___stage_hook_install2
# @command stage hook install <stage> <file>
# @summary Install the rendered <file>.new as <file> under the stage's hooks/ (0500), the last line of an mk batch: the render is complete (a phase marker, no render error, sh -n parses it), then it is placed
# @group   foundation
# @internal
# @see     stage earlboot mk
#@end
___stage_hook_install2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage hook rendered '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage hook clean '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage hook parses '$2'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage hook place '$1' '$2'"
}

#@help _stage_hook_rendered1
# @command stage hook rendered <file>
# @summary The rendered <file>.new is there and carries a phase marker (one grep)
# @group   foundation
# @internal
# @see     stage hook install
#@end
_stage_hook_rendered1() {
        printf '%s\n' "test -s '$1.new' && grep -q '^# ===== phase' '$1.new'"
}

#@help _stage_hook_clean1
# @command stage hook clean <file>
# @summary The rendered <file>.new carries no render error (a part that printed an error script instead of text): one negated grep
# @group   foundation
# @internal
# @see     stage hook install
#@end
_stage_hook_clean1() {
        printf '%s\n' "! grep -q '^printf .# Error: ' '$1.new'"
}

#@help _stage_hook_parses1
# @command stage hook parses <file>
# @summary The rendered <file>.new parses (sh -n): a broken catalog source shows here
# @group   foundation
# @internal
# @see     stage hook install
#@end
_stage_hook_parses1() {
        printf '%s\n' "sh -n '$1.new'"
}

#@help _stage_hook_place2
# @command stage hook place <stage> <file>
# @summary Act terminal: move <file>.new to <file>, mode 0500, and say so
# @group   foundation
# @internal
# @see     stage hook install
#@end
_stage_hook_place2() {
        printf '%s\n' "mv '$2.new' '$2' && chmod 0500 '$2'"
        printf '%s\n' "printf '# stage %s: hook written: %s\\n' '$1' '$2' >&2"
}

#@help _stage_hook_test_run3
# @command stage hook test run <stage> <container> <file>
# @summary Run a rendered test script (render mocks in place of state and tools): the render carries no error, a fresh test state dir, sh <file> with its exit code, every file the run left in the test state dir printed with a header, then state dir and script removed
# @group   foundation
# @internal
# @see     stage earlboot test
#@end
_stage_hook_test_run3() {
        local state="$ELEBAKE_BASE/stage/$1/hooks/$2.test.state"
        printf '%s\n' "! grep -q '^printf .# Error: ' '$3'"
        printf '%s\n' "rm -rf '$state' && mkdir -p '$state' && chmod 0700 '$state'"
        printf '%s\n' "sh '$3'; printf '== %s test run of %s: exit %s\\n' '$2' '$1' \"\$?\""
        printf '%s\n' "for x in '$state'/*; do [ -f \"\$x\" ] || continue; printf '== %s\\n' \"\${x##*/}\"; cat \"\$x\"; done"
        printf '%s\n' "rm -rf '$state' '$3'"
}

#@help ___stage_requirements_ensure_earlboot1
# @command stage requirements ensure earlboot <stage>
# @summary The demands of earlboot's bound measurements on the stage's boot tree are met, phase by phase (SYSINIT, MOUNTED): the chain ends in an error line at the first missing demand
# @group   foundation
# @internal
# @see     stage require
#@end
___stage_requirements_ensure_earlboot1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase requirements '$1' SYSINIT require"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase requirements '$1' MOUNTED require"
}

#@help ___stage_requirements_report_earlboot1
# @command stage requirements report earlboot <stage>
# @summary The demands of earlboot's bound measurements on the stage's boot tree, phase by phase (SYSINIT, MOUNTED), each ok (a comment) or MISSING with its remedy (a note)
# @group   foundation
# @internal
# @see     stage require
#@end
___stage_requirements_report_earlboot1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase requirements '$1' SYSINIT demand"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase requirements '$1' MOUNTED demand"
}

#@help ___stage_requirements_ensure_elvbootd1
# @command stage requirements ensure elvbootd <stage>
# @summary The demands of elvbootd's bound measurements on the stage's boot tree are met, phase by phase (STARTUP, PERIODIC, RESUME, MEDIA, SHUTDOWN): the chain ends in an error line at the first missing demand
# @group   foundation
# @internal
# @see     stage require
#@end
___stage_requirements_ensure_elvbootd1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase requirements '$1' STARTUP require"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase requirements '$1' PERIODIC require"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase requirements '$1' RESUME require"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase requirements '$1' MEDIA require"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase requirements '$1' SHUTDOWN require"
}

#@help ___stage_requirements_report_elvbootd1
# @command stage requirements report elvbootd <stage>
# @summary The demands of elvbootd's bound measurements on the stage's boot tree, phase by phase (STARTUP, PERIODIC, RESUME, MEDIA, SHUTDOWN), each ok (a comment) or MISSING with its remedy (a note)
# @group   foundation
# @internal
# @see     stage require
#@end
___stage_requirements_report_elvbootd1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase requirements '$1' STARTUP demand"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase requirements '$1' PERIODIC demand"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase requirements '$1' RESUME demand"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase requirements '$1' MEDIA demand"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase requirements '$1' SHUTDOWN demand"
}

#@help __stage_requirements_ensure2
# @command stage requirements ensure <container> <stage>
# @summary The total fallback behind the container-specific chains (dispatch binds the longer name): an error line
# @group   foundation
# @internal
# @see     stage require
#@end
__stage_requirements_ensure2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage requirements ensure: no anchor for container $1'"
}

#@help __stage_requirements_report2
# @command stage requirements report <container> <stage>
# @summary The total fallback behind the container-specific chains (dispatch binds the longer name): an error line
# @group   foundation
# @internal
# @see     stage require
#@end
__stage_requirements_report2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error 'stage requirements report: no anchor for container $1'"
}

#@help ___stage_phase_requirements3
# @command stage phase requirements <stage> <phase> <require|demand>
# @summary Every policy the phase binds: one 'stage policy requirements <stage> <policy> <verb>'; the verb (require = error line, demand = note) reaches the leaf
# @group   foundation
# @internal
# @see     stage requirements ensure earlboot
#@end
___stage_phase_requirements3() {
        local p="" lines=0
        while read -r p; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage policy requirements '$1' '$p' '$3'"
                lines=$((lines + 1))
        done 2>/dev/null < "$ELEBAKE_BASE/stage/$1/phases/$2"
        test "$lines" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'phase $2 of stage $1 binds no policy: no demand'"
}

#@help __stage_policy_requirements3
# @command stage policy requirements <stage> <policy> <require|demand>
# @summary The policy's gate: rewrite to 'stage gate requirements <stage> <gate> <verb>'
# @group   foundation
# @internal
# @see     stage phase requirements
#@end
__stage_policy_requirements3() {
        local gate; gate=$(sed -n "s/^gate //p" "$ELEBAKE_BASE/foundation/policies/$2" 2>/dev/null)
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage gate requirements '$1' '$gate' '$3'"
}

#@help ___stage_gate_requirements3
# @command stage gate requirements <stage> <gate> <require|demand>
# @summary Every claim the gate lists: its measurement's demands, 'stage measurement requirements <stage> <measurement> <verb>'
# @group   foundation
# @internal
# @see     stage measurement requirements
#@end
___stage_gate_requirements3() {
        local claim="" measurement="" rest="" lines=0
        while read -r claim; do
                read -r measurement rest 2>/dev/null < "$ELEBAKE_BASE/foundation/claims/$claim"
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage measurement requirements '$1' '$measurement' '$3'"
                lines=$((lines + 1))
        done 2>/dev/null < "$ELEBAKE_BASE/foundation/gates/$2/claims"
        test "$lines" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'gate $2 lists no claim: no demand'"
}

#@help ___stage_measurement_requirements3
# @command stage measurement requirements <stage> <measurement> <require|demand>
# @summary The demands a measurement makes on the boot tree, per row '<measurement> <path> <pattern|-> <remedy...>' of template/tbl/boot-tree-demands.tbl: one 'stage boot tree <verb> <stage> <measurement> <path> <pattern> <remedy>'; a measurement without a row demands nothing (a comment)
# @env     ELEBAKE_TEMPLATE_DIR  the template directory (awk programs, tables)
# @group   foundation
# @internal
# @see     stage boot tree require
# @see     stage boot tree demand
#@end
___stage_measurement_requirements3() {
        local m="" path="" pattern="" remedy="" lines=0
        while read -r m path pattern remedy; do
                [ "$m" = "$2" ] || continue
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage boot tree '$3' '$1' '$2' '$path' '$pattern' $(sq "$remedy")"
                lines=$((lines + 1))
        done 2>/dev/null < "$ELEBAKE_TEMPLATE_DIR/tbl/boot-tree-demands.tbl"
        test "$lines" -gt 0 || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment '$2 demands nothing of the boot tree'"
}

#@help __stage_boot_tree_require5
# @command stage boot tree require <stage> <measurement> <path> <pattern|-> <remedy>
# @summary The boot tree of the stage has the file (and the pattern in it, unless '-'): a comment, else an error line naming the remedy (with <stage> filled in)
# @group   foundation
# @internal
# @see     stage measurement requirements
#@end
__stage_boot_tree_require5() {
        local remedy="" with=""
        remedy=$(printf '%s' "$5" | sed "s/<stage>/$1/g")
        test "$4" = - || with=" with $4"
        if test -f "$ELEBAKE_BASE/stage/$1/boot/$3" && { test "$4" = - || grep -qs "$4" "$ELEBAKE_BASE/stage/$1/boot/$3"; }; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment '$2: boot/$3 ok'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" error $(sq "stage $1: $2 demands boot/$3$with -- $remedy")"
        fi
}

#@help __stage_boot_tree_demand5
# @command stage boot tree demand <stage> <measurement> <path> <pattern|-> <remedy>
# @summary The boot tree of the stage has the file (and the pattern in it, unless '-'): a note 'ok', else a note MISSING with the remedy (with <stage> filled in)
# @group   foundation
# @internal
# @see     stage measurement requirements
#@end
__stage_boot_tree_demand5() {
        local remedy=""
        remedy=$(printf '%s' "$5" | sed "s/<stage>/$1/g")
        if test -f "$ELEBAKE_BASE/stage/$1/boot/$3" && { test "$4" = - || grep -qs "$4" "$ELEBAKE_BASE/stage/$1/boot/$3"; }; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log '  $2  boot/$3  ok'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log $(sq "  $2  boot/$3  MISSING -- $remedy")"
        fi
}

#@help ___stage_foundation_make1
# @command stage foundation make <stage>
# @summary Generate foundation.c from the bound policies into the worktree: the stage and its checkout exist, the foundation/ directory is there, then the sections rendered in file order into foundation.c.new (header, macros, secrets, prerequisites, gates, phases, dispatch) and installed as one complete file
# @group   foundation
# @example elebake stage foundation make daily-v1
# @see     stage foundation check
# @see     stage foundation
# @see     stage foundation report
#@end
___stage_foundation_make1() {
        local target="$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local/foundation/foundation.c"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage checkout exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage foundation prepare '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage foundation render header '$1' > '$target.new'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage foundation render macros '$1' >> '$target.new'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage foundation render secrets '$1' >> '$target.new'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage foundation render prerequisites '$1' >> '$target.new'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage foundation render gates '$1' >> '$target.new'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage foundation render phases '$1' >> '$target.new'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage foundation render dispatch '$1' >> '$target.new'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage foundation install '$1'"
}

#@help ___stage_foundation1
# @command stage foundation <stage>
# @summary The foundation batch: check, make, report
# @group   foundation
# @example elebake stage foundation daily-v1
# @see     stage foundation check
# @see     stage foundation make
# @see     stage foundation report
#@end
___stage_foundation1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage foundation check '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage foundation make '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage foundation report '$1'"
}

#@help _stage_foundation_prepare1
# @command stage foundation prepare <stage>
# @summary Act terminal: the foundation/ directory in the stage's checkout
# @group   foundation
# @internal
# @see     stage foundation make
#@end
_stage_foundation_prepare1() {
        printf '%s\n' "$MODIFY_DIR_CREATE '$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local/foundation'"
}

#@help ___stage_foundation_install1
# @command stage foundation install <stage>
# @summary The rendered foundation.c.new is complete (it ends in the dispatcher), then it replaces foundation.c -- a batch that stopped halfway leaves the old file in place
# @group   foundation
# @internal
# @see     stage foundation make
#@end
___stage_foundation_install1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage foundation rendered '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage foundation place '$1'"
}

#@help _stage_foundation_rendered1
# @command stage foundation rendered <stage>
# @summary The rendered foundation.c.new is there and ends in phase_policies() (one grep)
# @group   foundation
# @internal
# @see     stage foundation install
#@end
_stage_foundation_rendered1() {
        printf '%s\n' "test -s '$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local/foundation/foundation.c.new' && grep -q '^phase_policies(enum phase ph)$' '$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local/foundation/foundation.c.new'"
}

#@help _stage_foundation_place1
# @command stage foundation place <stage>
# @summary Act terminal: move foundation.c.new to foundation.c and say so
# @group   foundation
# @internal
# @see     stage foundation install
#@end
_stage_foundation_place1() {
        printf '%s\n' "mv '$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local/foundation/foundation.c.new' '$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local/foundation/foundation.c'"
        emit_note "foundation.c generated -> $ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local/foundation/foundation.c"
}

#@help _stage_foundation_render_header1
# @command stage foundation render header <stage>
# @summary Print the header of foundation.c: license block (ELEBAKE_SPDX, ELEBAKE_COPYRIGHT when set), DETERMINISTIC provenance (checkout ref, worktree HEAD -- never a timestamp) and the includes
# @group   foundation
# @internal
# @env     ELEBAKE_SPDX  license identifier of the generated file's header
# @see     stage foundation make
#@end
_stage_foundation_render_header1() {
        local ref="" head="" spdx="${ELEBAKE_SPDX:-}" copyright="${ELEBAKE_COPYRIGHT:-}"
        ref=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/checkout" 2>/dev/null)
        head=$(git -C "$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local" rev-parse --short HEAD 2>/dev/null)
        test -z "$spdx$copyright" || printf '/*-\n'
        test -z "$spdx" || printf ' * SPDX-License-Identifier: %s\n' "$spdx"
        test -z "$spdx" || test -z "$copyright" || printf ' *\n'
        test -z "$copyright" || printf ' * Copyright (c) %s\n' "$copyright"
        test -z "$spdx$copyright" || printf ' */\n\n'
        printf '/* generated by elebake stage foundation make -- do not edit\n'
        printf ' * stage: %s  checkout: %s (%s) */\n\n' "$1" "${ref:--}" "${head:-unknown}"
        printf '#include "measurement.h"\n#include "claim.h"\n#include "policy.h"\n'
}

#@help ___stage_foundation_render_macros1
# @command stage foundation render macros <stage>
# @summary The baseline macro blocks of foundation.c: every macro record the bound gates' claims reference through a macro expectation, sorted, once -- one 'macro render c <MACRO>' each
# @env     ELEBAKE_TEMPLATE_DIR  the template directory (awk programs, tables)
# @group   foundation
# @internal
# @see     macro render c
#@end
___stage_foundation_render_macros1() {
        local p="" g="" c="" measurement="" diagnose="" publish="" expectation="" type="" label="" value="" stem="" lines=0
        for g in $(cat "$ELEBAKE_BASE/stage/$1"/phases/* 2>/dev/null | sort -u | while read -r p; do sed -n "s/^gate //p" "$ELEBAKE_BASE/foundation/policies/$p"; done | sort -u); do cat "$ELEBAKE_BASE/foundation/gates/$g/claims"; done | sort -u | while read -r c; do
                read -r measurement diagnose publish expectation 2>/dev/null < "$ELEBAKE_BASE/foundation/claims/$c"
                read -r type label value 2>/dev/null < "$ELEBAKE_BASE/foundation/expectations/$expectation"
                test "$type" = macro && awk -v want="$value" -v stem=1 -f "$ELEBAKE_TEMPLATE_DIR/awk/macro-defines.awk" "$ELEBAKE_BASE"/foundation/macros/* 2>/dev/null
        done | sort -u | while read -r stem; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" macro render c '$stem'"
        done
}

#@help _macro_render_c1
# @command macro render c <MACRO>
# @summary Print the #ifdef baseline block of a macro record: guard LOADER_TRUST_<MACRO> (the site.mk -D convention), the defined name (third field, or stem minus _DIGEST plus _EXPECTED), the #else alternative (fourth field, or MEASUREMENT_NONE of the type)
# @group   foundation
# @internal
# @see     stage foundation render macros
# @see     macro show
#@end
_macro_render_c1() {
        local type label defined elsev TYPE
        read -r type label defined elsev 2>/dev/null < "$ELEBAKE_BASE/foundation/macros/$1"
        TYPE=$(printf '%s' "$type" | tr '[:lower:]' '[:upper:]')
        test "${defined:--}" != - || defined="${1%_DIGEST}_EXPECTED"
        test "${elsev:--}" != - || elsev="MEASUREMENT_NONE(\"$label\", MEAS_$TYPE)"
        printf '\n#ifdef LOADER_TRUST_%s\n' "$1"
        printf '#define\t%s\tMEASUREMENT_%s("%s", LOADER_TRUST_%s)\n' "$defined" "$TYPE" "$label" "$1"
        printf '#else\n#define\t%s\t%s\n#endif\n' "$defined" "$elsev"
}

#@help ___stage_foundation_render_secrets1
# @command stage foundation render secrets <stage>
# @summary The passphrase slots of foundation.c: per bound gate (sorted, once) its secret and duress slot blocks
# @group   foundation
# @internal
# @see     gate slot render c
#@end
___stage_foundation_render_secrets1() {
        local g=""
        for g in $(cat "$ELEBAKE_BASE/stage/$1"/phases/* 2>/dev/null | sort -u | while read -r p; do sed -n "s/^gate //p" "$ELEBAKE_BASE/foundation/policies/$p"; done | sort -u); do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate slot render c '$g' secret"
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate slot render c '$g' duress"
        done
}

#@help __gate_slot_render_c2
# @command gate slot render c <gate> <secret|duress>
# @summary The gate carries the slot: rewrite to 'gate slot render c block', else a comment line (nothing rendered)
# @group   foundation
# @internal
# @see     stage foundation render secrets
#@end
__gate_slot_render_c2() {
        if test -f "$ELEBAKE_BASE/foundation/gates/$1/$2"; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate slot render c block '$1' '$2'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'gate $1 has no $2 slot'"
        fi
}

#@help _gate_slot_render_c_block2
# @command gate slot render c block <gate> <secret|duress>
# @summary Print the #ifdef block mapping one slot of the gate to its local macro (the slot minus LOADER_TRUST_), NULL when the build does not define it
# @group   foundation
# @internal
# @see     gate slot render c
#@end
_gate_slot_render_c_block2() {
        local slot=""
        slot=$(sed -n 1p "$ELEBAKE_BASE/foundation/gates/$1/$2" 2>/dev/null)
        printf '\n#ifdef %s\n#define\t%s\t%s\n#else\n#define\t%s\tNULL\n#endif\n' "$slot" "${slot#LOADER_TRUST_}" "$slot" "${slot#LOADER_TRUST_}"
}

#@help __stage_foundation_render_prerequisites1
# @command stage foundation render prerequisites <stage>
# @summary The checkout expects the prerequisites arrays (extern declarations in measurement.h): rewrite to 'stage prerequisites render c', else a comment line
# @group   foundation
# @internal
# @see     stage prerequisites render c
#@end
__stage_foundation_render_prerequisites1() {
        if grep -q "extern const char \*const[[:space:]]*prerequisites_exist" "$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local/measurement.h" 2>/dev/null; then
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites render c '$1'"
        else
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" comment 'the checkout of stage $1 expects no prerequisites arrays'"
        fi
}

#@help ___stage_prerequisites_render_c1
# @command stage prerequisites render c <stage>
# @summary The two prerequisites arrays of foundation.c, exist and verify: the decisions come from the stage's lists, empty lists are legal (N=0)
# @group   foundation
# @internal
# @see     stage prerequisites add
#@end
___stage_prerequisites_render_c1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites render c kind '$1' exist"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage prerequisites render c kind '$1' verify"
}

#@help _stage_prerequisites_render_c_kind2
# @command stage prerequisites render c kind <stage> <exist|verify>
# @summary Print one prerequisites array: its N define, the entries of the stage's list prereqs/<kind> (none is legal), the NULL terminator and the count
# @group   foundation
# @internal
# @see     stage prerequisites render c
#@end
_stage_prerequisites_render_c_kind2() {
        local upper="" n="" entry=""
        upper=$(printf '%s' "$2" | tr '[:lower:]' '[:upper:]')
        n=$(grep -c . "$ELEBAKE_BASE/stage/$1/prereqs/$2" 2>/dev/null)
        printf '\n#define\tLOADER_PREREQUISITES_%s_N\t%s\n' "$upper" "${n:-0}"
        printf 'const char *const prerequisites_%s[] = {\n' "$2"
        grep . "$ELEBAKE_BASE/stage/$1/prereqs/$2" 2>/dev/null | while read -r entry; do
                printf '\t"%s",\n' "$entry"
        done
        printf '\tNULL\n};\n'
        printf 'const unsigned int prerequisites_%s_n = LOADER_PREREQUISITES_%s_N;\n' "$2" "$upper"
}

#@help ___stage_foundation_render_gates1
# @command stage foundation render gates <stage>
# @summary The GATE_DEFINEs of foundation.c: every gate a policy bound to a LOADER phase (enum phase of the checkout's policy.h) references, sorted, once -- one 'gate render c <gate>' each; the gates of the sh containers' phases (SYSINIT, STARTUP, ...) measure with sh providers and never enter the loader
# @group   foundation
# @internal
# @see     gate render c
#@end
___stage_foundation_render_gates1() {
        local g="" ph="" loc="$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local"
        for g in $(for ph in $(sed -n '/enum phase {/,/};/p' "$loc/policy.h" 2>/dev/null | grep -o 'PHASE_[A-Z_]*'); do cat "$ELEBAKE_BASE/stage/$1/phases/$ph" 2>/dev/null; done | sort -u | while read -r p; do sed -n "s/^gate //p" "$ELEBAKE_BASE/foundation/policies/$p"; done | sort -u); do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate render c '$g'"
        done
}

#@help ___gate_render_c1
# @command gate render c <gate>
# @summary GATE_DEFINE as it lands in foundation.c: the head with the slot expressions, one CLAIM per claim the gate lists, the tail
# @group   foundation
# @internal
# @see     claim render c
#@end
___gate_render_c1() {
        local claim=""
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate render c head '$1'"
        while read -r claim; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" claim render c '$claim'"
        done 2>/dev/null < "$ELEBAKE_BASE/foundation/gates/$1/claims"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate render c tail"
}

#@help _gate_render_c_head1
# @command gate render c head <gate>
# @summary Print 'GATE_DEFINE(<gate>, <secret expr>, <duress expr>' -- a slot expression is the local macro (slot minus LOADER_TRUST_) or NULL
# @group   foundation
# @internal
# @see     gate render c
#@end
_gate_render_c_head1() {
        local s="" d=""
        s=$(sed -n 1p "$ELEBAKE_BASE/foundation/gates/$1/secret" 2>/dev/null); s=${s#LOADER_TRUST_}
        d=$(sed -n 1p "$ELEBAKE_BASE/foundation/gates/$1/duress" 2>/dev/null); d=${d#LOADER_TRUST_}
        printf '\nGATE_DEFINE(%s, %s, %s' "$1" "${s:-NULL}" "${d:-NULL}"
}

#@help _gate_render_c_tail0
# @command gate render c tail
# @summary Print the closing ');' of a GATE_DEFINE
# @group   foundation
# @internal
# @see     gate render c
#@end
_gate_render_c_tail0() {
        printf ');\n'
}

#@help _claim_render_c1
# @command claim render c <claim>
# @summary Print one CLAIM(measurement, diagnose|NULL, "publish"|NULL, expectation) continuation line of a GATE_DEFINE; the expectation in C: a macro expectation is its macro, the others MEASUREMENT_<TYPE>("label", value)
# @group   foundation
# @internal
# @see     gate render c
# @see     claim show
#@end
_claim_render_c1() {
        local measurement diagnose publish expectation type label value TYPE exp
        read -r measurement diagnose publish expectation 2>/dev/null < "$ELEBAKE_BASE/foundation/claims/$1"
        read -r type label value 2>/dev/null < "$ELEBAKE_BASE/foundation/expectations/$expectation"
        TYPE=$(printf '%s' "$type" | tr '[:lower:]' '[:upper:]')
        test "$diagnose" != - || diagnose=NULL
        test "$publish" = - && publish=NULL || publish="\"$publish\""
        test "$type" = macro && exp="$value" || exp="MEASUREMENT_$TYPE(\"$label\", $value)"
        printf ',\n    CLAIM(%s, %s, %s, %s)' "$measurement" "$diagnose" "$publish" "$exp"
}

#@help ___stage_foundation_render_phases1
# @command stage foundation render phases <stage>
# @summary The per-phase policy tables of foundation.c, one per phase the checkout's enum phase lists -- 'stage phase render c <stage> <phase>' each
# @group   foundation
# @internal
# @see     stage phase render c
#@end
___stage_foundation_render_phases1() {
        local ph=""
        for ph in $(sed -n '/enum phase {/,/};/p' "$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local/policy.h" 2>/dev/null | grep -o 'PHASE_[A-Z_]*'); do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase render c '$1' '$ph'"
        done
}

#@help ___stage_phase_render_c2
# @command stage phase render c <stage> <phase>
# @summary One phase of foundation.c: per bound policy its POLICY_TABLE_DEFINE ('policy render c'), then the <phase>_policies[] table -- the head, one POLICY(gate, table) row per bound policy ('policy render c row'), the POLICY_END tail; an unbound phase is the empty table
# @group   foundation
# @internal
# @see     policy render c
#@end
___stage_phase_render_c2() {
        local p=""
        grep . "$ELEBAKE_BASE/stage/$1/phases/$2" 2>/dev/null | while read -r p; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" policy render c '$p'"
        done
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase render c head '$2'"
        grep . "$ELEBAKE_BASE/stage/$1/phases/$2" 2>/dev/null | while read -r p; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" policy render c row '$p'"
        done
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase render c tail"
}

#@help _stage_phase_render_c_head1
# @command stage phase render c head <phase>
# @summary Print 'static const struct policy <phase>_policies[] = {' with the phase in lower case without PHASE_
# @group   foundation
# @internal
# @see     stage phase render c
#@end
_stage_phase_render_c_head1() {
        printf '\nstatic const struct policy %s_policies[] = {\n' "$(printf '%s' "${1#PHASE_}" | tr '[:upper:]' '[:lower:]')"
}

#@help _stage_phase_render_c_tail0
# @command stage phase render c tail
# @summary Print the POLICY_END tail of a policy table
# @group   foundation
# @internal
# @see     stage phase render c
#@end
_stage_phase_render_c_tail0() {
        printf '\tPOLICY_END,\n};\n'
}

#@help _policy_render_c1
# @command policy render c <policy>
# @summary Print the policy's binding table: POLICY_TABLE_DEFINE(<policy>_bindings, FIRE(when, action)...) from the policy record and its triggers, one FIRE per trigger in order; a trigger's when and action expressions render as AND/OR/NOT and COMPOSE, the preprocessor turns them into objects (policy.h). The policy name's hyphens become underscores
# @group   foundation
# @internal
# @see     policy render c row
# @see     stage phase render c
# @see     policy show
#@end
_policy_render_c1() {
        local t="" when="" action="" sep=""
        printf '\nPOLICY_TABLE_DEFINE(%s_bindings' "$(printf '%s' "$1" | tr '-' '_')"
        sed -n "s/^trigger //p" "$ELEBAKE_BASE/foundation/policies/$1" 2>/dev/null | while read -r t; do
                read -r when action 2>/dev/null < "$ELEBAKE_BASE/foundation/triggers/$t"
                printf ',\n    FIRE(%s, %s)' "$(fnd_expr_render when c "$when")" "$(fnd_expr_render action c "$action")"
        done
        printf ');\n'
}

#@help _policy_render_c_row1
# @command policy render c row <policy>
# @summary Print the policy's row of a phase table: POLICY(<gate>, <policy>_bindings), tab indented, trailing comma -- the gate from the record, the table 'policy render c' defines
# @group   foundation
# @internal
# @see     policy render c
# @see     stage phase render c
#@end
_policy_render_c_row1() {
        local gate=""
        gate=$(sed -n "s/^gate //p" "$ELEBAKE_BASE/foundation/policies/$1" 2>/dev/null)
        printf '\tPOLICY(%s, %s_bindings),\n' "$gate" "$(printf '%s' "$1" | tr '-' '_')"
}

#@help _stage_foundation_render_dispatch1
# @command stage foundation render dispatch <stage>
# @summary Print phase_policies() of foundation.c: the switch over the checkout's enum phases, the LAST phase as the fall-through return
# @group   foundation
# @internal
# @see     stage foundation make
#@end
_stage_foundation_render_dispatch1() {
        local ph="" last=""
        printf '\nconst struct policy *\nphase_policies(enum phase ph)\n{\n\tswitch (ph) {\n'
        for ph in $(sed -n '/enum phase {/,/};/p' "$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local/policy.h" 2>/dev/null | grep -o 'PHASE_[A-Z_]*'); do
                printf '\tcase %s:\n\t\treturn (%s_policies);\n' "$ph" "$(printf '%s' "${ph#PHASE_}" | tr '[:upper:]' '[:lower:]')"
        done
        last=$(sed -n '/enum phase {/,/};/p' "$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local/policy.h" | grep -o 'PHASE_[A-Z_]*' | tail -1)
        printf '\t}\n\treturn (%s_policies);\n}\n' "$(printf '%s' "${last#PHASE_}" | tr '[:upper:]' '[:lower:]')"
}

#@help ___stage_foundation_report1
# @command stage foundation report <stage>
# @summary Summarize the foundation of a stage: the checkout, per enum phase its bound policies, the referenced gates and the emission target -- notes for the caller
# @group   foundation
# @example elebake stage foundation report daily-v1
# @see     stage foundation make
#@end
___stage_foundation_report1() {
        local ref="" gates="" ph=""
        ref=$(sed -n 1p "$ELEBAKE_BASE/stage/$1/checkout" 2>/dev/null)
        gates=$(for ph in $(sed -n '/enum phase {/,/};/p' "$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local/policy.h" 2>/dev/null | grep -o 'PHASE_[A-Z_]*'); do cat "$ELEBAKE_BASE/stage/$1/phases/$ph" 2>/dev/null; done | sort -u | while read -r p; do sed -n "s/^gate //p" "$ELEBAKE_BASE/foundation/policies/$p"; done | sort -u | tr "\n" " ")
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage check stage '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage checkout exists '$1'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log 'foundation report of stage $1 (checkout: ${ref:--})'"
        for ph in $(sed -n '/enum phase {/,/};/p' "$ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local/policy.h" 2>/dev/null | grep -o 'PHASE_[A-Z_]*'); do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase report '$1' '$ph'"
        done
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log '  gates: ${gates:-(none)}'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log '  target: $ELEBAKE_BASE/stage/$1/work/stand/efi/loader/local/foundation/foundation.c'"
}

#@help ___stage_phase_report2
# @command stage phase report <stage> <phase>
# @summary The phase and its bound policies as notes; an unbound phase says so
# @group   foundation
# @internal
# @see     stage foundation report
#@end
___stage_phase_report2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log '  $2'"
        local p=""
        grep . "$ELEBAKE_BASE/stage/$1/phases/$2" 2>/dev/null | while read -r p; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" policy report '$p'"
        done
        test -s "$ELEBAKE_BASE/stage/$1/phases/$2" || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log '      (no policies bound)'"
}

#@help __stage_report1
# @command stage report <stage> [<container>]
# @summary The one reading view of a stage: every container, every phase, the bound policies, each policy's gate with its claims (measurement, diagnose, publish, expectation) and its triggers in firing order (when -> action). Rewrites to 'stage phase show <stage>'; with a container to 'stage phase show <container> <stage>'
# @group   foundation
# @example elebake stage report daily-v1
# @example elebake stage report daily-v1 earlboot
# @see     stage phase show
# @see     stage foundation report
# @see     policy report
#@end
__stage_report1() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase show '$1'"
}

#@help __stage_report2
# @internal arity-2 of 'stage report' (one container): rewrite to 'stage phase show <container> <stage>'
#@end
__stage_report2() {
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" stage phase show '$2' '$1'"
}

#@help ___policy_report1
# @command policy report <policy>
# @summary A bound policy in the reading view: its gate with every claim (claim render show), then its triggers in firing order (trigger render show)
# @group   foundation
# @internal
# @see     stage report
# @see     policy show
#@end
___policy_report1() {
        local t=""
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log '      policy: $1 (gate $(sed -n "s/^gate //p" "$ELEBAKE_BASE/foundation/policies/$1" 2>/dev/null))'"
        printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" gate claims show '$(sed -n "s/^gate //p" "$ELEBAKE_BASE/foundation/policies/$1" 2>/dev/null)'"
        sed -n 's/^trigger //p' "$ELEBAKE_BASE/foundation/policies/$1" 2>/dev/null | while read -r t; do
                printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" trigger render show '$t'"
        done
        grep -q '^trigger ' "$ELEBAKE_BASE/foundation/policies/$1" 2>/dev/null || printf '%s\n' "\"\$ELEBAKE_CONTEXT_SCRIPT\" log 'policy $1 fires no trigger'"
}
