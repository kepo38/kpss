/**
 * Solution geometry overlay editor → #solution-figure-svg
 * Locked underlay from #figure-svg (stem). Separate from map editor.
 */
(function () {
  "use strict";

  function boot() {
    if (!window.KpssGeometryEditorCore) return;
    var api = window.KpssGeometryEditorCore.create({ kind: "solution" });
    if (!api) return;
    window.KpssGeometrySolutionEditor = api;
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
