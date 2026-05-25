## Considerations

Direct `:emacs-rex` was attempted (remove `eval-and-grab-output`, send form as native sexpr, `nil` thread param, single-string `:return`) but **reverted** because it broke package resolution:

- Symbols in the form are interned during wire-read in Slynk's reader package (e.g., `SLYNK-IO-PACKAGE`), not in the target package (`CAD-USER`)
- `eval-and-grab-output` solves this by binding `*package*` before calling `read-from-string` on the form string, so symbols are properly interned in the target package
- SLY/SLIME from Emacs also uses `eval-and-grab-output` (or `eval-string-in-frame`) for user code — not bare `:emacs-rex`

The current code keeps `eval-and-grab-output` with `progn` wrapping and `--no-progn`, matching the `add-progn-wrapping` change. The `direct-form-eval` change can be archived without merging the direct eval approach.
