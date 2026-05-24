default:
  @echo "slyc — Slynk CLI client for AI agents"
  @echo ""
  @echo "Usage: just <recipe>"
  @echo ""
  @echo "Recipes:"
  @echo "  run         Run slyc from source: just run -- \"(+ 1 2)\""
  @echo "  build       Compile standalone executable → build/slyc"
  @echo "  test        Run integration tests (requires Slynk server)"
  @echo "  clean       Remove build artifacts"

run *args:
  janet src/main.janet {{args}}

test:
  bash tests/test.sh

build:
  jpm build

clean:
  rm -rf build
