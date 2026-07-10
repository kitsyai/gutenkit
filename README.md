# gutenkit

The central asset kit for [guten](https://github.com/kitsyai/guten) — the
templating engine. `gutenkit` is the online tier of guten's Maven/Gradle-style
resolution: the `guten` CLI ships an embedded snapshot, and `guten lib pull`
syncs the latest from here into `~/.kitsy/guten/gutenkit`.

## Namespacing

The repo is namespaced by asset type so it can grow beyond templates:

```
templates/    # guten template bundles (this is what exists today)
# future: themes/, snippets/, fonts/, layouts/ …
```

## Template bundle format

Each template is a directory under `templates/<name>/`:

| File | Required | What |
|---|---|---|
| `template.json` | yes | manifest: `{ name, kind, renderer, extends?, description, parts }` |
| `theme.json` | no | default theme (fonts/colors/…), applied under user overrides |
| `sample.json` | no | sample data for previews / `guten lib show` |
| `*.liquid` etc. | — | part source files referenced from `parts` as `@file` |

`parts` values are either an inline string or `@relative-file`:

```json
{
  "name": "otp",
  "kind": "email",
  "renderer": "liquid",
  "parts": {
    "subject": "{{ subject | default: \"Your verification code\" }}",
    "html": "@html.liquid",
    "text": "@text.liquid"
  }
}
```

`templates/index.json` is the registry (name, kind, path, description).

## Resolution precedence (in the CLI)

`--template` / `--lib-dir` → `~/.kitsy/guten/user/templates/` (your own) →
`~/.kitsy/guten/gutenkit/templates/` (pulled from here) → **embedded snapshot**.

## Use

```
guten lib list
guten lib show otp
guten export --lib invoice -d @data.json -o invoice.pdf
guten export --lib welcome -d @data.json --set theme.accent_color=#0ea5e9 -o welcome.html
```

## Extending

Create your own under `~/.kitsy/guten/user/templates/<name>/` — a `template.json`
with `"extends": "welcome"` inherits the base's parts and overrides only what you
change (plus `theme.json` / `--theme` / `--css` for styling).

## Contributing

Add a bundle under `templates/<name>/`, register it in `templates/index.json`,
keep it brand-neutral (all brand/data supplied at render time), and include a
`sample.json`.

## Releases

Template releases are versioned and published to npm as `@kitsy/gutenkit`.

Install:

```
npm install @kitsy/gutenkit
```

Run:

- `scripts/release.sh major|minor|patch|X.Y.Z`
- `scripts/release.ps1 major|minor|patch|X.Y.Z`

The scripts:

1. bump `package.json` version,
2. commit and push `main`,
3. create `vX.Y.Z`,
4. push the tag.

NPM publish is handled by GitHub Actions when `v*` is pushed.
