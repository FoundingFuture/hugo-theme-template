# privacy-embeds

Overrides the embed shortcodes Hugo ships so that a page loads nothing
from another host. Each renders a link, and a poster where the site asks
for one. The reader chooses whether to leave.

## Supported

`youtube` and `vimeo`. Neither fetches anything at build time unless
`params.privacyEmbeds.fetchPosters` is set, and neither fetches anything
at view time.

## Using it

The site mounts the component. Nothing else is needed, because the
component works through shortcode names the content already uses:

```toml
[module]
  [[module.mounts]]
    source = "themes/THEME/features/privacy-embeds/layouts"
    target = "layouts"
  [[module.mounts]]
    source = "themes/THEME/features/privacy-embeds/assets"
    target = "assets"
  [[module.mounts]]
    source = "themes/THEME/features/privacy-embeds/i18n"
    target = "i18n"
```

A mount source is read from the root of the site, not from the theme.
`THEME` is the directory the theme was installed into. A site developing
the theme at its own root drops the prefix.

## Removing it

Drop the three mounts. Hugo's own `youtube` and `vimeo` come back, so
the shortcode names in the content stay portable either way.

## Unsupported

`x` is not overridden, and the fixture does not call it.

Hugo's own implementation is not hermetic. It calls `resources.GetRemote`
against `publish.x.com` while the site is built, so the build depends on
a third party being reachable and willing. That request returns
Forbidden from some networks and is rate limited from others, and
`--panicOnWarning` turns either into a failed build.

A reference build that fails when somebody else's service is having a
bad day is not a reference. Overriding the shortcode here would not help,
because a site that dropped this component would get the unhermetic
original back.

A page that needs a post from X can link to it.
