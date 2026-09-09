===============================================================================
Environment System and Safety-First Design
===============================================================================

elebake displays commands instead of executing them. That is intentional and
controlled by interpreter variables, resolved per function (first match wins):

1. Arity-specific pin:   ELEBAKE_INTERPRETER_<function><arity>
2. Arity-agnostic pin:   ELEBAKE_INTERPRETER_<function>
3. Class fallback:       terminals (one underscore)      -> ELEBAKE_TERMINAL_INTERPRETER  (cat)
                         combinators (two underscores)  -> ELEBAKE_COMBINATOR_INTERPRETER
                         batches (three underscores)    -> ELEBAKE_BATCH_COMBINATOR_INTERPRETER

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
