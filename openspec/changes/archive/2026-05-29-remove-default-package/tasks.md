## 1. Core Code Changes

- [x] 1.1 Remove `default-package` constant from `src/main.janet`
- [x] 1.2 Change `(var pkg default-package)` to `(var pkg nil)` in `parse-args`
- [x] 1.3 Add conditional in `send-eval`: emit unquoted `nil` when pkg is nil, quoted string when set
- [x] 1.4 Change `send-abort` to use unquoted `nil` instead of `"CL-USER"`
- [x] 1.5 Update help text: change `--package` default from `CL-USER` to `(server default)`

## 2. Documentation Updates

- [x] 2.1 Update `doc/SKILL.md`: change `--package` default in flags table from `CL-USER` to `(server default)`
- [x] 2.2 Update `README.md`: clarify in Protocol section that `--package` defaults to server default
- [x] 2.3 Update `~/.config/opencode/skills/slyc/SKILL.md` to reflect the new default
