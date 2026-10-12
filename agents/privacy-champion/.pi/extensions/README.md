# Extensions

The Privacy Champion requires **no** host extensions. Every capability it
needs is provided by:

- the deterministic scripts in `../scripts/` (run via shell), and
- the surface catalog in `../data/surface-catalog.json`.

This is deliberate: extensions add supply-chain surface, and a privacy agent
should be inspectable and dependency-light. A host that wishes to add an
extension (for example, a native registry reader, or a GUI-automation helper
for the manual surfaces) may place it here, but it is not required to run the
audit.

If you add an extension, document what it does, what authority it needs, and
why the bundled scripts are insufficient.
