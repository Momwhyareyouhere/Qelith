# Flux v1 (custom syntax)

Flux now uses its own syntax style with a function-first shape:
- `root` for the entry function
- `glyph` for other functions
- `emit`, `line`, `call`, `loop`, `done` statements

No Python/C toolchain is used.
- `flux run` uses a built-in interpreter in the `flux` CLI.
- `flux build` uses the assembly seed compiler `flux0.s` + `as/ld`.

## Layout
- `flux` - CLI (`run`, `build`)
- `flux0.s` - assembly seed compiler
- `examples/hello.flux` - v1 syntax example

Bootstrap location:
- hidden bootstrap binary: `~/.local/share/flux/flux0`
- command on PATH: `~/.local/bin/flux`

## Build and run

Install toolchain:

```bash
make build
```

Run a Flux file directly:

```bash
./flux run examples/hello.flux
```

Build only (creates persistent binary):

```bash
./flux build examples/hello.flux
# writes binary at examples/hello (default: same path without .flux)
```

Or specify output:

```bash
./flux build examples/hello.flux build/hello
```

`flux run` supports these v1 statements:
- `emit "text\n".`
- `line.`
- `call function_name.`
- `loop N call function_name.`
- `done N.`

Function blocks:
- `root name [ ... ]` (exactly one root)
- `glyph name [ ... ]` (any number)

`flux build` compiles with `flux0` and currently supports the build subset:
- first string literal used as output bytes
- `done N.` for exit code

Expected output:

```text
hello from flux
```

## Make shortcut

```bash
make run
```

## Releases

Build release artifacts locally:

```bash
make dist
```

Outputs:
- `dist/flux-linux-x86_64.tar.gz`
- `dist/install-latest.sh`

Automated GitHub release:
- Workflow: `.github/workflows/release.yml`
- Trigger: push a tag like `v0.1.0`
- It uploads the two files above to the GitHub Release.

Tag/publish example:

```bash
git tag v0.1.0
git push origin v0.1.0
```

## Auto installer

Users can install latest release with:

```bash
curl -fsSL https://raw.githubusercontent.com/OWNER/REPO/main/scripts/install-latest.sh | bash -s -- OWNER/REPO
```

What it does:
- fetches latest GitHub release
- downloads `flux-linux-x86_64.tar.gz`
- installs `flux` to `~/.local/bin/flux`
- installs hidden bootstrap to `~/.local/share/flux/flux0`

## Releases website

Static site file:
- `site/index.html`

Set your repo in that file:
- change `const REPO = "OWNER/REPO";` to your real repo

Deploy:
- Workflow: `.github/workflows/pages.yml`
- Enable GitHub Pages in repo settings (source: GitHub Actions)

## Syntax example

```flux
glyph greet [
    emit "hello from flux\n".
]

root main [
    loop 1 call greet.
    done 0.
]
```
