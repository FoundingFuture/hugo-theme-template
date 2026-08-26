// The theme's stylesheets. stylelint refuses to start without a config,
// so this ships whether or not a theme adds a stylesheet of its own.
//
// chroma.css is generated from a named Chroma style, so it is read for
// contrast by the accessibility gate and not for house style here.
export default {
  extends: ["stylelint-config-standard"],
  rules: {
    "no-descending-specificity": null,
  },
};
