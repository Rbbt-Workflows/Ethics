/* Global htmx */

(function () {
  // Attach CSRF token to all HTMX requests
  document.body.addEventListener("htmx:configRequest", function (evt) {
    var token = document.querySelector('meta[name="csrf-token"]');
    if (token) {
      evt.detail.headers["X-CSRF-Token"] = token.content;
    }

    var script_name_obj = document.querySelector('meta[name="script_name"]');
    var script_name = null;
    if (script_name_obj){
        script_name = script_name_obj.content
        if (script_name == ""){
            script_name = null
        }
    }

    if (script_name && evt.detail.path && evt.detail.path.startsWith("/") && ! evt.detail.path.startsWith(script_name)) {
        evt.detail.path = script_name + '/'  + evt.detail.path;
    }
  });

  // Utilities to lazy-load scripts/styles
  function loadScriptOnce(src) {
    return new Promise(function (resolve) {
      if (document.querySelector('script[src="' + src + '"]')) return resolve();
      var s = document.createElement("script");
      s.src = src;
      s.onload = resolve;
      document.head.appendChild(s);
    });
  }
  function loadCSSOnce(href) {
    return new Promise(function (resolve) {
      if (document.querySelector('link[href="' + href + '"]')) return resolve();
      var l = document.createElement("link");
      l.rel = "stylesheet";
      l.href = href;
      l.onload = resolve;
      document.head.appendChild(l);
    });
  }

  async function initMarkdownEditors(root) {
    var areas = (root || document).querySelectorAll("textarea[data-markdown-editor]");
    if (areas.length === 0) return;

    await loadCSSOnce("https://unpkg.com/easymde/dist/easymde.min.css");
    await loadScriptOnce("https://unpkg.com/easymde/dist/easymde.min.js");

    areas.forEach(function (ta) {
      if (ta._easymde) return;
      var e = new window.EasyMDE({
        element: ta,
        autofocus: ta.hasAttribute("data-autofocus"),
        spellChecker: false,
        status: false,
        minHeight: "200px",
        renderingConfig: { singleLineBreaks: false, codeSyntaxHighlighting: true },
        hideIcons: ["guide", "side-by-side", "fullscreen"],
        showIcons: ["code", "table"]
      });
      ta._easymde = e;
    });
  }

  document.addEventListener("DOMContentLoaded", function () {
    initMarkdownEditors(document);
  });

  document.body.addEventListener("htmx:afterSwap", function (evt) {
    initMarkdownEditors(evt.target);
  });

  // Simple toast mechanism
  window.toast = function (msg) {
    var t = document.createElement("div");
    t.className = "fixed bottom-4 right-4 bg-slate-900 text-white shadow-lg rounded px-3 py-2 text-sm";
    t.textContent = msg;
    document.body.appendChild(t);
    setTimeout(function () {
      t.classList.add("opacity-0");
      setTimeout(function () { t.remove(); }, 300);
    }, 2000);
  };

  tailwind.config = {
      theme: {
          extend: {
              fontFamily: { sans: ['Inter', 'ui-sans-serif', 'system-ui'] }
          }
      }
  }

})();
