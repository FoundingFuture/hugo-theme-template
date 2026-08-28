# katex

Renders mathematics at build time with the KaTeX that Hugo embeds.
Nothing is fetched from another host, and a page with formulas works
with scripts blocked.

## What it adds

`layouts/_markup/render-passthrough.html` is a passthrough render hook.
Goldmark hands it every span between the math delimiters, and it
returns what `transform.ToMath` makes of it. The default output is
MathML, which Chrome 109, Firefox and Safari render with no stylesheet.

`layouts/_partials/features/katex.html` sits in the `head` slot. It
renders nothing until the site asks for KaTeX markup. Then it links
`assets/css/katex/katex.min.css` on the pages that carry a formula,
and publishes the twenty woff2 fonts the stylesheet names.

A formula KaTeX cannot parse stops the build with the file, line and
column of the span.

## Using it

The site mounts the component and turns the passthrough extension
on. The extension is a markup setting, which a theme cannot set for a
site. The delimiters are the ones the Hugo documentation names:

```toml
[markup.goldmark.extensions.passthrough]
  enable = true
  [markup.goldmark.extensions.passthrough.delimiters]
    block = [['\[', '\]'], ['$$', '$$']]
    inline = [['\(', '\)']]

[module]
  [[module.mounts]]
    source = "themes/THEME/features/katex/layouts"
    target = "layouts"
  [[module.mounts]]
    source = "themes/THEME/features/katex/assets"
    target = "assets"
```

A mount source is read from the root of the site, not from the theme.
`THEME` is the directory the theme was installed into. A site developing
the theme at its own root drops the prefix.

Content then carries `\(E = h \nu\)` inline and `$$ ... $$` or
`\[ ... \]` on its own lines for a display formula. A single dollar
sign is not a delimiter, so a price in prose stays a price.

## Output

`params.katex.output` in the site config selects what
`transform.ToMath` writes. The values are the ones the function takes.

| Value | Markup | Stylesheet |
|---|---|---|
| `mathml` | A `math` element. The default. | None. |
| `htmlAndMathml` | KaTeX spans for the eye, MathML for a screen reader. | Linked on pages with a formula. |
| `html` | KaTeX spans only. | Linked on pages with a formula. |

```toml
[params.katex]
  output = "htmlAndMathml"
```

The stylesheet is KaTeX 0.16.21, the version Hugo 0.165 embeds. It
comes with the woff2 fonts. The woff and ttf fallbacks are left out,
since no current browser requests them. `assets/css/katex/LICENSE` is
its MIT license.

## Removing it

Drop the two mounts. The passthrough extension may stay on. The
delimiters then pass through to the page as written. That is what Hugo
does without a render hook, so the content stays portable either way.

## Unsupported

Macros defined in content. `transform.ToMath` takes a `macros` map,
and a site that needs one adds it to the hook. A macro is then part of
the theme rather than of the content. A page that uses it renders
under this theme only.
