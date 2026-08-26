// Put a copy button on every code block.
//
// The button is added here rather than in the template. A reader with no
// script then sees no control that does nothing. The label comes from
// the script tag, so the words stay in i18n with the rest.
(function () {
  var tag = document.currentScript;
  var label = (tag && tag.dataset.copyLabel) || 'Copy';

  document.querySelectorAll('pre > code').forEach(function (code) {
    var block = code.parentNode;
    var button = document.createElement('button');
    button.type = 'button';
    button.className = 'code-copy';
    button.textContent = label;
    button.addEventListener('click', function () {
      navigator.clipboard.writeText(code.textContent);
    });
    if (getComputedStyle(block).position === 'static') {
      block.style.position = 'relative';
    }
    block.appendChild(button);
  });
})();
