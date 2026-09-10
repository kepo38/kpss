/**
 * Olay grubu formu → sağdaki telefon önizlemesi (uygulamadaki olay kartı).
 * LaTeX / zengin metin: base.html içindeki math-render.js (KpssMathRender).
 */
(function () {
  function val(name) {
    var el = document.querySelector('[name="' + name + '"]');
    return el ? (el.value || "").trim() : "";
  }

  function stemHtml(text) {
    var raw = String(text || "").trim();
    if (!raw) {
      return '<p class="quiz-mock-scenario-placeholder">Ortak olay metni buraya…</p>';
    }
    if (window.KpssMathRender && window.KpssMathRender.examDocumentHtml) {
      return window.KpssMathRender.examDocumentHtml(raw);
    }
    return (
      "<p>" +
      raw
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;") +
      "</p>"
    );
  }

  function sync() {
    var titleEl = document.getElementById("pv-scenario-title");
    var stemEl = document.getElementById("pv-scenario-stem");
    if (!titleEl || !stemEl) return;

    var title = val("title");
    titleEl.textContent = title || "Olay";
    titleEl.classList.toggle("is-empty", !title);

    var stem = val("stem");
    stemEl.innerHTML = stemHtml(stem);
    stemEl.classList.toggle("is-empty", !stem);
  }

  document.addEventListener("DOMContentLoaded", function () {
    if (!document.getElementById("scenario-preview")) return;
    var form = document.getElementById("scenario-form");
    if (!form) return;

    form.addEventListener("input", sync);
    form.addEventListener("change", sync);
    sync();
    window.KpssScenarioPreview = { sync: sync };
  });
})();
