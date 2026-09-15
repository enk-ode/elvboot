# help-render.awk -- the generated help: reads every #@help ... #@end block of the sources
# (fed on stdin, concatenated) and renders one of four modes:
#   mode=overview            grouped command summaries (elebake help)
#   mode=query target=...    detail of an exact command, a group, or a prefix match
#   mode=group  target=...   one group
#   mode=manpage             markdown COMMANDS sections (help manual)
#   mode=complete target=... candidates for the word under the cursor (elebake complete):
#                            target = the words typed so far joined by \037, the last one
#                            the (possibly empty) word being completed. Emits "word <w>"
#                            for literal command words (already filtered by that prefix)
#                            and "src <source> [<ctx>]" for placeholders; complete_values()
#                            in include/help.sh turns a source into values. ctxname names
#                            the placeholder whose typed word is passed as <ctx> (stage).
# ch/cc/cg/cr carry the ANSI colours (empty when ELEBAKE_DISPLAY_ANSI is 0).
# Tags: @command @summary @group @param @option @env @returns @example @see @internal
# @completion <placeholder> <source> (per command); @defcompletion <placeholder> <source>
# in a free-standing block is the table every usage placeholder resolves through;
# @defgroup <id> <title> with @order and body lines define a group; @topic adds prose to a group.
function trim(s){ sub(/^[ \t]+/,"",s); sub(/[ \t]+$/,"",s); return s }
function pathof(u,  p){ p=u; sub(/[ \t]*[<[].*$/,"",p); return trim(p) }
function mesc(s){ gsub(/</,"\\<",s); gsub(/>/,"\\>",s); gsub(/\|/,"\\|",s); return s }
# --- completion helpers ---
# cand: emit one candidate line once; literal words are filtered by the
# prefix under the cursor (an empty prefix matches everything).
function cand(kind, v, pre,   key){
	if (kind=="word" && pre!="" && index(v, pre)!=1) return
	key=kind " " v; if (key in seen) return; seen[key]=1; print key }
# tokens: a usage line as argument tokens, brackets stripped:
# "dump [<strategy> [<stage>|all]]" -> dump, <strategy>, <stage>|all
function tokens(u, t,   n, i, x, k){ n=split(u, raw, " "); k=0
	for(i=1;i<=n;i++){ x=raw[i]; gsub(/[\[\]]/,"",x); if(x!="") t[++k]=x } return k }
# isph: is <nm> a placeholder of command p? The table decides - a name with
# a @completion/@defcompletion source is a placeholder, anything else in
# <...> is a literal alternative (<exist|verify>, <path|->, <stage>|all).
function isph(p, nm){ return ((p SUBSEP nm) in ccomp) || (nm in defc) }
function srcof(p, nm){ return ((p SUBSEP nm) in ccomp) ? ccomp[p,nm] : defc[nm] }
# accepts: does a typed word satisfy a usage token? A placeholder part
# accepts every word, a literal part only itself. Only a token written
# with <...> can hold placeholders: a bare command word is literal even
# when a placeholder of the same name exists (stage, dump).
function accepts(p, t, v,   n, a, parts, nm, br){ n=split(t, parts, "|"); br=(t ~ /</)
	for(a=1;a<=n;a++){ nm=parts[a]; gsub(/[<>]/,"",nm); if ((br && isph(p,nm)) || nm==v) return 1 } return 0 }
# candidates_for: what a usage token offers at the cursor - literal parts as
# words, placeholder parts as their source (command-path expands to the
# command words right here). literalonly: after "help", only paths.
function candidates_for(p, t, pre, literalonly, ctx,   n, a, parts, nm, src, br){ n=split(t, parts, "|"); br=(t ~ /</)
	for(a=1;a<=n;a++){
		nm=parts[a]; gsub(/[<>]/,"",nm)
		if (!(br && isph(p,nm))) { cand("word", nm, pre); continue }
		if (literalonly) continue
		src=srcof(p,nm)
		if (src=="command-path") { command_words(pre); continue }
		cand("src", src (ctx!="" ? " " ctx : ""), "") } }
# command_words: what "help <...>" completes to - the first words of every
# command path, the group ids and the concept topics.
function command_words(pre,   pp, f, b){
	for(pp in cu){ if (chid[pp]) continue; f=pp; sub(/ .*/,"",f); cand("word", f, pre) }
	for(b=1;b<=ndg;b++) cand("word", dgall[b], pre)
	cand("word","environment",pre) }
# complete_pass: match every usage against the typed words from index
# "from" on and collect the candidates at the cursor.
function complete_pass(from, n, literalonly,   p, k, ok, i, j, ctx, nm, parts, a, np){
	for (p in cu) {
		if (chid[p]) continue
		k=tokens(cu[p], tok); ok=1; ctx=""
		for(i=from;i<n;i++){ j=i-from+1
			if (j>k || !accepts(p, tok[j], wd[i])) { ok=0; break }
			if (ctxname!="" && tok[j] ~ /</) { np=split(tok[j], parts, "|")
				for(a=1;a<=np;a++){ nm=parts[a]; gsub(/[<>]/,"",nm); if (nm==ctxname && isph(p,nm)) ctx=wd[i] } } }
		j=n-from+1
		if (ok && j<=k) candidates_for(p, tok[j], cur, literalonly, ctx) } }
BEGIN{ seq=0 }
/^#@help/ { inblk=1; kind=""; usage=""; summary=""; ret=""; body=""; internal=0;
gc=0; pc=0; ec=0; sc=0; vc=0; xc=0; dgid=""; dgtitle=""; dgord=999; topic="";
next }
inblk && /^#@end$/ {
        inblk=0
        if (kind=="command") {
                p=pathof(usage); cu[p]=usage; cs[p]=summary; cr_[p]=ret; cord[p]=(++seq); chid[p]=internal
                cnp[p]=pc; for(i=1;i<=pc;i++) cp[p,i]=prm[i]
                cne[p]=ec; for(i=1;i<=ec;i++) cex[p,i]=exs[i]
                cns[p]=sc; for(i=1;i<=sc;i++) cse[p,i]=seer[i]
                cnv[p]=vc; for(i=1;i<=vc;i++) cv[p,i]=env[i]
                for(i=1;i<=xc;i++){ nm=cmpl[i]; sub(/[ \t].*$/,"",nm); src=cmpl[i]; sub(/^[^ \t]+[ \t]+/,"",src); ccomp[p,nm]=src }
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
else if(name=="completion"){cmpl[++xc]=val}
else if(name=="defcompletion"){kind="defcompletion"; nm=val; sub(/[ \t].*$/,"",nm); src=val; sub(/^[^ \t]+[ \t]+/,"",src); defc[nm]=src}
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
# complete mode: the normal pass matches every usage against the typed
# words; after "help" a second, literal-only pass completes command paths
# (and right after "help" also the group ids and topics).
if (mode=="complete") {
	n=split(target, wd, "\037"); if (n==0) { n=1; wd[1]="" }
	cur=wd[n]
	complete_pass(1, n, 0)
	if (wd[1]=="help" && n>=2) { if (n==2) command_words(cur); complete_pass(2, n, 1) }
	exit 0
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
