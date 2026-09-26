/**
 * Panel geometri şekil editörü.
 * Çizimleri #figure-svg alanına yazar; telefon önizlemesi mevcut sync ile güncellenir.
 */
(function () {
  "use strict";

  var root = document.getElementById("geometry-question-editor");
  if (!root) return;

  var canvas = document.getElementById("geo-canvas");
  var shapesLayer = document.getElementById("geo-shapes");
  var previewLayer = document.getElementById("geo-preview");
  var gridLayer = document.getElementById("geo-grid");
  var figureField = document.getElementById("figure-svg");
  var statusEl = document.getElementById("geo-status");
  var helpEl = document.getElementById("geo-help");
  var colorInput = document.getElementById("geo-color");
  var strokeInput = document.getElementById("geo-stroke");
  var strokeVal = document.getElementById("geo-stroke-val");
  var angleLabelInput = document.getElementById("geo-angle-label");

  var VB_W = 400;
  var VB_H = 320;
  var tool = "select";
  var shapes = [];
  var draftPoints = [];
  var dragStart = null;
  var selectedId = null;

  function setStatus(msg) {
    if (statusEl) statusEl.textContent = msg || "";
  }

  function setHelp(msg) {
    if (helpEl) helpEl.textContent = msg || "";
  }

  function color() {
    return (colorInput && colorInput.value) || "#E8C87A";
  }

  function strokeW() {
    return parseFloat((strokeInput && strokeInput.value) || "2") || 2;
  }

  function angleLabel() {
    var v = (angleLabelInput && angleLabelInput.value || "").trim();
    return v || "1";
  }

  function uid() {
    return "g" + Date.now().toString(36) + Math.random().toString(36).slice(2, 6);
  }

  function svgPoint(evt) {
    var pt = canvas.createSVGPoint();
    pt.x = evt.clientX;
    pt.y = evt.clientY;
    var ctm = canvas.getScreenCTM();
    if (!ctm) return { x: 0, y: 0 };
    var p = pt.matrixTransform(ctm.inverse());
    return {
      x: Math.max(0, Math.min(VB_W, p.x)),
      y: Math.max(0, Math.min(VB_H, p.y)),
    };
  }

  function dist(a, b) {
    var dx = a.x - b.x;
    var dy = a.y - b.y;
    return Math.sqrt(dx * dx + dy * dy);
  }

  function mid(a, b) {
    return { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 };
  }

  function angleAt(vertex, a, b) {
    var a1 = Math.atan2(a.y - vertex.y, a.x - vertex.x);
    var a2 = Math.atan2(b.y - vertex.y, b.x - vertex.x);
    return { a1: a1, a2: a2 };
  }

  function buildGrid() {
    if (!gridLayer) return;
    gridLayer.innerHTML = "";
    var step = 20;
    var i;
    for (i = step; i < VB_W; i += step) {
      gridLayer.appendChild(el("line", { x1: i, y1: 0, x2: i, y2: VB_H }));
    }
    for (i = step; i < VB_H; i += step) {
      gridLayer.appendChild(el("line", { x1: 0, y1: i, x2: VB_W, y2: i }));
    }
  }

  function el(name, attrs, text) {
    var node = document.createElementNS("http://www.w3.org/2000/svg", name);
    Object.keys(attrs || {}).forEach(function (k) {
      node.setAttribute(k, attrs[k]);
    });
    if (text != null) node.textContent = text;
    return node;
  }

  function renderShape(s) {
    var g = el("g", { "data-id": s.id, fill: "none", stroke: s.color, "stroke-width": s.stroke });
    if (s.kind === "line") {
      g.appendChild(el("line", { x1: s.a.x, y1: s.a.y, x2: s.b.x, y2: s.b.y, "stroke-linecap": "round" }));
    } else if (s.kind === "circle") {
      g.appendChild(el("circle", { cx: s.c.x, cy: s.c.y, r: s.r }));
    } else if (s.kind === "square") {
      g.appendChild(el("rect", { x: s.x, y: s.y, width: s.size, height: s.size }));
    } else if (s.kind === "triangle") {
      var pts = [s.a, s.b, s.c].map(function (p) { return p.x + "," + p.y; }).join(" ");
      g.appendChild(el("polygon", { points: pts }));
    } else if (s.kind === "semicircle") {
      var r = dist(s.a, s.b) / 2;
      var m = mid(s.a, s.b);
      var sweep = s.sweep || 1;
      var d =
        "M " + s.a.x + " " + s.a.y +
        " A " + r + " " + r + " 0 0 " + sweep + " " + s.b.x + " " + s.b.y +
        " L " + s.a.x + " " + s.a.y + " Z";
      g.appendChild(el("path", { d: d, fill: "none" }));
      g.appendChild(el("line", { x1: s.a.x, y1: s.a.y, x2: s.b.x, y2: s.b.y, "stroke-linecap": "round" }));
      // center mark optional
      void m;
    } else if (s.kind === "angle") {
      g.appendChild(el("line", { x1: s.v.x, y1: s.v.y, x2: s.a.x, y2: s.a.y, "stroke-linecap": "round" }));
      g.appendChild(el("line", { x1: s.v.x, y1: s.v.y, x2: s.b.x, y2: s.b.y, "stroke-linecap": "round" }));
      var an = angleAt(s.v, s.a, s.b);
      var rad = Math.min(28, dist(s.v, s.a) * 0.35, dist(s.v, s.b) * 0.35);
      var large = 0;
      var delta = an.a2 - an.a1;
      while (delta <= -Math.PI) delta += Math.PI * 2;
      while (delta > Math.PI) delta -= Math.PI * 2;
      if (Math.abs(delta) > Math.PI) large = 1;
      var sweep = delta >= 0 ? 1 : 0;
      var p1 = { x: s.v.x + rad * Math.cos(an.a1), y: s.v.y + rad * Math.sin(an.a1) };
      var p2 = { x: s.v.x + rad * Math.cos(an.a2), y: s.v.y + rad * Math.sin(an.a2) };
      var ad =
        "M " + p1.x + " " + p1.y +
        " A " + rad + " " + rad + " 0 " + large + " " + sweep + " " + p2.x + " " + p2.y;
      g.appendChild(el("path", { d: ad, fill: "none" }));
      var bis = an.a1 + delta / 2;
      var lx = s.v.x + (rad + 14) * Math.cos(bis);
      var ly = s.v.y + (rad + 14) * Math.sin(bis);
      g.appendChild(el("text", {
        x: lx,
        y: ly,
        fill: s.color,
        stroke: "none",
        "font-size": "14",
        "font-family": "serif",
        "text-anchor": "middle",
        "dominant-baseline": "middle",
      }, s.label || "1"));
    } else if (s.kind === "radius") {
      g.appendChild(el("circle", { cx: s.c.x, cy: s.c.y, r: s.r }));
      g.appendChild(el("line", {
        x1: s.c.x, y1: s.c.y, x2: s.e.x, y2: s.e.y, "stroke-linecap": "round",
      }));
      var lm = mid(s.c, s.e);
      g.appendChild(el("text", {
        x: lm.x + 8,
        y: lm.y - 6,
        fill: s.color,
        stroke: "none",
        "font-size": "13",
        "font-family": "serif",
      }, s.label || "r"));
    }
    if (selectedId === s.id) {
      g.setAttribute("stroke-opacity", "1");
      g.style.filter = "drop-shadow(0 0 3px rgba(94,234,212,0.7))";
    }
    return g;
  }

  function redraw() {
    shapesLayer.innerHTML = "";
    shapes.forEach(function (s) {
      shapesLayer.appendChild(renderShape(s));
    });
    exportToField();
  }

  function clearPreview() {
    previewLayer.innerHTML = "";
  }

  function exportSvgString() {
    var parts = [
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + VB_W + " " + VB_H + '">',
    ];
    shapes.forEach(function (s) {
      var node = renderShape(s);
      // strip selection styling
      node.removeAttribute("style");
      parts.push(node.outerHTML);
    });
    parts.push("</svg>");
    return parts.join("");
  }

  function exportToField() {
    if (!figureField) return;
    if (!shapes.length) {
      // Boş çizimde mevcut elle yapıştırılmış SVG'yi silme.
      if (figureField.dataset.geoOwned === "1") {
        figureField.value = "";
        figureField.dataset.geoOwned = "0";
        triggerPreview();
      }
      return;
    }
    figureField.value = exportSvgString();
    figureField.dataset.geoOwned = "1";
    triggerPreview();
  }

  function triggerPreview() {
    if (figureField) {
      figureField.dispatchEvent(new Event("input", { bubbles: true }));
    }
    if (window.KpssQuestionPreview && typeof window.KpssQuestionPreview.sync === "function") {
      try { window.KpssQuestionPreview.sync(); } catch (e) {}
    }
  }

  function setTool(next) {
    tool = next;
    draftPoints = [];
    dragStart = null;
    clearPreview();
    root.querySelectorAll(".geo-tool").forEach(function (btn) {
      btn.setAttribute("aria-pressed", btn.getAttribute("data-tool") === tool ? "true" : "false");
    });
    var helps = {
      select: "Şekil seçmek için tıklayın; Sil ile seçileni kaldırın (Delete).",
      line: "Çizgi: basılı tutup sürükleyin.",
      circle: "Çember: merkezden kenara sürükleyin.",
      square: "Kare: köşeden sürükleyin.",
      triangle: "Üçgen: 3 köşeye sırayla tıklayın.",
      semicircle: "Yarım daire: çapın iki ucunu sürükleyin.",
      angle: "Açı: önce tepe, sonra iki ışın ucu (3 tık). Sayı kutusu etiketi belirler.",
      radius: "Yarıçap: merkezden çevreye sürükleyin (çember + r).",
    };
    setHelp(helps[tool] || "");
    setStatus(tool === "select" ? "" : "Araç: " + tool);
  }

  function addShape(s) {
    shapes.push(s);
    selectedId = s.id;
    redraw();
    setStatus("Eklendi (" + shapes.length + ")");
  }

  function undo() {
    if (!shapes.length) return;
    shapes.pop();
    selectedId = shapes.length ? shapes[shapes.length - 1].id : null;
    redraw();
  }

  function clearAll() {
    if (!shapes.length) return;
    if (!window.confirm("Tüm çizilen şekiller silinsin mi?")) return;
    shapes = [];
    selectedId = null;
    redraw();
  }

  function hitTest(p) {
    for (var i = shapes.length - 1; i >= 0; i--) {
      var s = shapes[i];
      if (s.kind === "line" && distToSegment(p, s.a, s.b) < 8) return s.id;
      if (s.kind === "circle" || s.kind === "radius") {
        var d = Math.abs(dist(p, s.c) - s.r);
        if (d < 8 || dist(p, s.c) < 8) return s.id;
      }
      if (s.kind === "square") {
        if (p.x >= s.x - 4 && p.x <= s.x + s.size + 4 && p.y >= s.y - 4 && p.y <= s.y + s.size + 4) {
          return s.id;
        }
      }
      if (s.kind === "triangle") {
        if (pointInTriangle(p, s.a, s.b, s.c) || dist(p, s.a) < 8 || dist(p, s.b) < 8 || dist(p, s.c) < 8) {
          return s.id;
        }
      }
      if (s.kind === "angle" && (dist(p, s.v) < 12 || distToSegment(p, s.v, s.a) < 8 || distToSegment(p, s.v, s.b) < 8)) {
        return s.id;
      }
      if (s.kind === "semicircle" && (distToSegment(p, s.a, s.b) < 8 || Math.abs(dist(p, mid(s.a, s.b)) - dist(s.a, s.b) / 2) < 10)) {
        return s.id;
      }
    }
    return null;
  }

  function distToSegment(p, a, b) {
    var l2 = dist(a, b);
    if (l2 < 0.001) return dist(p, a);
    l2 = l2 * l2;
    var t = ((p.x - a.x) * (b.x - a.x) + (p.y - a.y) * (b.y - a.y)) / l2;
    t = Math.max(0, Math.min(1, t));
    return dist(p, { x: a.x + t * (b.x - a.x), y: a.y + t * (b.y - a.y) });
  }

  function pointInTriangle(p, a, b, c) {
    function sign(p1, p2, p3) {
      return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y);
    }
    var b1 = sign(p, a, b) < 0;
    var b2 = sign(p, b, c) < 0;
    var b3 = sign(p, c, a) < 0;
    return b1 === b2 && b2 === b3;
  }

  function onPointerDown(evt) {
    if (evt.button != null && evt.button !== 0) return;
    var p = svgPoint(evt);
    canvas.setPointerCapture && canvas.setPointerCapture(evt.pointerId);

    if (tool === "select") {
      selectedId = hitTest(p);
      redraw();
      return;
    }

    if (tool === "triangle" || tool === "angle") {
      draftPoints.push(p);
      clearPreview();
      draftPoints.forEach(function (pt, idx) {
        previewLayer.appendChild(el("circle", {
          cx: pt.x, cy: pt.y, r: 3.5, fill: color(), stroke: "none",
        }));
        if (idx > 0) {
          previewLayer.appendChild(el("line", {
            x1: draftPoints[idx - 1].x, y1: draftPoints[idx - 1].y,
            x2: pt.x, y2: pt.y, stroke: color(), "stroke-width": strokeW(),
            "stroke-dasharray": "4 3",
          }));
        }
      });
      if (draftPoints.length >= 3) {
        if (tool === "triangle") {
          addShape({
            id: uid(), kind: "triangle", color: color(), stroke: strokeW(),
            a: draftPoints[0], b: draftPoints[1], c: draftPoints[2],
          });
        } else {
          addShape({
            id: uid(), kind: "angle", color: color(), stroke: strokeW(),
            v: draftPoints[0], a: draftPoints[1], b: draftPoints[2],
            label: angleLabel(),
          });
        }
        draftPoints = [];
        clearPreview();
      } else {
        setStatus((tool === "triangle" ? "Üçgen" : "Açı") + ": " + draftPoints.length + "/3 nokta");
      }
      return;
    }

    dragStart = p;
  }

  function onPointerMove(evt) {
    if (!dragStart) return;
    var p = svgPoint(evt);
    clearPreview();
    var c = color();
    var sw = strokeW();
    if (tool === "line") {
      previewLayer.appendChild(el("line", {
        x1: dragStart.x, y1: dragStart.y, x2: p.x, y2: p.y,
        stroke: c, "stroke-width": sw, "stroke-linecap": "round",
      }));
    } else if (tool === "circle" || tool === "radius") {
      var r = dist(dragStart, p);
      previewLayer.appendChild(el("circle", {
        cx: dragStart.x, cy: dragStart.y, r: r, fill: "none", stroke: c, "stroke-width": sw,
      }));
      if (tool === "radius") {
        previewLayer.appendChild(el("line", {
          x1: dragStart.x, y1: dragStart.y, x2: p.x, y2: p.y,
          stroke: c, "stroke-width": sw,
        }));
      }
    } else if (tool === "square") {
      var size = Math.max(Math.abs(p.x - dragStart.x), Math.abs(p.y - dragStart.y));
      var x = p.x < dragStart.x ? dragStart.x - size : dragStart.x;
      var y = p.y < dragStart.y ? dragStart.y - size : dragStart.y;
      previewLayer.appendChild(el("rect", {
        x: x, y: y, width: size, height: size, fill: "none", stroke: c, "stroke-width": sw,
      }));
    } else if (tool === "semicircle") {
      var rr = dist(dragStart, p) / 2;
      var d =
        "M " + dragStart.x + " " + dragStart.y +
        " A " + rr + " " + rr + " 0 0 1 " + p.x + " " + p.y;
      previewLayer.appendChild(el("path", { d: d, fill: "none", stroke: c, "stroke-width": sw }));
      previewLayer.appendChild(el("line", {
        x1: dragStart.x, y1: dragStart.y, x2: p.x, y2: p.y, stroke: c, "stroke-width": sw,
      }));
    }
  }

  function onPointerUp(evt) {
    if (!dragStart) return;
    var p = svgPoint(evt);
    var c = color();
    var sw = strokeW();
    if (tool === "line" && dist(dragStart, p) > 3) {
      addShape({ id: uid(), kind: "line", color: c, stroke: sw, a: dragStart, b: p });
    } else if (tool === "circle") {
      var r = dist(dragStart, p);
      if (r > 3) addShape({ id: uid(), kind: "circle", color: c, stroke: sw, c: dragStart, r: r });
    } else if (tool === "radius") {
      var rr = dist(dragStart, p);
      if (rr > 3) {
        addShape({
          id: uid(), kind: "radius", color: c, stroke: sw,
          c: dragStart, e: p, r: rr, label: angleLabel() === "1" ? "r" : angleLabel(),
        });
      }
    } else if (tool === "square") {
      var size = Math.max(Math.abs(p.x - dragStart.x), Math.abs(p.y - dragStart.y));
      if (size > 3) {
        var x = p.x < dragStart.x ? dragStart.x - size : dragStart.x;
        var y = p.y < dragStart.y ? dragStart.y - size : dragStart.y;
        addShape({ id: uid(), kind: "square", color: c, stroke: sw, x: x, y: y, size: size });
      }
    } else if (tool === "semicircle" && dist(dragStart, p) > 3) {
      addShape({ id: uid(), kind: "semicircle", color: c, stroke: sw, a: dragStart, b: p, sweep: 1 });
    }
    dragStart = null;
    clearPreview();
  }

  function onKeyDown(evt) {
    if (evt.key === "Delete" || evt.key === "Backspace") {
      if (!selectedId) return;
      var tag = (evt.target && evt.target.tagName || "").toLowerCase();
      if (tag === "input" || tag === "textarea" || tag === "select") return;
      shapes = shapes.filter(function (s) { return s.id !== selectedId; });
      selectedId = null;
      redraw();
      evt.preventDefault();
    }
  }

  // Wire UI
  root.querySelectorAll(".geo-tool").forEach(function (btn) {
    btn.addEventListener("click", function () {
      setTool(btn.getAttribute("data-tool") || "select");
    });
  });
  document.getElementById("geo-undo") && document.getElementById("geo-undo").addEventListener("click", undo);
  document.getElementById("geo-clear") && document.getElementById("geo-clear").addEventListener("click", clearAll);
  if (strokeInput) {
    strokeInput.addEventListener("input", function () {
      if (strokeVal) strokeVal.textContent = strokeInput.value;
    });
  }

  canvas.addEventListener("pointerdown", onPointerDown);
  canvas.addEventListener("pointermove", onPointerMove);
  canvas.addEventListener("pointerup", onPointerUp);
  canvas.addEventListener("pointercancel", function () {
    dragStart = null;
    clearPreview();
  });
  window.addEventListener("keydown", onKeyDown);

  buildGrid();
  setTool("line");

  window.KpssGeometryQuestionEditor = {
    hasShapes: function () { return shapes.length > 0; },
    exportSvg: exportSvgString,
    clear: function () {
      shapes = [];
      selectedId = null;
      redraw();
    },
  };
})();
