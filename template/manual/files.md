# FILES

`~/.elebake/db`
:   the active database (symlink)

`~/.elebake/<name>/.env/{local,default}/`
:   the layered variable store: overrides (`setenv`) over the installed profile over the shipped templates

`~/.elebake/<name>/.log/YYYY-MM-DD/`
:   per-invocation traces -- the debugging ground truth (`elebake last`)

`~/.elebake/<name>/stage/<stage>/`
:   a stage record: `boot/` (the built tree), `backup/<medium>/<label>/` (backup records), `media/`, `marker/`

`~/.elebake/<name>/provenance/`
:   receipts of every admitted import (the lineage)

`~/.elebake/worktree/`
:   git worktrees of the FreeBSD source; build trees live outside the database

`~/.elebake/bundle/`, `~/.elebake/incoming/`
:   where an exported bundle is handed to the user, and import's scratch area
