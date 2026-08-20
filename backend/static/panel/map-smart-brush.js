/**
 * Akıllı Fırça v2 — kalınlıklı serbest stroke, kara (il birleşimi) clip.
 * Editör: window.KpssMapSmartBrush.attach(opts)
 */
(function () {
  "use strict";

  var MAX_STROKES = 12;
  var MAX_POINTS = 160;
  var MIN_DIST = 0.35;
  var MIN_WIDTH = 0.8;
  var MAX_WIDTH = 6;
  var DEFAULT_WIDTH = 2.2;

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, Number(value) || 0));
  }

  function fixed(value) {
    return Math.round(Number(value) * 100) / 100;
  }

  function polygonPath(polygons) {
    return (polygons || [])
      .map(function (ring) {
        return (
          ring
            .map(function (point, index) {
              return (index ? "L" : "M") + point[0] + " " + point[1];
            })
            .join(" ") + " Z"
        );
      })
      .join(" ");
  }

  function simplifyPoints(points) {
    if (!points.length) return [];
    var out = [points[0]];
    for (var i = 1; i < points.length; i++) {
      var prev = out[out.length - 1];
      var cur = points[i];
      var dx = cur[0] - prev[0];
      var dy = cur[1] - prev[1];
      if (Math.sqrt(dx * dx + dy * dy) >= MIN_DIST) {
        out.push(cur);
      }
    }
    var last = points[points.length - 1];
    var tip = out[out.length - 1];
    if (tip[0] !== last[0] || tip[1] !== last[1]) out.push(last);
    if (out.length > MAX_POINTS) {
      var step = Math.ceil(out.length / MAX_POINTS);
      var reduced = [];
      for (var j = 0; j < out.length; j += step) reduced.push(out[j]);
      var end = out[out.length - 1];
      var lastR = reduced[reduced.length - 1];
      if (!lastR || lastR[0] !== end[0] || lastR[1] !== end[1]) {
        reduced.push(end);
      }
      out = reduced.slice(0, MAX_POINTS);
    }
    return out;
  }

  function pathFromPoints(points) {
    if (!points.length) return "";
    var d = "";
    for (var i = 0; i < points.length; i++) {
      d += (i === 0 ? "M" : "L") + points[i][0] + " " + points[i][1] + " ";
    }
    return d.trim();
  }

  /**
   * @param {object} opts
   * @param {HTMLElement} opts.wrap
   * @param {HTMLElement} opts.fitPlane
   * @param {SVGElement} opts.layer
   * @param {function(): boolean} opts.isEnabled
   * @param {function(): boolean} opts.isModeOn
   * @param {function(): string} opts.getColor
   * @param {function(): number} opts.getWidth
   * @param {function(MouseEvent|PointerEvent, boolean=): {x:number,y:number}|null} opts.eventToPercent
   * @param {function(): void} opts.onChange
   * @param {function(boolean): void} [opts.onSuppressClick]
   */
  function attach(opts) {
    var wrap = opts.wrap;
    var fitPlane = opts.fitPlane;
    var layer = opts.layer;
    var clipPath = layer.querySelector("#map-land-clip");
    var strokesGroup = layer.querySelector("#map-brush-strokes");
    var livePath = layer.querySelector("#map-brush-live");
    var cursor = document.getElementById("map-brush-cursor");

    var strokes = [];
    var live = null;
    var pointerId = null;

    function rebuildClip(provinces) {
      if (!clipPath) return;
      clipPath.innerHTML = "";
      (provinces || []).forEach(function (province) {
        var d = polygonPath(province.polygons || []);
        if (!d) return;
        var path = document.createElementNS("http://www.w3.org/2000/svg", "path");
        path.setAttribute("d", d);
        clipPath.appendChild(path);
      });
    }

    function renderCommitted() {
      if (!strokesGroup) return;
      strokesGroup.innerHTML = "";
      strokes.forEach(function (stroke) {
        var path = document.createElementNS("http://www.w3.org/2000/svg", "path");
        path.setAttribute("d", pathFromPoints(stroke.points));
        path.setAttribute("fill", "none");
        path.setAttribute("stroke", stroke.color);
        path.setAttribute("stroke-width", String(stroke.width));
        path.setAttribute("stroke-linecap", "round");
        path.setAttribute("stroke-linejoin", "round");
        path.setAttribute("vector-effect", "non-scaling-stroke");
        // non-scaling-stroke fights % width — use user units in viewBox 0..100
        path.removeAttribute("vector-effect");
        strokesGroup.appendChild(path);
      });
    }

    function clearLive() {
      live = null;
      if (livePath) {
        livePath.setAttribute("d", "");
        livePath.setAttribute("stroke-width", "0");
      }
      wrap.classList.remove("is-brushing");
    }

    function updateLiveVisual() {
      if (!livePath || !live || !live.points.length) {
        clearLive();
        return;
      }
      livePath.setAttribute("d", pathFromPoints(live.points));
      livePath.setAttribute("stroke", live.color);
      livePath.setAttribute("stroke-width", String(live.width));
      livePath.setAttribute("stroke-linecap", "round");
      livePath.setAttribute("stroke-linejoin", "round");
      wrap.classList.add("is-brushing");
    }

    function updateCursor(event) {
      if (!cursor || !opts.isModeOn() || !opts.isEnabled()) {
        if (cursor) cursor.hidden = true;
        return;
      }
      var pt = opts.eventToPercent(event, true);
      if (!pt || !fitPlane) {
        cursor.hidden = true;
        return;
      }
      var w = clamp(opts.getWidth(), MIN_WIDTH, MAX_WIDTH);
      var rect = fitPlane.getBoundingClientRect();
      var px = Math.max(8, (w / 100) * rect.width);
      cursor.hidden = false;
      cursor.style.left = pt.x + "%";
      cursor.style.top = pt.y + "%";
      cursor.style.width = px + "px";
      cursor.style.height = px + "px";
      cursor.style.borderColor = opts.getColor() || "#111827";
    }

    function hideCursor() {
      if (cursor) cursor.hidden = true;
    }

    function commitLive() {
      if (!live || !live.points.length) {
        clearLive();
        return;
      }
      if (strokes.length >= MAX_STROKES) {
        clearLive();
        opts.onChange();
        return;
      }
      var points = simplifyPoints(live.points);
      if (!points.length) {
        clearLive();
        return;
      }
      strokes.push({
        shape: "brush",
        color: live.color,
        width: fixed(clamp(live.width, MIN_WIDTH, MAX_WIDTH)),
        points: points,
      });
      clearLive();
      renderCommitted();
      opts.onChange();
    }

    function startStroke(event) {
      if (!opts.isModeOn() || !opts.isEnabled()) return false;
      if (event.button != null && event.button !== 0) return false;
      if (strokes.length >= MAX_STROKES) return false;
      var pt = opts.eventToPercent(event, true);
      if (!pt) return false;
      live = {
        color: opts.getColor() || "#111827",
        width: clamp(opts.getWidth(), MIN_WIDTH, MAX_WIDTH),
        points: [[fixed(pt.x), fixed(pt.y)]],
      };
      pointerId = event.pointerId;
      try {
        wrap.setPointerCapture(event.pointerId);
      } catch (_) {}
      updateLiveVisual();
      if (opts.onSuppressClick) opts.onSuppressClick(true);
      return true;
    }

    function moveStroke(event) {
      if (!live) return;
      var pt = opts.eventToPercent(event, true);
      if (!pt) return;
      var last = live.points[live.points.length - 1];
      var dx = pt.x - last[0];
      var dy = pt.y - last[1];
      var dist = Math.sqrt(dx * dx + dy * dy);
      var steps = Math.max(1, Math.ceil(dist / 0.45));
      for (var i = 1; i <= steps; i++) {
        var t = i / steps;
        live.points.push([
          fixed(last[0] + dx * t),
          fixed(last[1] + dy * t),
        ]);
      }
      if (live.points.length > MAX_POINTS * 2) {
        live.points = simplifyPoints(live.points);
      }
      updateLiveVisual();
      updateCursor(event);
    }

    function endStroke(event) {
      if (!live) return;
      if (pointerId != null && event && event.pointerId !== pointerId) return;
      try {
        if (pointerId != null && wrap.releasePointerCapture) {
          wrap.releasePointerCapture(pointerId);
        }
      } catch (_) {}
      pointerId = null;
      commitLive();
    }

    wrap.addEventListener("pointerdown", function (event) {
      if (!opts.isModeOn() || !opts.isEnabled()) return;
      if (event.target.closest(".map-marker, .map-line-handle, .map-city-label-pin")) {
        return;
      }
      if (startStroke(event)) event.preventDefault();
    });
    wrap.addEventListener("pointermove", function (event) {
      if (opts.isModeOn() && opts.isEnabled()) updateCursor(event);
      if (live) moveStroke(event);
    });
    wrap.addEventListener("pointerup", endStroke);
    wrap.addEventListener("pointercancel", endStroke);
    wrap.addEventListener("pointerleave", function () {
      if (!live) hideCursor();
    });
    wrap.addEventListener("lostpointercapture", function () {
      if (live) {
        pointerId = null;
        commitLive();
      }
    });

    return {
      MIN_WIDTH: MIN_WIDTH,
      MAX_WIDTH: MAX_WIDTH,
      DEFAULT_WIDTH: DEFAULT_WIDTH,
      MAX_STROKES: MAX_STROKES,
      setProvinces: function (provinces) {
        rebuildClip(provinces);
      },
      load: function (items) {
        strokes = (items || [])
          .filter(function (item) {
            return item && item.shape === "brush" && Array.isArray(item.points);
          })
          .slice(0, MAX_STROKES)
          .map(function (item) {
            return {
              shape: "brush",
              color: /^#[0-9a-f]{6}$/i.test(item.color || "")
                ? item.color
                : "#111827",
              width: fixed(clamp(item.width, MIN_WIDTH, MAX_WIDTH)),
              points: simplifyPoints(
                item.points.map(function (p) {
                  return [fixed(clamp(p[0], 0, 100)), fixed(clamp(p[1], 0, 100))];
                })
              ),
            };
          });
        clearLive();
        renderCommitted();
      },
      getStrokes: function () {
        return strokes.slice();
      },
      clear: function () {
        strokes = [];
        clearLive();
        renderCommitted();
      },
      count: function () {
        return strokes.length;
      },
      setModeVisual: function (on) {
        wrap.classList.toggle("is-brush", Boolean(on));
        if (!on) {
          hideCursor();
          if (live) {
            clearLive();
          }
        }
      },
      hideCursor: hideCursor,
      paintPreview: function (ctx, canvasW, canvasH, provinces) {
        // Soft client preview: stamp ellipses then mask by province hit
        // (server uses same land union). For speed, clip via destination-in
        // using a temp land mask.
        if (!strokes.length) return;
        var tmp = document.createElement("canvas");
        tmp.width = canvasW;
        tmp.height = canvasH;
        var tctx = tmp.getContext("2d");
        strokes.forEach(function (stroke) {
          var r = Math.max(1, (stroke.width / 100) * canvasW * 0.5);
          tctx.fillStyle = stroke.color;
          var pts = stroke.points;
          for (var i = 0; i < pts.length; i++) {
            var x = (pts[i][0] / 100) * canvasW;
            var y = (pts[i][1] / 100) * canvasH;
            tctx.beginPath();
            tctx.arc(x, y, r, 0, Math.PI * 2);
            tctx.fill();
            if (i > 0) {
              var x0 = (pts[i - 1][0] / 100) * canvasW;
              var y0 = (pts[i - 1][1] / 100) * canvasH;
              var dx = x - x0;
              var dy = y - y0;
              var dist = Math.sqrt(dx * dx + dy * dy);
              var steps = Math.max(1, Math.ceil(dist / (r * 0.6)));
              for (var s = 1; s < steps; s++) {
                var tt = s / steps;
                tctx.beginPath();
                tctx.arc(x0 + dx * tt, y0 + dy * tt, r, 0, Math.PI * 2);
                tctx.fill();
              }
            }
          }
        });
        // Land mask — tüm illerin birleşimi (destination-in ile tek seferde)
        if (provinces && provinces.length) {
          var mask = document.createElement("canvas");
          mask.width = canvasW;
          mask.height = canvasH;
          var mctx = mask.getContext("2d");
          mctx.fillStyle = "#fff";
          provinces.forEach(function (province) {
            (province.polygons || []).forEach(function (ring) {
              if (!ring.length) return;
              mctx.beginPath();
              ring.forEach(function (point, index) {
                var px = (point[0] / 100) * canvasW;
                var py = (point[1] / 100) * canvasH;
                if (index === 0) mctx.moveTo(px, py);
                else mctx.lineTo(px, py);
              });
              mctx.closePath();
              mctx.fill();
            });
          });
          tctx.globalCompositeOperation = "destination-in";
          tctx.drawImage(mask, 0, 0);
        }
        ctx.drawImage(tmp, 0, 0);
      },
    };
  }

  window.KpssMapSmartBrush = {
    attach: attach,
    MIN_WIDTH: MIN_WIDTH,
    MAX_WIDTH: MAX_WIDTH,
    DEFAULT_WIDTH: DEFAULT_WIDTH,
  };
})();
