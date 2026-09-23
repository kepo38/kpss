/**
 * Shared geometry drawing core (stem + solution overlay).
 * Separate from map-question-editor.js.
 */
(function (global) {
  "use strict";

  var FIGURE_PLACEHOLDER = "[ŞEKİL]";

  function ensureSekilInText(value) {
    value = value == null ? "" : String(value);
    if (value.indexOf(FIGURE_PLACEHOLDER) !== -1) return value;
    if (!value.trim()) return FIGURE_PLACEHOLDER + "\n";
    return FIGURE_PLACEHOLDER + "\n\n" + value;
  }

  function ensureSolutionSekilPlaceholder() {
    var el =
      document.getElementById("question-solution") ||
      document.querySelector('textarea[name="solution"]');
    if (!el) return false;
    var next = ensureSekilInText(el.value || "");
    if (next === (el.value || "")) return false;
    el.value = next;
    el.dispatchEvent(new Event("input", { bubbles: true }));
    el.dispatchEvent(new Event("change", { bubbles: true }));
    if (global.KpssQuestionPreview && typeof global.KpssQuestionPreview.sync === "function") {
      global.KpssQuestionPreview.sync();
    }
    return true;
  }

  function create(config) {
    config = config || {};
    var kind = config.kind === "solution" ? "solution" : "stem";
    var ids = config.ids || {};
    function idOf(key, fallback) {
      return ids[key] || fallback;
    }

  var VB_W = 400;
  var VB_H = 320;
  var MIN_LEN = 3;
  var MIN_R = 3;
  var EDITOR_MARK = 'data-geo-editor="1"';
  var SOLUTION_ROLE = 'data-geo-role="solution"';
  var FIGURE_PLACEHOLDER = "[ŞEKİL]";

  var root;
  var canvas;
  var shapesLayer;
  var underlayLayer;
  var previewLayer;
  var handlesLayer;
  var gridLayer;
  var statusEl;
  var colorEl;
  var strokeEl;
  var strokeValEl;
  var angleLabelEl;
  var figureField;
  var solutionField;
  var editorMode = kind;

  var tool = "select";
  var shapes = [];
  var history = [];
  var selectedId = null;

  var drag = null;
  var clickPts = [];
  var shapeSeq = 1;

  function $(id) {
    return document.getElementById(id);
  }

  function setStatus(msg) {
    if (statusEl) statusEl.textContent = msg || "";
  }

  function strokeWidth() {
    var n = strokeEl ? parseFloat(strokeEl.value) : 2;
    if (!isFinite(n) || n <= 0) return 2;
    return Math.max(0.5, Math.min(6, n));
  }

  function strokeColor() {
    var c = colorEl ? String(colorEl.value || "").trim() : "#E8C87A";
    return /^#[0-9a-fA-F]{6}$/.test(c) ? c : "#E8C87A";
  }

  function angleLabelText() {
    var t = angleLabelEl ? String(angleLabelEl.value || "").trim() : "";
    return t.slice(0, 8);
  }

  function dist(a, b) {
    var dx = a.x - b.x;
    var dy = a.y - b.y;
    return Math.sqrt(dx * dx + dy * dy);
  }

  function round2(n) {
    return Math.round(n * 100) / 100;
  }

  function clamp(n, lo, hi) {
    return Math.max(lo, Math.min(hi, n));
  }

  function svgPoint(evt) {
    if (!canvas) return { x: 0, y: 0 };
    var pt = canvas.createSVGPoint();
    pt.x = evt.clientX;
    pt.y = evt.clientY;
    var ctm = canvas.getScreenCTM();
    if (!ctm) {
      var rect = canvas.getBoundingClientRect();
      return {
        x: clamp(((evt.clientX - rect.left) / rect.width) * VB_W, 0, VB_W),
        y: clamp(((evt.clientY - rect.top) / rect.height) * VB_H, 0, VB_H),
      };
    }
    var p = pt.matrixTransform(ctm.inverse());
    return { x: clamp(p.x, 0, VB_W), y: clamp(p.y, 0, VB_H) };
  }

  function pushHistory() {
    history.push(JSON.stringify(shapes));
    if (history.length > 80) history.shift();
  }

  function nextId() {
    shapeSeq += 1;
    return "gs-" + shapeSeq;
  }

  function isUsable(shape) {
    if (!shape || !shape.type) return false;
    var sw = Number(shape.stroke);
    if (!isFinite(sw) || sw <= 0) return false;
    if (!shape.color || !/^#[0-9a-fA-F]{6}$/.test(shape.color)) return false;

    switch (shape.type) {
      case "line":
      case "radius":
        return dist({ x: shape.x1, y: shape.y1 }, { x: shape.x2, y: shape.y2 }) >= MIN_LEN;
      case "circle":
        return Number(shape.r) >= MIN_R;
      case "square":
        return Number(shape.size) >= MIN_LEN;
      case "triangle":
        if (!shape.points || shape.points.length !== 3) return false;
        return (
          dist(shape.points[0], shape.points[1]) >= MIN_LEN &&
          dist(shape.points[1], shape.points[2]) >= MIN_LEN &&
          dist(shape.points[0], shape.points[2]) >= MIN_LEN
        );
      case "polygon":
        if (!shape.points || shape.points.length < 3) return false;
        return shape.points.length >= 3;
      case "semicircle":
        return dist({ x: shape.x1, y: shape.y1 }, { x: shape.x2, y: shape.y2 }) >= MIN_LEN * 2;
      case "angle":
        if (!shape.a || !shape.b || !shape.c) return false;
        return (
          dist(shape.a, shape.b) >= MIN_LEN &&
          dist(shape.c, shape.b) >= MIN_LEN &&
          dist(shape.a, shape.c) >= MIN_LEN * 0.5
        );
      default:
        return false;
    }
  }

  function cloneShape(shape) {
    return JSON.parse(JSON.stringify(shape));
  }

  function findShape(id) {
    if (!id) return null;
    for (var i = 0; i < shapes.length; i++) {
      if (shapes[i].id === id) return shapes[i];
    }
    return null;
  }

  function shapeBBox(shape) {
    var minX = Infinity;
    var minY = Infinity;
    var maxX = -Infinity;
    var maxY = -Infinity;
    function add(x, y) {
      if (!isFinite(x) || !isFinite(y)) return;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
    if (!shape) return { minX: 0, minY: 0, maxX: 0, maxY: 0 };
    switch (shape.type) {
      case "line":
      case "radius":
      case "semicircle":
        add(shape.x1, shape.y1);
        add(shape.x2, shape.y2);
        if (shape.type === "semicircle") {
          var mx = (shape.x1 + shape.x2) / 2;
          var my = (shape.y1 + shape.y2) / 2;
          var r = dist({ x: shape.x1, y: shape.y1 }, { x: shape.x2, y: shape.y2 }) / 2;
          var dx = shape.x2 - shape.x1;
          var dy = shape.y2 - shape.y1;
          var nx = -dy;
          var ny = dx;
          var nlen = Math.sqrt(nx * nx + ny * ny) || 1;
          add(mx + (nx / nlen) * r, my + (ny / nlen) * r);
        }
        break;
      case "circle":
        add(shape.cx - shape.r, shape.cy - shape.r);
        add(shape.cx + shape.r, shape.cy + shape.r);
        break;
      case "square":
        add(shape.x, shape.y);
        add(shape.x + shape.size, shape.y + shape.size);
        break;
      case "triangle":
      case "polygon":
        (shape.points || []).forEach(function (p) {
          add(p.x, p.y);
        });
        break;
      case "angle":
        add(shape.a.x, shape.a.y);
        add(shape.b.x, shape.b.y);
        add(shape.c.x, shape.c.y);
        break;
      default:
        break;
    }
    if (!isFinite(minX)) {
      return { minX: 0, minY: 0, maxX: 0, maxY: 0 };
    }
    return { minX: minX, minY: minY, maxX: maxX, maxY: maxY };
  }

  function shapeCentroid(shape) {
    var bb = shapeBBox(shape);
    return { x: (bb.minX + bb.maxX) / 2, y: (bb.minY + bb.maxY) / 2 };
  }

  function rotatePt(p, deg, ox, oy) {
    var rad = (deg * Math.PI) / 180;
    var c = Math.cos(rad);
    var s = Math.sin(rad);
    var dx = p.x - ox;
    var dy = p.y - oy;
    return { x: ox + dx * c - dy * s, y: oy + dx * s + dy * c };
  }

  function scalePt(p, factor, ox, oy) {
    return { x: ox + (p.x - ox) * factor, y: oy + (p.y - oy) * factor };
  }

  function squareToPolygon(shape) {
    if (!shape || shape.type !== "square") return shape;
    var x = Number(shape.x);
    var y = Number(shape.y);
    var s = Number(shape.size);
    shape.type = "polygon";
    shape.points = [
      { x: x, y: y },
      { x: x + s, y: y },
      { x: x + s, y: y + s },
      { x: x, y: y + s },
    ];
    delete shape.x;
    delete shape.y;
    delete shape.size;
    return shape;
  }

  function translateShape(shape, dx, dy) {
    if (!shape || (!dx && !dy)) return shape;
    switch (shape.type) {
      case "line":
      case "radius":
      case "semicircle":
        shape.x1 += dx;
        shape.y1 += dy;
        shape.x2 += dx;
        shape.y2 += dy;
        break;
      case "circle":
        shape.cx += dx;
        shape.cy += dy;
        break;
      case "square":
        shape.x += dx;
        shape.y += dy;
        break;
      case "triangle":
      case "polygon":
        (shape.points || []).forEach(function (p) {
          p.x += dx;
          p.y += dy;
        });
        break;
      case "angle":
        shape.a.x += dx;
        shape.a.y += dy;
        shape.b.x += dx;
        shape.b.y += dy;
        shape.c.x += dx;
        shape.c.y += dy;
        break;
      default:
        break;
    }
    return shape;
  }

  function scaleShape(shape, factor, ox, oy) {
    if (!shape || !isFinite(factor) || factor <= 0) return shape;
    var minFactor = factor;
    switch (shape.type) {
      case "line":
      case "radius":
      case "semicircle": {
        var len0 = dist({ x: shape.x1, y: shape.y1 }, { x: shape.x2, y: shape.y2 });
        var minNeed = shape.type === "semicircle" ? MIN_LEN * 2 : MIN_LEN;
        if (len0 * factor < minNeed && len0 > 0) minFactor = minNeed / len0;
        var p1 = scalePt({ x: shape.x1, y: shape.y1 }, minFactor, ox, oy);
        var p2 = scalePt({ x: shape.x2, y: shape.y2 }, minFactor, ox, oy);
        shape.x1 = p1.x;
        shape.y1 = p1.y;
        shape.x2 = p2.x;
        shape.y2 = p2.y;
        break;
      }
      case "circle": {
        if (shape.r * factor < MIN_R && shape.r > 0) minFactor = MIN_R / shape.r;
        var c = scalePt({ x: shape.cx, y: shape.cy }, minFactor, ox, oy);
        shape.cx = c.x;
        shape.cy = c.y;
        shape.r = Math.max(MIN_R, shape.r * minFactor);
        break;
      }
      case "square": {
        if (shape.size * factor < MIN_LEN && shape.size > 0) minFactor = MIN_LEN / shape.size;
        var tl = scalePt({ x: shape.x, y: shape.y }, minFactor, ox, oy);
        shape.x = tl.x;
        shape.y = tl.y;
        shape.size = Math.max(MIN_LEN, shape.size * minFactor);
        break;
      }
      case "triangle":
      case "polygon": {
        var pts = shape.points || [];
        if (pts.length >= 2) {
          var minEdge = Infinity;
          var i;
          for (i = 0; i < pts.length; i++) {
            var j = (i + 1) % pts.length;
            var e = dist(pts[i], pts[j]);
            if (e < minEdge) minEdge = e;
          }
          if (isFinite(minEdge) && minEdge * factor < MIN_LEN && minEdge > 0) {
            minFactor = MIN_LEN / minEdge;
          }
        }
        shape.points = pts.map(function (p) {
          return scalePt(p, minFactor, ox, oy);
        });
        break;
      }
      case "angle": {
        var la = dist(shape.a, shape.b);
        var lc = dist(shape.c, shape.b);
        var minArm = Math.min(la, lc);
        if (minArm * factor < MIN_LEN && minArm > 0) minFactor = MIN_LEN / minArm;
        shape.a = scalePt(shape.a, minFactor, ox, oy);
        shape.b = scalePt(shape.b, minFactor, ox, oy);
        shape.c = scalePt(shape.c, minFactor, ox, oy);
        break;
      }
      default:
        break;
    }
    return shape;
  }

  function rotateShape(shape, deg, ox, oy) {
    if (!shape || !isFinite(deg) || deg === 0) return shape;
    // Normalize tiny floats
    if (Math.abs(deg) < 1e-9) return shape;
    switch (shape.type) {
      case "line":
      case "radius":
      case "semicircle": {
        var p1 = rotatePt({ x: shape.x1, y: shape.y1 }, deg, ox, oy);
        var p2 = rotatePt({ x: shape.x2, y: shape.y2 }, deg, ox, oy);
        shape.x1 = p1.x;
        shape.y1 = p1.y;
        shape.x2 = p2.x;
        shape.y2 = p2.y;
        break;
      }
      case "circle":
        // Geometry is rotation-invariant; still move center if pivot ≠ center
        {
          var c = rotatePt({ x: shape.cx, y: shape.cy }, deg, ox, oy);
          shape.cx = c.x;
          shape.cy = c.y;
        }
        break;
      case "square": {
        // Any rotation leaves axis-aligned square representation invalid (except
        // exact 90° multiples about centroid). Convert once and rotate as polygon.
        squareToPolygon(shape);
        shape.points = shape.points.map(function (p) {
          return rotatePt(p, deg, ox, oy);
        });
        break;
      }
      case "triangle":
      case "polygon":
        shape.points = (shape.points || []).map(function (p) {
          return rotatePt(p, deg, ox, oy);
        });
        break;
      case "angle":
        shape.a = rotatePt(shape.a, deg, ox, oy);
        shape.b = rotatePt(shape.b, deg, ox, oy);
        shape.c = rotatePt(shape.c, deg, ox, oy);
        break;
      default:
        break;
    }
    return shape;
  }

  function shapesEqualJson(a, b) {
    return JSON.stringify(a) === JSON.stringify(b);
  }

  function drawGrid() {
    if (!gridLayer) return;
    gridLayer.innerHTML = "";
    var step = 20;
    var i;
    for (i = step; i < VB_W; i += step) {
      var v = document.createElementNS("http://www.w3.org/2000/svg", "line");
      v.setAttribute("x1", i);
      v.setAttribute("y1", 0);
      v.setAttribute("x2", i);
      v.setAttribute("y2", VB_H);
      gridLayer.appendChild(v);
    }
    for (i = step; i < VB_H; i += step) {
      var h = document.createElementNS("http://www.w3.org/2000/svg", "line");
      h.setAttribute("x1", 0);
      h.setAttribute("y1", i);
      h.setAttribute("x2", VB_W);
      h.setAttribute("y2", i);
      gridLayer.appendChild(h);
    }
  }

  function el(name, attrs) {
    var node = document.createElementNS("http://www.w3.org/2000/svg", name);
    if (attrs) {
      Object.keys(attrs).forEach(function (k) {
        if (attrs[k] != null && attrs[k] !== "") node.setAttribute(k, String(attrs[k]));
      });
    }
    return node;
  }

  function semicirclePath(x1, y1, x2, y2) {
    var mx = (x1 + x2) / 2;
    var my = (y1 + y2) / 2;
    var r = dist({ x: x1, y: y1 }, { x: x2, y: y2 }) / 2;
    if (r < MIN_R) return "";
    // Arc to the "left" of diameter direction (upper relative to vector)
    var dx = x2 - x1;
    var dy = y2 - y1;
    var nx = -dy;
    var ny = dx;
    var nlen = Math.sqrt(nx * nx + ny * ny) || 1;
    var hx = mx + (nx / nlen) * r;
    var hy = my + (ny / nlen) * r;
    // Use sweep based on cross product of diameter → arc midpoint
    var cross = dx * (hy - y1) - dy * (hx - x1);
    var sweep = cross >= 0 ? 1 : 0;
    return (
      "M " +
      round2(x1) +
      " " +
      round2(y1) +
      " A " +
      round2(r) +
      " " +
      round2(r) +
      " 0 0 " +
      sweep +
      " " +
      round2(x2) +
      " " +
      round2(y2) +
      " L " +
      round2(x1) +
      " " +
      round2(y1)
    );
  }

  function angleArcPath(a, b, c) {
    var r = Math.min(28, dist(a, b) * 0.35, dist(c, b) * 0.35);
    if (r < 6) r = 6;
    var ang1 = Math.atan2(a.y - b.y, a.x - b.x);
    var ang2 = Math.atan2(c.y - b.y, c.x - b.x);
    var p1 = { x: b.x + Math.cos(ang1) * r, y: b.y + Math.sin(ang1) * r };
    var p2 = { x: b.x + Math.cos(ang2) * r, y: b.y + Math.sin(ang2) * r };
    var delta = ang2 - ang1;
    while (delta <= -Math.PI) delta += Math.PI * 2;
    while (delta > Math.PI) delta -= Math.PI * 2;
    var large = Math.abs(delta) > Math.PI ? 1 : 0;
    var sweep = delta >= 0 ? 1 : 0;
    return {
      d:
        "M " +
        round2(p1.x) +
        " " +
        round2(p1.y) +
        " A " +
        round2(r) +
        " " +
        round2(r) +
        " 0 " +
        large +
        " " +
        sweep +
        " " +
        round2(p2.x) +
        " " +
        round2(p2.y),
      labelX: b.x + Math.cos(ang1 + delta / 2) * (r + 12),
      labelY: b.y + Math.sin(ang1 + delta / 2) * (r + 12),
    };
  }

  function renderShapeNode(shape, interactive) {
    var g = el("g", {
      "data-id": shape.id || "",
      "data-type": shape.type,
      class: interactive && shape.id === selectedId ? "geo-shape-selected" : "",
    });
    var color = shape.color;
    var sw = shape.stroke;
    var common = {
      fill: "none",
      stroke: color,
      "stroke-width": sw,
      "stroke-linecap": "round",
      "stroke-linejoin": "round",
    };
    // Wide invisible stroke so thin outlines are easy to grab in select mode.
    var hitSw = Math.max(14, Number(sw) * 5 || 14);

    if (shape.type === "line" || shape.type === "radius") {
      if (interactive) {
        g.appendChild(
          el("line", {
            class: "geo-hit",
            x1: round2(shape.x1),
            y1: round2(shape.y1),
            x2: round2(shape.x2),
            y2: round2(shape.y2),
            fill: "none",
            stroke: "rgba(0,0,0,0)",
            "stroke-width": hitSw,
            "stroke-linecap": "round",
            "pointer-events": "stroke",
          })
        );
      }
      g.appendChild(
        el("line", {
          x1: round2(shape.x1),
          y1: round2(shape.y1),
          x2: round2(shape.x2),
          y2: round2(shape.y2),
          fill: "none",
          stroke: color,
          "stroke-width": sw,
          "stroke-linecap": "round",
        })
      );
      if (shape.type === "radius") {
        var midX = (shape.x1 + shape.x2) / 2;
        var midY = (shape.y1 + shape.y2) / 2;
        var label = shape.label || "r";
        g.appendChild(
          el("text", {
            x: round2(midX + 6),
            y: round2(midY - 4),
            fill: color,
            "font-size": "14",
            "font-family": "Tinos, Times New Roman, serif",
          })
        ).textContent = label;
      }
    } else if (shape.type === "circle") {
      if (interactive) {
        g.appendChild(
          el("circle", {
            class: "geo-hit",
            cx: round2(shape.cx),
            cy: round2(shape.cy),
            r: round2(shape.r),
            fill: "rgba(0,0,0,0)",
            stroke: "rgba(0,0,0,0)",
            "stroke-width": hitSw,
            "pointer-events": "all",
          })
        );
      }
      g.appendChild(
        el("circle", {
          cx: round2(shape.cx),
          cy: round2(shape.cy),
          r: round2(shape.r),
          fill: "none",
          stroke: color,
          "stroke-width": sw,
        })
      );
    } else if (shape.type === "square") {
      if (interactive) {
        g.appendChild(
          el("rect", {
            class: "geo-hit",
            x: round2(shape.x),
            y: round2(shape.y),
            width: round2(shape.size),
            height: round2(shape.size),
            fill: "rgba(0,0,0,0)",
            stroke: "rgba(0,0,0,0)",
            "stroke-width": hitSw,
            "pointer-events": "all",
          })
        );
      }
      g.appendChild(
        el("rect", {
          x: round2(shape.x),
          y: round2(shape.y),
          width: round2(shape.size),
          height: round2(shape.size),
          fill: "none",
          stroke: color,
          "stroke-width": sw,
        })
      );
    } else if (shape.type === "triangle" || shape.type === "polygon") {
      var pts = shape.points
        .map(function (p) {
          return round2(p.x) + "," + round2(p.y);
        })
        .join(" ");
      if (interactive) {
        g.appendChild(
          el("polygon", {
            class: "geo-hit",
            points: pts,
            fill: "rgba(0,0,0,0)",
            stroke: "rgba(0,0,0,0)",
            "stroke-width": hitSw,
            "pointer-events": "all",
          })
        );
      }
      g.appendChild(
        el("polygon", {
          points: pts,
          fill: "none",
          stroke: color,
          "stroke-width": sw,
          "stroke-linejoin": "round",
        })
      );
    } else if (shape.type === "semicircle") {
      var d = semicirclePath(shape.x1, shape.y1, shape.x2, shape.y2);
      if (d) {
        if (interactive) {
          g.appendChild(
            el("path", {
              class: "geo-hit",
              d: d,
              fill: "none",
              stroke: "rgba(0,0,0,0)",
              "stroke-width": hitSw,
              "stroke-linejoin": "round",
              "pointer-events": "stroke",
            })
          );
        }
        g.appendChild(
          el("path", {
            d: d,
            fill: "none",
            stroke: color,
            "stroke-width": sw,
            "stroke-linejoin": "round",
          })
        );
      }
    } else if (shape.type === "angle") {
      if (interactive) {
        g.appendChild(
          el("line", {
            class: "geo-hit",
            x1: round2(shape.a.x),
            y1: round2(shape.a.y),
            x2: round2(shape.b.x),
            y2: round2(shape.b.y),
            fill: "none",
            stroke: "rgba(0,0,0,0)",
            "stroke-width": hitSw,
            "stroke-linecap": "round",
            "pointer-events": "stroke",
          })
        );
        g.appendChild(
          el("line", {
            class: "geo-hit",
            x1: round2(shape.c.x),
            y1: round2(shape.c.y),
            x2: round2(shape.b.x),
            y2: round2(shape.b.y),
            fill: "none",
            stroke: "rgba(0,0,0,0)",
            "stroke-width": hitSw,
            "stroke-linecap": "round",
            "pointer-events": "stroke",
          })
        );
      }
      g.appendChild(
        el("line", Object.assign({}, common, {
          x1: round2(shape.a.x),
          y1: round2(shape.a.y),
          x2: round2(shape.b.x),
          y2: round2(shape.b.y),
        }))
      );
      g.appendChild(
        el("line", Object.assign({}, common, {
          x1: round2(shape.c.x),
          y1: round2(shape.c.y),
          x2: round2(shape.b.x),
          y2: round2(shape.b.y),
        }))
      );
      var arc = angleArcPath(shape.a, shape.b, shape.c);
      g.appendChild(
        el("path", {
          d: arc.d,
          fill: "none",
          stroke: color,
          "stroke-width": Math.max(1, sw * 0.85),
        })
      );
      if (shape.label) {
        g.appendChild(
          el("text", {
            x: round2(arc.labelX),
            y: round2(arc.labelY),
            fill: color,
            "font-size": "13",
            "font-family": "Tinos, Times New Roman, serif",
            "text-anchor": "middle",
            "dominant-baseline": "middle",
          })
        ).textContent = shape.label;
      }
    }
    return g;
  }

  function clearLayer(layer) {
    if (layer) while (layer.firstChild) layer.removeChild(layer.firstChild);
  }

  function renderShapes() {
    if (kind === "solution") renderUnderlay();
    clearLayer(shapesLayer);
    shapes.forEach(function (s) {
      if (!isUsable(s)) return;
      shapesLayer.appendChild(renderShapeNode(s, true));
    });
    renderUnderlay();
    renderHandles();
  }

  function clearHandles() {
    clearLayer(handlesLayer);
  }

  function renderHandles() {
    clearHandles();
    if (!handlesLayer || !selectedId || tool !== "select") return;
    var shape = findShape(selectedId);
    if (!shape || !isUsable(shape)) return;
    var bb = shapeBBox(shape);
    var pad = 6;
    var x = bb.minX - pad;
    var y = bb.minY - pad;
    var w = bb.maxX - bb.minX + pad * 2;
    var h = bb.maxY - bb.minY + pad * 2;
    if (w < 8) {
      x -= (8 - w) / 2;
      w = 8;
    }
    if (h < 8) {
      y -= (8 - h) / 2;
      h = 8;
    }
    var hs = 9;
    var half = hs / 2;

    // Inline fills: SVG default fill is black — solution editor (#geo-sol-handles)
    // had no CSS and painted a solid black move plate over the canvas.
    handlesLayer.appendChild(
      el("rect", {
        class: "geo-handle-bbox",
        x: round2(x),
        y: round2(y),
        width: round2(w),
        height: round2(h),
        fill: "none",
        stroke: "rgba(94,234,212,0.7)",
        "stroke-width": 1,
        "stroke-dasharray": "4 3",
        "pointer-events": "none",
      })
    );
    handlesLayer.appendChild(
      el("rect", {
        class: "geo-handle-move",
        "data-handle": "move",
        x: round2(x),
        y: round2(y),
        width: round2(w),
        height: round2(h),
        fill: "rgba(0,0,0,0)",
        stroke: "none",
        "pointer-events": "all",
        style: "cursor:move",
      })
    );

    var corners = [
      { key: "nw", cx: x, cy: y },
      { key: "ne", cx: x + w, cy: y },
      { key: "se", cx: x + w, cy: y + h },
      { key: "sw", cx: x, cy: y + h },
    ];
    corners.forEach(function (c) {
      handlesLayer.appendChild(
        el("rect", {
          class: "geo-handle-corner",
          "data-handle": "resize",
          "data-corner": c.key,
          x: round2(c.cx - half),
          y: round2(c.cy - half),
          width: hs,
          height: hs,
          fill: "#e8c87a",
          stroke: "#5eead4",
          "stroke-width": 1,
          "pointer-events": "all",
        })
      );
    });

    // Rotation stalk above top-center (skip pure visual for circle? keep for consistency)
    var stalkLen = 22;
    var topCx = x + w / 2;
    var topCy = y;
    var rotY = topCy - stalkLen;
    handlesLayer.appendChild(
      el("line", {
        class: "geo-handle-rotate-stalk",
        x1: round2(topCx),
        y1: round2(topCy),
        x2: round2(topCx),
        y2: round2(rotY),
        fill: "none",
        stroke: "rgba(94,234,212,0.75)",
        "stroke-width": 1.25,
        "pointer-events": "none",
      })
    );
    handlesLayer.appendChild(
      el("circle", {
        class: "geo-handle-rotate",
        "data-handle": "rotate",
        cx: round2(topCx),
        cy: round2(rotY),
        r: 6,
        fill: "#5eead4",
        stroke: "#e8c87a",
        "stroke-width": 1.25,
        "pointer-events": "all",
        style: "cursor:grab",
      })
    );
  }

  function renderPreview(temp) {
    clearLayer(previewLayer);
    if (!temp || !isUsable(temp)) {
      // still show incomplete multi-click guides
      if (temp && (temp.type === "triangle" || temp.type === "angle") && temp._guides) {
        temp._guides.forEach(function (p) {
          previewLayer.appendChild(
            el("circle", {
              cx: round2(p.x),
              cy: round2(p.y),
              r: 3,
              fill: strokeColor(),
              stroke: "none",
            })
          );
        });
      }
      return;
    }
    previewLayer.appendChild(renderShapeNode(temp, false));
  }



  function serializeShapeNodes(list) {
    var parts = [];
    list.forEach(function (s) {
      if (!isUsable(s)) return;
      var node = renderShapeNode(s, false);
      parts.push(new XMLSerializer().serializeToString(node));
    });
    return parts.join("");
  }

  function exportSvg() {
    var usable = shapes.filter(isUsable);
    if (!usable.length) return "";
    return (
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' +
      VB_W +
      " " +
      VB_H +
      '" width="400" height="320" ' +
      EDITOR_MARK +
      ' fill="none">' +
      serializeShapeNodes(usable) +
      "</svg>"
    );
  }


  function writeField(field, svg) {
    if (!field) return;
    if (svg === field.value) {
      if (window.KpssQuestionPreview && typeof window.KpssQuestionPreview.sync === "function") {
        window.KpssQuestionPreview.sync();
      }
      return;
    }
    field.value = svg;
    field.dispatchEvent(new Event("input", { bubbles: true }));
    field.dispatchEvent(new Event("change", { bubbles: true }));
    if (window.KpssQuestionPreview && typeof window.KpssQuestionPreview.sync === "function") {
      window.KpssQuestionPreview.sync();
    }
    document.dispatchEvent(new CustomEvent("geometry-question-change"));
  }






  function commitShape(shape) {
    if (!isUsable(shape)) {
      setStatus("Şekil çok küçük veya geçersiz — atlandı.");
      renderPreview(null);
      return;
    }
    pushHistory();
    shape.id = nextId();
    shapes.push(shape);
    selectedId = shape.id;
    clickPts = [];
    drag = null;
    renderShapes();
    renderPreview(null);
    syncActiveField(false);
    refreshModeStatus();
  }

  function setTool(next) {
    tool = next || "select";
    clickPts = [];
    drag = null;
    renderPreview(null);
    if (root) root.setAttribute("data-tool", tool);
    root.querySelectorAll(".geo-tool").forEach(function (btn) {
      btn.setAttribute("aria-pressed", btn.getAttribute("data-tool") === tool ? "true" : "false");
    });
    if (tool === "triangle") setStatus("Üçgen: 3 noktaya tıklayın (0/3)");
    else if (tool === "angle") setStatus("Açı: 3 nokta — ışın, tepe, ışın (0/3)");
    else if (tool === "radius") setStatus("Yarıçap: merkezden kenara sürükleyin");
    else if (tool === "semicircle") setStatus("Yarım daire: çapı sürükleyin");
    else if (tool === "select") {
      setStatus(
        selectedId
          ? "Seçili: sürükle / köşe / döndür"
          : "Seç: sürükle taşı · köşeden boyut · üst tutamaktan döndür · Delete sil"
      );
    } else setStatus("");
    renderHandles();
  }

  function draftFromDrag(p0, p1) {
    var color = strokeColor();
    var sw = strokeWidth();
    if (tool === "line") {
      return { type: "line", x1: p0.x, y1: p0.y, x2: p1.x, y2: p1.y, color: color, stroke: sw };
    }
    if (tool === "circle") {
      return {
        type: "circle",
        cx: p0.x,
        cy: p0.y,
        r: dist(p0, p1),
        color: color,
        stroke: sw,
      };
    }
    if (tool === "square") {
      var side = Math.max(Math.abs(p1.x - p0.x), Math.abs(p1.y - p0.y));
      var x = p1.x < p0.x ? p0.x - side : p0.x;
      var y = p1.y < p0.y ? p0.y - side : p0.y;
      return { type: "square", x: x, y: y, size: side, color: color, stroke: sw };
    }
    if (tool === "semicircle") {
      return {
        type: "semicircle",
        x1: p0.x,
        y1: p0.y,
        x2: p1.x,
        y2: p1.y,
        color: color,
        stroke: sw,
      };
    }
    if (tool === "radius") {
      var lbl = angleLabelText();
      return {
        type: "radius",
        x1: p0.x,
        y1: p0.y,
        x2: p1.x,
        y2: p1.y,
        label: lbl || "r",
        color: color,
        stroke: sw,
      };
    }
    return null;
  }

  function startSelectGesture(mode, shape, p, pointerId, corner) {
    var pivot = shapeCentroid(shape);
    var startDist = dist(p, pivot);
    if (startDist < 1) startDist = 1;
    drag = {
      mode: mode,
      shapeId: shape.id,
      snapshot: cloneShape(shape),
      pivot: pivot,
      start: p,
      last: p,
      startDist: startDist,
      startAngle: Math.atan2(p.y - pivot.y, p.x - pivot.x),
      corner: corner || null,
      pointerId: pointerId,
      changed: false,
    };
    try {
      canvas.setPointerCapture(pointerId);
    } catch (e) {}
  }

  function applySelectGesture(p) {
    if (!drag || !drag.snapshot) return;
    var live = cloneShape(drag.snapshot);
    if (drag.mode === "move") {
      translateShape(live, p.x - drag.start.x, p.y - drag.start.y);
    } else if (drag.mode === "resize") {
      var d = dist(p, drag.pivot);
      var factor = d / drag.startDist;
      if (!isFinite(factor) || factor <= 0) factor = 1;
      scaleShape(live, factor, drag.pivot.x, drag.pivot.y);
    } else if (drag.mode === "rotate") {
      var ang = Math.atan2(p.y - drag.pivot.y, p.x - drag.pivot.x);
      var deg = ((ang - drag.startAngle) * 180) / Math.PI;
      rotateShape(live, deg, drag.pivot.x, drag.pivot.y);
    }
    var idx = -1;
    for (var i = 0; i < shapes.length; i++) {
      if (shapes[i].id === drag.shapeId) {
        idx = i;
        break;
      }
    }
    if (idx < 0) return;
    live.id = drag.shapeId;
    if (JSON.stringify(shapes[idx]) !== JSON.stringify(live)) {
      drag.changed = true;
      shapes[idx] = live;
      renderShapes();
    }
    drag.last = p;
  }

  function endSelectGesture() {
    if (!drag || !drag.mode || drag.mode === "draw") return false;
    var changed = !!drag.changed;
    var shapeId = drag.shapeId;
    var snapshot = drag.snapshot;
    if (changed && snapshot) {
      var before = shapes.map(function (s) {
        return s.id === shapeId ? snapshot : s;
      });
      history.push(JSON.stringify(before));
      if (history.length > 80) history.shift();
      syncActiveField(false);
      setStatus("Şekil güncellendi");
    }
    drag = null;
    renderHandles();
    return changed;
  }

  function deleteSelectedShape() {
    if (!selectedId) return;
    var idx = -1;
    for (var i = 0; i < shapes.length; i++) {
      if (shapes[i].id === selectedId) {
        idx = i;
        break;
      }
    }
    if (idx < 0) return;
    pushHistory();
    shapes.splice(idx, 1);
    selectedId = null;
    renderShapes();
    renderPreview(null);
    if (shapes.filter(isUsable).length) syncActiveField(false);
    else syncActiveField(true);
    setStatus("Şekil silindi");
  }

  function onPointerDown(evt) {
    if (!canvas || evt.button != null && evt.button !== 0) return;
    var p = svgPoint(evt);
    if (tool === "select") {
      evt.preventDefault();
      var handleEl =
        evt.target && evt.target.closest ? evt.target.closest("[data-handle]") : null;
      if (handleEl && selectedId) {
        var shapeH = findShape(selectedId);
        if (shapeH && isUsable(shapeH)) {
          var mode = handleEl.getAttribute("data-handle") || "move";
          var corner = handleEl.getAttribute("data-corner");
          startSelectGesture(mode, shapeH, p, evt.pointerId, corner);
          setStatus(
            mode === "resize" ? "Boyutlandırılıyor…" : mode === "rotate" ? "Döndürülüyor…" : "Taşınıyor…"
          );
          return;
        }
      }
      // Prefer current shapesLayer (stem #geo-shapes or solution #geo-sol-shapes).
      var hitG =
        evt.target && evt.target.closest
          ? evt.target.closest("g[data-id]")
          : null;
      var hit =
        hitG && shapesLayer && shapesLayer.contains(hitG) ? hitG : null;
      if (hit) {
        var id = hit.getAttribute("data-id");
        selectedId = id;
        renderShapes();
        var shapeS = findShape(selectedId);
        // First click already starts move — second click was too hard to use.
        if (shapeS && isUsable(shapeS)) {
          startSelectGesture("move", shapeS, p, evt.pointerId, null);
          setStatus("Taşınıyor…");
        } else {
          setStatus("Seçili: sürükle / köşe / döndür");
        }
        return;
      }
      selectedId = null;
      clearHandles();
      renderShapes();
      setStatus("Seç: sürükle taşı · köşeden boyut · üst tutamaktan döndür · Delete sil");
      return;
    }
    if (tool === "triangle" || tool === "angle") {
      evt.preventDefault();
      clickPts.push(p);
      var need = 3;
      var guides = clickPts.slice();
      renderPreview({
        type: tool,
        _guides: guides,
        color: strokeColor(),
        stroke: strokeWidth(),
        // fake usable false until complete
        a: { x: 0, y: 0 },
        b: { x: 0, y: 0 },
        c: { x: 0, y: 0 },
        points: [],
      });
      // show guide dots
      clearLayer(previewLayer);
      guides.forEach(function (gp) {
        previewLayer.appendChild(
          el("circle", {
            cx: round2(gp.x),
            cy: round2(gp.y),
            r: 3.5,
            fill: strokeColor(),
          })
        );
      });
      if (clickPts.length >= 2) {
        previewLayer.appendChild(
          el("line", {
            x1: round2(clickPts[0].x),
            y1: round2(clickPts[0].y),
            x2: round2(clickPts[1].x),
            y2: round2(clickPts[1].y),
            stroke: strokeColor(),
            "stroke-width": strokeWidth(),
            "stroke-dasharray": "4 3",
            fill: "none",
          })
        );
      }
      setStatus(
        (tool === "triangle" ? "Üçgen" : "Açı") +
          ": " +
          clickPts.length +
          "/" +
          need +
          " nokta"
      );
      if (clickPts.length >= need) {
        var pts = clickPts.slice(0, 3);
        clickPts = [];
        if (tool === "triangle") {
          // reject near-duplicate points
          if (
            dist(pts[0], pts[1]) < MIN_LEN ||
            dist(pts[1], pts[2]) < MIN_LEN ||
            dist(pts[0], pts[2]) < MIN_LEN
          ) {
            setStatus("Üçgen için 3 ayrı nokta gerekli.");
            renderPreview(null);
            return;
          }
          commitShape({
            type: "triangle",
            points: pts.map(function (q) {
              return { x: q.x, y: q.y };
            }),
            color: strokeColor(),
            stroke: strokeWidth(),
          });
        } else {
          if (
            dist(pts[0], pts[1]) < MIN_LEN ||
            dist(pts[2], pts[1]) < MIN_LEN ||
            dist(pts[0], pts[2]) < 1
          ) {
            setStatus("Açı için 3 ayrı nokta gerekli (ışın–tepe–ışın).");
            renderPreview(null);
            return;
          }
          commitShape({
            type: "angle",
            a: { x: pts[0].x, y: pts[0].y },
            b: { x: pts[1].x, y: pts[1].y },
            c: { x: pts[2].x, y: pts[2].y },
            label: angleLabelText() || "1",
            color: strokeColor(),
            stroke: strokeWidth(),
          });
        }
      }
      return;
    }

    // drag tools
    evt.preventDefault();
    try {
      canvas.setPointerCapture(evt.pointerId);
    } catch (e) {}
    drag = { start: p, pointerId: evt.pointerId };
    renderPreview(draftFromDrag(p, p));
  }

  function onPointerMove(evt) {
    if (!drag) return;
    evt.preventDefault();
    var p = svgPoint(evt);
    if (drag.mode === "move" || drag.mode === "resize" || drag.mode === "rotate") {
      applySelectGesture(p);
      return;
    }
    renderPreview(draftFromDrag(drag.start, p));
  }

  function onPointerUp(evt) {
    if (!drag) return;
    evt.preventDefault();
    var p = svgPoint(evt);
    try {
      canvas.releasePointerCapture(evt.pointerId);
    } catch (e) {}
    if (drag.mode === "move" || drag.mode === "resize" || drag.mode === "rotate") {
      applySelectGesture(p);
      endSelectGesture();
      return;
    }
    var shape = draftFromDrag(drag.start, p);
    drag = null;
    if (shape) commitShape(shape);
    else renderPreview(null);
  }

  function undo() {
    if (!history.length) {
      setStatus("Geri alınacak yok.");
      return;
    }
    try {
      shapes = JSON.parse(history.pop()) || [];
    } catch (e) {
      shapes = [];
    }
    selectedId = null;
    clickPts = [];
    renderShapes();
    renderPreview(null);
    if (shapes.filter(isUsable).length) syncActiveField(false);
    else syncActiveField(true);
    setStatus("Geri alındı");
  }


  function looksLikeEditorSvg(text) {
    if (!text || text.indexOf("<svg") === -1) return false;
    if (/<foreignObject|<image[\s>]/i.test(text)) return false;
    // Only re-import what this editor exported (safe vs OCR dumps).
    return /data-geo-editor\s*=\s*["']?1["']?/i.test(text);
  }

  function parseImportedShapes(svgText) {
    var out = [];
    try {
      var doc = new DOMParser().parseFromString(svgText, "image/svg+xml");
      if (doc.querySelector("parsererror")) return out;
      return parseImportedShapesFromRoot(doc);
    } catch (err) {
      return [];
    }
  }

  function parseImportedShapesFromRoot(rootEl) {
    var out = [];
    if (!rootEl) return out;
    try {
      var groups = rootEl.querySelectorAll("g[data-type]");
      if (groups.length) {
        groups.forEach(function (g) {
          var type = g.getAttribute("data-type");
          var strokeNode =
            g.querySelector("line,circle,rect,polygon,path") || g;
          var color = strokeNode.getAttribute("stroke") || "#E8C87A";
          var sw = parseFloat(strokeNode.getAttribute("stroke-width") || "2") || 2;
          if (type === "line" || type === "radius") {
            var ln = g.querySelector("line");
            if (!ln) return;
            var text = g.querySelector("text");
            out.push({
              type: type,
              id: nextId(),
              x1: parseFloat(ln.getAttribute("x1")),
              y1: parseFloat(ln.getAttribute("y1")),
              x2: parseFloat(ln.getAttribute("x2")),
              y2: parseFloat(ln.getAttribute("y2")),
              label: text ? (text.textContent || "r").trim() : "r",
              color: color,
              stroke: sw,
            });
          } else if (type === "circle") {
            var cir = g.querySelector("circle");
            if (!cir) return;
            out.push({
              type: "circle",
              id: nextId(),
              cx: parseFloat(cir.getAttribute("cx")),
              cy: parseFloat(cir.getAttribute("cy")),
              r: parseFloat(cir.getAttribute("r")),
              color: color,
              stroke: sw,
            });
          } else if (type === "square") {
            var rect = g.querySelector("rect");
            if (!rect) return;
            out.push({
              type: "square",
              id: nextId(),
              x: parseFloat(rect.getAttribute("x")),
              y: parseFloat(rect.getAttribute("y")),
              size: parseFloat(rect.getAttribute("width")),
              color: color,
              stroke: sw,
            });
          } else if (type === "triangle" || type === "polygon") {
            var poly = g.querySelector("polygon");
            if (!poly) return;
            var raw = (poly.getAttribute("points") || "").trim().split(/[\s,]+/);
            var points = [];
            for (var i = 0; i + 1 < raw.length; i += 2) {
              points.push({ x: parseFloat(raw[i]), y: parseFloat(raw[i + 1]) });
            }
            if (type === "triangle" && points.length >= 3) {
              out.push({
                type: "triangle",
                id: nextId(),
                points: points.slice(0, 3),
                color: color,
                stroke: sw,
              });
            } else if (type === "polygon" && points.length >= 3) {
              out.push({
                type: "polygon",
                id: nextId(),
                points: points,
                color: color,
                stroke: sw,
              });
            }
          } else if (type === "semicircle") {
            var x1 = parseFloat(g.getAttribute("data-x1"));
            var y1 = parseFloat(g.getAttribute("data-y1"));
            var x2 = parseFloat(g.getAttribute("data-x2"));
            var y2 = parseFloat(g.getAttribute("data-y2"));
            if (isFinite(x1) && isFinite(y1) && isFinite(x2) && isFinite(y2)) {
              out.push({
                type: "semicircle",
                id: nextId(),
                x1: x1,
                y1: y1,
                x2: x2,
                y2: y2,
                color: color,
                stroke: sw,
              });
            }
          } else if (type === "angle") {
            var ax = parseFloat(g.getAttribute("data-ax"));
            var ay = parseFloat(g.getAttribute("data-ay"));
            var bx = parseFloat(g.getAttribute("data-bx"));
            var by = parseFloat(g.getAttribute("data-by"));
            var cx = parseFloat(g.getAttribute("data-cx"));
            var cy = parseFloat(g.getAttribute("data-cy"));
            var t = g.querySelector("text");
            if ([ax, ay, bx, by, cx, cy].every(isFinite)) {
              out.push({
                type: "angle",
                id: nextId(),
                a: { x: ax, y: ay },
                b: { x: bx, y: by },
                c: { x: cx, y: cy },
                label: t ? (t.textContent || "").trim() : "1",
                color: color,
                stroke: sw,
              });
            }
          }
        });
      }
    } catch (err) {
      return [];
    }
    return out.filter(isUsable);
  }

  function parseSolutionOverlayShapes(svgText) {
    if (!svgText || svgText.indexOf("<svg") === -1) return [];
    try {
      var doc = new DOMParser().parseFromString(svgText, "image/svg+xml");
      if (doc.querySelector("parsererror")) return [];
      var overlay = doc.querySelector('g[data-geo-layer="overlay"]');
      if (overlay) return parseImportedShapesFromRoot(overlay);
      // Legacy / flat solution SVG: treat all editor shapes as overlay marks.
      if (/data-geo-role\s*=\s*["']?solution["']?/i.test(svgText)) {
        return parseImportedShapesFromRoot(doc);
      }
      return parseImportedShapesFromRoot(doc);
    } catch (err) {
      return [];
    }
  }

  // Enrich render to persist geometry attrs needed for re-import
  var _renderShapeNode = renderShapeNode;
  renderShapeNode = function (shape, interactive) {
    var node = _renderShapeNode(shape, interactive);
    if (shape.type === "semicircle") {
      node.setAttribute("data-x1", round2(shape.x1));
      node.setAttribute("data-y1", round2(shape.y1));
      node.setAttribute("data-x2", round2(shape.x2));
      node.setAttribute("data-y2", round2(shape.y2));
    }
    if (shape.type === "angle") {
      node.setAttribute("data-ax", round2(shape.a.x));
      node.setAttribute("data-ay", round2(shape.a.y));
      node.setAttribute("data-bx", round2(shape.b.x));
      node.setAttribute("data-by", round2(shape.b.y));
      node.setAttribute("data-cx", round2(shape.c.x));
      node.setAttribute("data-cy", round2(shape.c.y));
    }
    return node;
  };


    function parseStemShapesFromField() {
      if (!figureField) return [];
      var text = (figureField.value || "").trim();
      if (!text || !looksLikeEditorSvg(text)) return [];
      return parseImportedShapes(text);
    }

    function stemSvgRaw() {
      if (!figureField) return "";
      return (figureField.value || "").trim();
    }

    function appendRawSvgUnderlay(svgText) {
      if (!underlayLayer || !svgText || svgText.indexOf("<svg") === -1) return false;
      try {
        var doc = new DOMParser().parseFromString(svgText, "image/svg+xml");
        if (doc.querySelector("parsererror")) return false;
        var src = doc.documentElement;
        if (!src || String(src.tagName || "").toLowerCase() !== "svg") return false;
        var wrap = el("g", { "data-geo-underlay-src": "figure-svg" });
        // Preserve viewBox scaling via nested svg when dimensions differ
        var nested = el("svg", {
          xmlns: "http://www.w3.org/2000/svg",
          viewBox: src.getAttribute("viewBox") || "0 0 " + VB_W + " " + VB_H,
          width: String(VB_W),
          height: String(VB_H),
          x: "0",
          y: "0",
        });
        Array.prototype.slice.call(src.childNodes).forEach(function (child) {
          if (child.nodeType === 1) {
            nested.appendChild(document.importNode(child, true));
          }
        });
        wrap.appendChild(nested);
        underlayLayer.appendChild(wrap);
        return true;
      } catch (err) {
        return false;
      }
    }

    function renderUnderlay() {
      if (!underlayLayer) return;
      clearLayer(underlayLayer);
      if (kind !== "solution") return;
      var parsed = parseStemShapesFromField().filter(isUsable);
      if (parsed.length) {
        parsed.forEach(function (s) {
          underlayLayer.appendChild(renderShapeNode(s, false));
        });
        return;
      }
      appendRawSvgUnderlay(stemSvgRaw());
    }

    function baseLayerMarkup() {
      var parsed = parseStemShapesFromField().filter(isUsable);
      if (parsed.length) return serializeShapeNodes(parsed);
      var raw = stemSvgRaw();
      if (!raw || raw.indexOf("<svg") === -1) return "";
      try {
        var doc = new DOMParser().parseFromString(raw, "image/svg+xml");
        if (doc.querySelector("parsererror")) return "";
        var src = doc.documentElement;
        var inner = "";
        Array.prototype.slice.call(src.childNodes).forEach(function (child) {
          if (child.nodeType === 1) {
            inner += new XMLSerializer().serializeToString(child);
          }
        });
        var vb = src.getAttribute("viewBox") || "0 0 " + VB_W + " " + VB_H;
        return (
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="' +
          vb +
          '" width="' +
          VB_W +
          '" height="' +
          VB_H +
          '" x="0" y="0">' +
          inner +
          "</svg>"
        );
      } catch (err) {
        return "";
      }
    }

    function exportSolutionSvg() {
      var overlay = shapes.filter(isUsable);
      if (!overlay.length) return "";
      var base = baseLayerMarkup();
      return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' +
        VB_W +
        " " +
        VB_H +
        '" width="400" height="320" ' +
        EDITOR_MARK +
        " " +
        SOLUTION_ROLE +
        ' fill="none">' +
        '<g data-geo-layer="base">' +
        base +
        "</g>" +
        '<g data-geo-layer="overlay">' +
        serializeShapeNodes(overlay) +
        "</g>" +
        "</svg>"
      );
    }

    function syncFigureField(forceClear) {
      if (!figureField) return;
      writeField(figureField, forceClear ? "" : exportSvg());
      if (!forceClear && exportSvg()) ensureSolutionSekilPlaceholder();
    }

    function syncSolutionField(forceClear) {
      if (!solutionField) return;
      writeField(solutionField, forceClear ? "" : exportSolutionSvg());
      if (!forceClear && exportSolutionSvg()) ensureSolutionSekilPlaceholder();
    }

    function syncActiveField(forceClear) {
      if (kind === "solution") syncSolutionField(forceClear);
      else syncFigureField(forceClear);
    }

    function modeStatusPrefix() {
      return kind === "solution"
        ? "Çözüm çizimi — soru şekli kilitli; üzerine işaret ekleyin. "
        : "Soru şekli — ";
    }

    function refreshModeStatus(extra) {
      var n = shapes.filter(isUsable).length;
      var msg = modeStatusPrefix() + (n ? n + " şekil" : "boş");
      if (extra) msg = extra;
      setStatus(msg);
    }

    function clearAll() {
      var field = kind === "solution" ? solutionField : figureField;
      if (!shapes.length && !(field && field.value.trim())) {
        setStatus("Zaten boş.");
        return;
      }
      pushHistory();
      shapes = [];
      selectedId = null;
      clickPts = [];
      renderShapes();
      renderPreview(null);
      syncActiveField(true);
      setStatus(
        kind === "solution"
          ? "Çözüm işaretleri temizlendi (soru şekli korundu)."
          : "Temizlendi"
      );
    }

    function tryImportExisting() {
      if (kind === "solution") {
        if (!solutionField) return;
        var solText = (solutionField.value || "").trim();
        if (!solText) {
          shapes = [];
          history = [];
          renderShapes();
          renderUnderlay();
          refreshModeStatus();
          return;
        }
        shapes = parseSolutionOverlayShapes(solText);
        history = [];
        renderShapes();
        renderUnderlay();
        refreshModeStatus(
          modeStatusPrefix() + (shapes.length ? shapes.length + " işaret yüklendi" : "boş")
        );
        return;
      }
      if (!figureField) return;
      var text = (figureField.value || "").trim();
      if (!text) return;
      if (!looksLikeEditorSvg(text)) {
        setStatus("Mevcut SVG (OCR/karmaşık) korundu — çizince üzerine yazılır.");
        return;
      }
      var imported = parseImportedShapes(text);
      if (!imported.length) {
        if (/data-geo-editor/i.test(text)) {
          setStatus("Kayıtlı editör SVG’si okunamadı — boş tuval.");
        }
        return;
      }
      shapes = imported;
      history = [];
      renderShapes();
      refreshModeStatus(modeStatusPrefix() + shapes.length + " şekil yüklendi");
    }

    function resolveInsertTarget() {
      var active = document.activeElement;
      var sol =
        document.getElementById("question-solution") ||
        document.querySelector('textarea[name="solution"]');
      var stem =
        document.getElementById("question-stem") ||
        document.querySelector('textarea[name="stem"]');
      if (kind === "solution" && sol) {
        if (
          !active ||
          active === sol ||
          active.id === "question-solution" ||
          (active.getAttribute && active.getAttribute("name") === "solution") ||
          !(
            active === stem ||
            active.id === "question-stem" ||
            (active.getAttribute && active.getAttribute("name") === "stem")
          )
        ) {
          return { el: sol, kind: "solution" };
        }
      }
      if (
        active &&
        sol &&
        (active === sol ||
          active.id === "question-solution" ||
          (active.getAttribute && active.getAttribute("name") === "solution"))
      ) {
        return { el: sol, kind: "solution" };
      }
      if (
        active &&
        stem &&
        (active === stem ||
          active.id === "question-stem" ||
          (active.getAttribute && active.getAttribute("name") === "stem"))
      ) {
        return { el: stem, kind: "stem" };
      }
      if (kind === "solution") return { el: sol, kind: "solution" };
      return { el: stem, kind: "stem" };
    }

    function insertFigurePlaceholder() {
      var target = resolveInsertTarget();
      var el = target.el;
      var note = document.getElementById(
        idOf("insertStatus", kind === "solution" ? "geo-sol-insert-status" : "geo-insert-status")
      );
      function say(msg) {
        if (note) note.textContent = msg;
        if (statusEl && statusEl !== note) statusEl.textContent = msg;
      }
      if (!el) {
        say(kind === "solution" ? "Çözüm metni alanı bulunamadı." : "Soru metni alanı bulunamadı.");
        return;
      }
      var value = el.value || "";
      var found = value.indexOf(FIGURE_PLACEHOLDER);
      if (found !== -1) {
        el.focus();
        try {
          el.setSelectionRange(found, found + FIGURE_PLACEHOLDER.length);
        } catch (_) {}
        say("Metinde zaten [ŞEKİL] var.");
        if (global.KpssQuestionPreview) global.KpssQuestionPreview.sync();
        return;
      }
      var start = typeof el.selectionStart === "number" ? el.selectionStart : value.length;
      var end = typeof el.selectionEnd === "number" ? el.selectionEnd : start;
      var before = value.slice(0, start);
      var after = value.slice(end);
      var padBefore =
        before && !/\n\n$/.test(before)
          ? before.slice(-1) === "\n"
            ? "\n"
            : "\n\n"
          : "";
      var padAfter =
        after && !/^\n\n/.test(after)
          ? after.charAt(0) === "\n"
            ? "\n"
            : "\n\n"
          : after
            ? ""
            : "\n";
      var insert = padBefore + FIGURE_PLACEHOLDER + padAfter;
      el.value = before + insert + after;
      var cursor = before.length + insert.length;
      el.focus();
      try {
        el.setSelectionRange(cursor, cursor);
      } catch (_) {}
      el.dispatchEvent(new Event("input", { bubbles: true }));
      if (global.KpssQuestionPreview) global.KpssQuestionPreview.sync();
      say(
        target.kind === "solution"
          ? "[ŞEKİL] çözüm metnine eklendi."
          : "[ŞEKİL] soru metnine eklendi."
      );
    }

    function bindToolbar() {
      if (!root) return;
      root.querySelectorAll(".geo-tool").forEach(function (btn) {
        btn.addEventListener("click", function () {
          setTool(btn.getAttribute("data-tool") || "select");
        });
      });
      var undoBtn = document.getElementById(
        idOf("undo", kind === "solution" ? "geo-sol-undo" : "geo-undo")
      );
      var clearBtn = document.getElementById(
        idOf("clear", kind === "solution" ? "geo-sol-clear" : "geo-clear")
      );
      var insertBtn = document.getElementById(
        idOf("insert", kind === "solution" ? "geo-sol-insert-placeholder" : "geo-insert-placeholder")
      );
      if (undoBtn) undoBtn.addEventListener("click", undo);
      if (clearBtn) clearBtn.addEventListener("click", clearAll);
      if (insertBtn) insertBtn.addEventListener("click", insertFigurePlaceholder);
      if (strokeEl && strokeValEl) {
        strokeValEl.textContent = String(strokeEl.value);
        strokeEl.addEventListener("input", function () {
          strokeValEl.textContent = String(strokeEl.value);
        });
      }
    }

    function bindCanvas() {
      if (!canvas) return;
      canvas.addEventListener("pointerdown", onPointerDown);
      canvas.addEventListener("pointermove", onPointerMove);
      canvas.addEventListener("pointerup", onPointerUp);
      canvas.addEventListener("pointercancel", onPointerUp);
      canvas.addEventListener(
        "touchstart",
        function (e) {
          if (tool !== "select") e.preventDefault();
        },
        { passive: false }
      );
    }

    function bindKeyboard() {
      document.addEventListener("keydown", function (evt) {
        if (!root || !selectedId) return;
        var tag = (evt.target && evt.target.tagName) || "";
        if (
          tag === "INPUT" ||
          tag === "TEXTAREA" ||
          tag === "SELECT" ||
          (evt.target && evt.target.isContentEditable)
        ) {
          return;
        }
        if (tool !== "select") return;
        if (evt.key === "Escape") {
          selectedId = null;
          drag = null;
          renderShapes();
          setStatus("Seçim kaldırıldı");
          return;
        }
        if (evt.key === "Delete" || evt.key === "Backspace") {
          evt.preventDefault();
          deleteSelectedShape();
        }
      });
    }

    function init() {
      root = document.getElementById(
        idOf(
          "root",
          config.rootId ||
            (kind === "solution" ? "geometry-solution-editor" : "geometry-question-editor")
        )
      );
      if (!root) return null;
      canvas = document.getElementById(
        idOf("canvas", kind === "solution" ? "geo-sol-canvas" : "geo-canvas")
      );
      shapesLayer = document.getElementById(
        idOf("shapes", kind === "solution" ? "geo-sol-shapes" : "geo-shapes")
      );
      underlayLayer = document.getElementById(
        idOf("underlay", kind === "solution" ? "geo-sol-underlay" : "geo-underlay")
      );
      previewLayer = document.getElementById(
        idOf("preview", kind === "solution" ? "geo-sol-preview" : "geo-preview")
      );
      handlesLayer = document.getElementById(
        idOf("handles", kind === "solution" ? "geo-sol-handles" : "geo-handles")
      );
      gridLayer = document.getElementById(
        idOf("grid", kind === "solution" ? "geo-sol-grid" : "geo-grid")
      );
      statusEl = document.getElementById(
        idOf("status", kind === "solution" ? "geo-sol-status" : "geo-status")
      );
      colorEl = document.getElementById(
        idOf("color", kind === "solution" ? "geo-sol-color" : "geo-color")
      );
      strokeEl = document.getElementById(
        idOf("stroke", kind === "solution" ? "geo-sol-stroke" : "geo-stroke")
      );
      strokeValEl = document.getElementById(
        idOf("strokeVal", kind === "solution" ? "geo-sol-stroke-val" : "geo-stroke-val")
      );
      angleLabelEl = document.getElementById(
        idOf("angleLabel", kind === "solution" ? "geo-sol-angle-label" : "geo-angle-label")
      );
      figureField =
        document.getElementById("figure-svg") || document.querySelector('[name="figure_svg"]');
      solutionField =
        document.getElementById("solution-figure-svg") ||
        document.querySelector('[name="solution_figure_svg"]');

      drawGrid();
      bindToolbar();
      bindCanvas();
      bindKeyboard();
      setTool("select");
      tryImportExisting();
      root.setAttribute("data-geo-mode", kind);

      if (kind === "solution") {
        renderUnderlay();
        var help = document.getElementById(idOf("help", "geo-sol-help"));
        if (help) {
          help.textContent =
            "Çözüm çizimi: alttaki soru şekli kilitli. Üzerine açı/işaret ekleyin. Seç: sürükle taşı · köşeden boyut · üst tutamaktan döndür · Delete sil. Temizle yalnızca çözüm işaretlerini siler.";
        }
        if (figureField) {
          figureField.addEventListener("input", renderUnderlay);
          figureField.addEventListener("change", renderUnderlay);
        }
        document.addEventListener("geometry-question-change", renderUnderlay);
        if (figureField && (figureField.value || "").trim()) {
          ensureSolutionSekilPlaceholder();
        }
      }

      return {
        exportSvg: exportSvg,
        exportSolutionSvg: exportSolutionSvg,
        shapes: function () {
          return shapes.slice();
        },
        clear: clearAll,
        ensureSolutionSekilPlaceholder: ensureSolutionSekilPlaceholder,
        kind: kind,
      };
    }

    return init();
  }

  global.KpssGeometryEditorCore = {
    create: create,
    FIGURE_PLACEHOLDER: FIGURE_PLACEHOLDER,
    ensureSekilInText: ensureSekilInText,
    ensureSolutionSekilPlaceholder: ensureSolutionSekilPlaceholder,
  };
})(window);
