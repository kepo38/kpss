/**
 * Stem geometry editor → #figure-svg only.
 */
(function () {
  "use strict";

  function boot() {
    if (!window.KpssGeometryEditorCore) return;
    var api = window.KpssGeometryEditorCore.create({ kind: "stem" });
    if (!api) return;
    window.KpssGeometryQuestionEditor = api;
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
