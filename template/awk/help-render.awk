# help-render.awk -- the generated help: reads every #@help ... #@end block of the sources
# (fed on stdin, concatenated) and renders one of four modes:
#   mode=overview            grouped command summaries (elebake help)
#   mode=query target=...    detail of an exact command, a group, or a prefix match
#   mode=group  target=...   one group
#   mode=manpage             markdown COMMANDS sections (help manual)
# ch/cc/cg/cr carry the ANSI colours (empty when ELEBAKE_DISPLAY_ANSI is 0).
# Tags: @command @summary @group @param @option @env @returns @example @see @internal;
# @defgroup <id> <title> with @order and body lines define a group; @topic adds prose to a group.
function trim(s){ sub(/^[ \t]+/,"",s); sub(/[ \t]+$/,"",s); return s }
function pathof(u,  p){ p=u; sub(/[ \t]*[<[].*$/,"",p); return trim(p) }
function mesc(s){ gsub(/</,"\\<",s); gsub(/>/,"\\>",s); gsub(/\|/,"\\|",s); return s }
BEGIN{ seq=0 }
/^#@help/ { inblk=1; kind=""; usage=""; summary=""; ret=""; body=""; internal=0;
gc=0; pc=0; ec=0; sc=0; vc=0; dgid=""; dgtitle=""; dgord=999; topic="";
next }
inblk && /^#@end$/ {
        inblk=0
        if (kind=="command") {
                p=pathof(usage); cu[p]=usage; cs[p]=summary; cr_[p]=ret; cord[p]=(++seq); chid[p]=internal
                cnp[p]=pc; for(i=1;i<=pc;i++) cp[p,i]=prm[i]
                cne[p]=ec; for(i=1;i<=ec;i++) cex[p,i]=exs[i]
                cns[p]=sc; for(i=1;i<=sc;i++) cse[p,i]=seer[i]
                cnv[p]=vc; for(i=1;i<=vc;i++) cv[p,i]=env[i]
                if (!internal) for(i=1;i<=gc;i++){ g=grp[i]; gmn[g]++; gm[g,gmn[g]]=p }
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
else if(name=="internal"){internal=1; if (kind=="") kind="internal"}
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
        nf=0; for(p in cu) if (index(p, target " ")==1 && !chid[p]) { nf++; fam[nf]=p }
        if (nf>0){ for(a=2;a<=nf;a++){ k=fam[a]; b=a-1; while(b>=1 && cord[fam[b]]>cord[k]){ fam[b+1]=fam[b]; b-- } fam[b+1]=k }
        print ""; print ch "Family:" cr; for(i=1;i<=nf;i++){ p=fam[i]; pad=w-length("elebake " cu[p]); s=sprintf("%-"pad"s",""); print "  " cc "elebake " cu[p] cr s cg cs[p] cr } }
        exit 0
}
if (mode=="prefix") {
        n=0; for(p in cu) if (index(p, target)==1 && !chid[p]) n++
        if (n==0) { print "No help for: " target; exit 1 }
        for(p in cu) if (index(p, target)==1 && !chid[p]) { pad=w-length("elebake " cu[p]); s=sprintf("%-"pad"s",""); print "  " cc "elebake " cu[p] cr s cg cs[p] cr }
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
