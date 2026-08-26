// Filter the list the page already carries.
//
// The markup holds every page, so the page works with no script at all.
// What is added here is filtering as the reader types, and a count of
// what matched.
//
// Nothing is fetched. The index is read from the page itself, so
// opening the page costs one request and searching costs none.
(function () {
  var form = document.querySelector('.search-form');
  var list = document.querySelector('.search-results');
  var count = document.querySelector('.search-count');
  if (!form || !list) return;

  var input = form.querySelector('input[type="search"]');
  var results = Array.prototype.slice.call(list.querySelectorAll('.search-result'));
  var haystacks = results.map(function (item) {
    return item.textContent.toLowerCase();
  });

  function apply(query) {
    var needle = query.trim().toLowerCase();
    var found = 0;
    results.forEach(function (item, index) {
      var hit = !needle || haystacks[index].indexOf(needle) !== -1;
      item.hidden = !hit;
      if (hit) found += 1;
    });
    if (count) {
      count.hidden = !needle;
      count.textContent = count.dataset.template.replace('{count}', String(found));
    }
  }

  // The form submits without the script, so it must not submit with it.
  form.addEventListener('submit', function (event) {
    event.preventDefault();
    apply(input.value);
  });
  input.addEventListener('input', function () {
    apply(input.value);
  });

  var initial = new URLSearchParams(window.location.search).get('q');
  if (initial) {
    input.value = initial;
    apply(initial);
  }
})();
