## Why

slyc always sends `"CL-USER"` as the package in `:emacs-rex` messages, which overrides the Slynk server's preferred package. When a Slynk server sets a custom default package (via `slynk:*default-package-for-slime-interactions*` or similar), slyc ignores it. The server should decide the evaluation package unless the user explicitly specifies one via `--package`.

## What Changes

- Remove `default-package` constant from `src/main.janet`
- Initialize `pkg` to `nil` in `parse-args` (no default package)
- In `send-eval`: when `pkg` is `nil`, emit unquoted `nil` symbol; when set, emit quoted string as before
- In `send-abort`: change hard-coded `"CL-USER"` to unquoted `nil`
- Update help text: `--package` default changes from `CL-USER` to `(server default)`
- Update `doc/SKILL.md`: `--package` default changes from `CL-USER` to `(server default)`
- Update `README.md`: clarify that `--package` controls the evaluation package, defaults to server default
- **BREAKING**: Forms evaluated without `--package` now run in the server's default package, not `CL-USER`

## Capabilities

### New Capabilities

None — purely a behavior change to the existing package mechanism.

### Modified Capabilities

- `eval-form`: The default evaluation package changes from `CL-USER` to the Slynk server's preferred package. Add a scenario for form evaluation without `--package` (server default). Update the existing "Form in specific package" scenario to clarify it applies only when `--package` is explicitly given.

## Impact

| File | Change |
|------|--------|
| `src/main.janet` | Remove `default-package`, conditionalize `send-eval`, update `send-abort` |
| `doc/SKILL.md` | Update `--package` default in flags table |
| `README.md` | Clarify package behavior in Protocol section |
| `openspec/specs/eval-form/spec.md` | Add default-package scenario, clarify existing scenario |
