/**
 * Solution geometry overlay editor → #solution-figure-svg
 *
 * Owns solution-specific boot/defaults. Drawing logic lives in
 * KpssGeometryEditorCore (kind: "solution"): locked stem underlay,
 * transparent draw surface, overlay → solution_figure_svg.
 */
(function () {
  "use strict";

  var DEFAULT_TOOL = "line";

  function boot() {
    if (!window.KpssGeometryEditorCore || typeof window.KpssGeometryEditorCore.create !== "function") {
      return;
    }
    var root = document.getElementById("geometry-solution-editor");
    var canvas = document.getElementById("geo-sol-canvas");
    if (!root || !canvas) return;

    var api = window.KpssGeometryEditorCore.create({
      kind: "solution",
      rootId: "geometry-solution-editor",
      ids: {
        root: "geometry-solution-editor",
        canvas: "geo-sol-canvas",
        shapes: "geo-sol-shapes",
        underlay: "geo-sol-underlay",
        preview: "geo-sol-preview",
        handles: "geo-sol-handles",
        grid: "geo-sol-grid",
        status: "geo-sol-status",
        color: "geo-sol-color",
        stroke: "geo-sol-stroke",
        strokeVal: "geo-sol-stroke-val",
        angleLabel: "geo-sol-angle-label",
        undo: "geo-sol-undo",
        clear: "geo-sol-clear",
        insert: "geo-sol-insert-placeholder",
        insertStatus: "geo-sol-insert-status",
        help: "geo-sol-help",
        drawSurface: "geo-sol-draw-surface",
      },
    });
    if (!api) return;

    // Reinforce draw-tool default (core also sets this for kind=solution).
    if (typeof api.setTool === "function") {
      api.setTool(DEFAULT_TOOL);
    }

    window.KpssGeometrySolutionEditor = api;
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
