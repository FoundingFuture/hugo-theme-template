# search

Publishes a JSON index and a search page. Nothing is fetched from another
host, and the page works with the script blocked.

## What it adds

`layouts/search.html` renders a page listing every page on the site, in
its own markup. `layouts/home.json` publishes the index the script reads.
`assets/js/search.js` filters the list as a query is typed.

The list is the search. A reader with no script gets a working index
rather than an empty box. The script only narrows what is already there,
so opening the page costs one request and searching costs none.

## Using it

The site mounts the component and adds the JSON output to its home page,
which is what publishes the index:

```toml
[outputs]
  home = ["html", "rss", "json"]

[module]
  [[module.mounts]]
    source = "themes/THEME/features/search/layouts"
    target = "layouts"
  [[module.mounts]]
    source = "themes/THEME/features/search/assets"
    target = "assets"
  [[module.mounts]]
    source = "themes/THEME/features/search/i18n"
    target = "i18n"
```

A mount source is read from the root of the site, not from the theme.
`THEME` is the directory the theme was installed into. A site developing
the theme at its own root drops the prefix and mounts
`features/search/layouts`.

A page uses it by setting `layout = 'search'` in its front matter.

## Removing it

Drop the three mounts and the `json` output. A component is turned off by
not mounting it, which is what makes it a component rather than a toggle.

## What it costs

The index holds a title, a link, a summary and up to 1200 characters of
each page. `output/search` fails above 1.5 MB, since a reader downloads
the whole of it. A page carrying `private = true` in its front matter is
left out.
