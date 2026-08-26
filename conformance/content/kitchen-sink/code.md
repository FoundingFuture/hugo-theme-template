+++
title = 'Code blocks'
date = 2026-01-17T08:00:00Z
description = 'A page holding fenced code with and without a language, and a highlight shortcode carrying line numbers.'
+++

This page exercises code rendering. A theme styles three cases here, and
a render hook may replace any of them.

<!--more-->

## Fenced with a language

```go
package main

func main() {
	println("hello")
}
```

## Fenced without a language

```
no language tag on this fence
```

## Highlight shortcode

{{< highlight go "linenos=true" >}}
package main

func main() {
	println("numbered")
}
{{< /highlight >}}
