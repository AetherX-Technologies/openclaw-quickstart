# Runtime Patches

These patches are applied to openclaw dist files to fix bugs.
Must be re-applied after `npm update openclaw`.

## patch-1: ECONNREFUSED as timeout (pi-embedded-helpers-CBr7pp25.js)

Adds "connection error" and "econnrefused" to timeout error patterns so
ECONNREFUSED (proxy down) triggers model fallback instead of hard failure.

File: dist/pi-embedded-helpers-CBr7pp25.js
Change: Add "connection error", "econnrefused" to ERROR_PATTERNS.timeout array

## patch-2: ECONNREFUSED error code as timeout (reply-D-ejYZny.js)

File: dist/reply-D-ejYZny.js  
Change: Add "ECONNREFUSED" to the error code → timeout mapping array

## patch-3: Fix agent-level fallbacks not reaching cli backends (reply-D-ejYZny.js)

When agent has explicit fallbacks override, candidates were added with
enforceAllowlist=true which blocked cli backends (codex-cli) from being
added even though they were in the allowlist. Changed to false so all
configured fallbacks are tried.

File: dist/reply-D-ejYZny.js
Change: addCandidate(resolved.ref, true) → addCandidate(resolved.ref, false)
        in resolveFallbackCandidates loop

## patch-4: Remove --color flag from codex resumeArgs (reply-D-ejYZny.js)

`codex exec resume` does not accept `--color` argument (unlike `codex exec`),
causing all resume-session fallbacks to fail with "unexpected argument '--color'".

File: dist/reply-D-ejYZny.js
Change: Remove `"--color", "never"` from DEFAULT_CODEX_BACKEND.resumeArgs
