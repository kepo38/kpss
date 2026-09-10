/**
 * Coordinate editor for reusable Turkey map questions.
 * Coordinates and marker sizes are normalized percentages.
 */
(function () {
  "use strict";

  var MAX_MARKERS = 12;
  var MAP_PLACEHOLDER = "[HARITA]";
  var ROMAN = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"];
  var DEFAULT_ELLIPSE = {
    shape: "ellipse",
    x: 50,
    y: 50,
    width: 4.5,
    height: 3.5,
    rotation: 0,
    color: "#c026d3",
    labelSide: "right",
    showLabel: false,
    labelSizeDelta: 0,
  };
  var DEFAULT_CIRCLE = {
    shape: "circle",
    x: 50,
    y: 50,
    width: 2.6,
    height: 2.6,
    rotation: 0,
    color: "#c026d3",
    labelSide: "right",
    showLabel: false,
    labelSizeDelta: 0,
  };
  var DEFAULT_LINE = {
    shape: "line",
    x: 42,
    y: 16,
    x2: 50,
    y2: 84,
    width: 0.5,
    height: 0,
    rotation: 0,
    color: "#ef4444",
    labelSide: "right",
    showLabel: true,
    label: "",
    startLabel: "",
    endLabel: "",
    labelCustom: false,
  };
  var DEFAULT_FILL_COLOR = "#111827";

  function pointInRing(x, y, ring) {
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      var xi = ring[i][0];
      var yi = ring[i][1];
      var xj = ring[j][0];
      var yj = ring[j][1];
      if (yi === yj) continue;
      if ((yi > y) !== (yj > y) && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) {
        inside = !inside;
      }
    }
    return inside;
  }

  function polygonPath(polygons) {
    return polygons
      .map(function (ring) {
        return ring
          .map(function (point, index) {
            return (index ? "L" : "M") + point[0] + " " + point[1];
          })
          .join(" ") + " Z";
      })
      .join(" ");
  }

  function normalizeMarker(marker) {
    if (marker && marker.shape === "line") {
      return {
        shape: "line",
        x: fixed(clamp(marker && marker.x, 0, 100)),
        y: fixed(clamp(marker && marker.y, 0, 100)),
        x2: fixed(clamp(marker && marker.x2 != null ? marker.x2 : 50, 0, 100)),
        y2: fixed(clamp(marker && marker.y2 != null ? marker.y2 : 80, 0, 100)),
        width: fixed(clamp(marker && marker.width ? marker.width : 0.5, 0.4, 4)),
        height: 0,
        rotation: 0,
        color: /^#[0-9a-f]{6}$/i.test((marker && marker.color) || "")
          ? marker.color
          : DEFAULT_LINE.color,
        labelSide: "right",
        showLabel: marker && Object.prototype.hasOwnProperty.call(marker, "showLabel")
          ? marker.showLabel !== false
          : Boolean(
              String(
                (marker && (marker.label || marker.startLabel || marker.endLabel)) || ""
              ).trim()
            ),
        label: String((marker && marker.label) || "").trim().slice(0, 80),
        startLabel: String((marker && marker.startLabel) || "").trim().slice(0, 40),
        endLabel: String((marker && marker.endLabel) || "").trim().slice(0, 40),
        labelCustom: Boolean(marker && marker.labelCustom),
      };
    }
    if (marker && marker.shape === "city-label") {
      return {
        shape: "city-label",
        x: fixed(clamp(marker && marker.x, 0, 100)),
        y: fixed(clamp(marker && marker.y, 0, 100)),
        width: 0,
        height: 0,
        rotation: 0,
        color: "#111827",
        labelSide: "right",
        showLabel: marker && Object.prototype.hasOwnProperty.call(marker, "showLabel")
          ? marker.showLabel !== false
          : Boolean(String((marker && marker.label) || "").trim()),
        label: String((marker && marker.label) || "").trim().slice(0, 40),
        labelCustom: Boolean(marker && marker.labelCustom),
      };
    }
    var shape = marker && marker.shape === "circle" ? "circle" : "ellipse";
    var width = fixed(clamp(marker && marker.width ? marker.width : (shape === "circle" ? 2.6 : 4.5), 1, 15));
    var height = fixed(clamp(marker && marker.height ? marker.height : (shape === "circle" ? 2.6 : 3.5), 1, 15));
    if (shape === "circle") {
      height = width;
    }
    var showLabel = true;
    if (marker && Object.prototype.hasOwnProperty.call(marker, "showLabel")) {
      showLabel = marker.showLabel !== false;
    }
    return {
      shape: shape,
      x: fixed(clamp(marker && marker.x, 0, 100)),
      y: fixed(clamp(marker && marker.y, 0, 100)),
      width: width,
      height: height,
      rotation: shape === "circle" ? 0 : Math.round(clamp(marker && marker.rotation, 0, 179)),
      color: /^#[0-9a-f]{6}$/i.test((marker && marker.color) || "")
        ? marker.color
        : DEFAULT_ELLIPSE.color,
      labelSide: ["left", "right", "top", "bottom"].includes(marker && marker.labelSide)
        ? marker.labelSide
        : "right",
      showLabel: showLabel,
      labelSizeDelta: normalizeLabelSizeDelta(marker && marker.labelSizeDelta),
    };
  }

  function normalizeLabelSizeDelta(raw) {
    var n = Math.round(Number(raw) || 0);
    if (!Number.isFinite(n)) n = 0;
    n = Math.round(n / 2) * 2;
    return Math.max(-20, Math.min(40, n));
  }

  function romanBasePx(canvasWidth) {
    return Math.max(68, Math.round(canvasWidth * 0.048));
  }

  function romanPxForMarker(canvasWidth, marker) {
    return Math.max(
      28,
      romanBasePx(canvasWidth) + normalizeLabelSizeDelta(marker && marker.labelSizeDelta)
    );
  }

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, Number(value) || 0));
  }

  function fixed(value) {
    return Math.round(Number(value) * 100) / 100;
  }

  function init() {
    var root = document.getElementById("map-question-editor");
    if (!root) return;

    var template = document.getElementById("map-template");
    var hidden = document.getElementById("map-markers");
    var body = document.getElementById("map-editor-body");
    var wrap = document.getElementById("map-canvas-wrap");
    var fitPlane = document.getElementById("map-fit-plane");
    var layer = document.getElementById("map-marker-layer");
    var baseImage = document.getElementById("map-base-image");
    var previewImage = document.createElement("img");
    previewImage.src = root.dataset.mapSrc || baseImage.src;
    var controls = document.getElementById("map-marker-controls");
    var expandButton = document.getElementById("map-zoom-expand");
    var addButton = document.getElementById("map-add-marker");
    var addCircleButton = document.getElementById("map-add-circle");
    var addLineButton = document.getElementById("map-add-line");
    var addSpokeButton = document.getElementById("map-add-spoke");
    var addCityLabelButton = document.getElementById("map-add-city-label");
    var cityLabelsButton = document.getElementById("map-city-labels-toggle");
    var lineCountWrap = document.getElementById("map-line-count-wrap");
    var lineCountInput = document.getElementById("map-line-count");
    var lineCountOk = document.getElementById("map-line-count-ok");
    var lineWidthWrap = document.getElementById("map-line-width-wrap");
    var lineWidthInput = document.getElementById("map-line-width");
    var lineWidthVal = document.getElementById("map-line-width-val");
    var clearButton = document.getElementById("map-clear-markers");
    var insertPlaceholderButton = document.getElementById("map-insert-placeholder");
    var insertStatus = document.getElementById("map-insert-status");
    var stemField = document.getElementById("question-stem");
    var status = document.getElementById("map-editor-status");
    var initialData = document.getElementById("map-markers-data");
    var templatesData = document.getElementById("map-templates-data");
    var mapTemplates = {};
    var fillLayer = document.getElementById("map-fill-layer");
    var brushLayer = document.getElementById("map-brush-layer");
    var paintButton = document.getElementById("map-paint-toggle");
    var brushButton = document.getElementById("map-brush-toggle");
    var fillColorInput = document.getElementById("map-fill-color");
    var fillColorWrap = document.getElementById("map-fill-color-wrap");
    var brushWidthWrap = document.getElementById("map-brush-width-wrap");
    var brushWidthInput = document.getElementById("map-brush-width");
    var brushWidthVal = document.getElementById("map-brush-width-val");
    var markers = [];
    var fills = [];
    var provinces = [];
    var paintMode = false;
    var brushMode = false;
    var brushWidth = (window.KpssMapSmartBrush && window.KpssMapSmartBrush.DEFAULT_WIDTH) || 2.2;
    var smartBrush = null;
    var initialBrushes = [];
    var lineMode = false;
    var spokeMode = false;
    var cityLabelMode = false;
    var ellipseMode = false;
    var lineDraft = null;
    var lineSpokeLeft = 0;
    var lineAwaitCount = false;
    var lineWidth = 0.5;
    var cityLabelsOn = true;
    var fillColor = DEFAULT_FILL_COLOR;
    var selected = -1;
    var drag = null;
    var suppressMapClick = false;

    try {
      mapTemplates = templatesData ? JSON.parse(templatesData.textContent || "{}") : {};
    } catch (_) {
      mapTemplates = {};
    }

    try {
      var initialItems = initialData ? JSON.parse(initialData.textContent || "[]") : [];
      if (!Array.isArray(initialItems)) initialItems = [];
      initialItems.forEach(function (item) {
        if (item && item.shape === "fill" && item.province) {
          fills.push({
            province: String(item.province),
            color: /^#[0-9a-f]{6}$/i.test(item.color || "") ? item.color : DEFAULT_FILL_COLOR,
          });
        } else if (item && item.shape === "brush") {
          initialBrushes.push(item);
        } else {
          markers.push(normalizeMarker(item));
        }
      });
    } catch (_) {
      markers = [];
      fills = [];
      initialBrushes = [];
    }
    markers = markers.slice(0, MAX_MARKERS);
    var loadedLines = markers.filter(function (marker) {
      return marker.shape === "line" || marker.shape === "city-label";
    });
    if (loadedLines.length) {
      cityLabelsOn = loadedLines.some(function (marker) {
        return marker.showLabel !== false;
      });
    }

    function mapPlane() {
      return fitPlane || wrap;
    }

    function syncFitPlane() {
      if (!fitPlane || !wrap || !baseImage) return;
      var cs = window.getComputedStyle(wrap);
      var padL = parseFloat(cs.paddingLeft) || 0;
      var padT = parseFloat(cs.paddingTop) || 0;
      var padR = parseFloat(cs.paddingRight) || 0;
      var padB = parseFloat(cs.paddingBottom) || 0;
      var contentW = Math.max(0, wrap.clientWidth - padL - padR);
      var contentH = Math.max(0, wrap.clientHeight - padT - padB);
      var nw = baseImage.naturalWidth;
      var nh = baseImage.naturalHeight;
      var w = contentW;
      var h = contentH;
      var x = padL;
      var y = padT;
      if (nw > 0 && nh > 0 && contentW > 0 && contentH > 0) {
        var scale = Math.min(contentW / nw, contentH / nh);
        w = nw * scale;
        h = nh * scale;
        x = padL + (contentW - w) / 2;
        y = padT + (contentH - h) / 2;
      }
      fitPlane.style.left = x + "px";
      fitPlane.style.top = y + "px";
      fitPlane.style.width = w + "px";
      fitPlane.style.height = h + "px";
    }

    function eventToMapPercent(event, clampOutside) {
      var rect = mapPlane().getBoundingClientRect();
      if (!rect.width || !rect.height) return null;
      var x = ((event.clientX - rect.left) / rect.width) * 100;
      var y = ((event.clientY - rect.top) / rect.height) * 100;
      if (!clampOutside && (x < -0.8 || x > 100.8 || y < -0.8 || y > 100.8)) {
        return null;
      }
      return { x: fixed(clamp(x, 0, 100)), y: fixed(clamp(y, 0, 100)) };
    }

    function currentTemplate() {
      return mapTemplates[template.value] || null;
    }

    function markerMode() {
      var entry = currentTemplate();
      return Boolean(entry && entry.kind === "marker");
    }

    function staticMode() {
      var entry = currentTemplate();
      return Boolean(entry && entry.kind === "static");
    }

    function mapActive() {
      return markerMode() || staticMode();
    }

    function paintEnabled() {
      var entry = currentTemplate();
      return Boolean(entry && entry.kind === "marker" && entry.paint);
    }

    function applyTemplateAssets() {
      var entry = currentTemplate();
      if (!entry) return;
      if (entry.editor_asset) {
        baseImage.src = entry.editor_asset;
      } else if (entry.asset) {
        baseImage.src = entry.asset;
      }
      previewImage.src = entry.asset || previewImage.src;
    }

    function enabled() {
      return markerMode();
    }

    function serialize() {
      var brushItems = smartBrush ? smartBrush.getStrokes() : [];
      hidden.value = JSON.stringify(
        fills
          .map(function (fill) {
            return { shape: "fill", province: fill.province, color: fill.color };
          })
          .concat(brushItems)
          .concat(markers)
      );
      var parts = [];
      if (fills.length) parts.push(fills.length + " il boyalı");
      if (brushItems.length) parts.push(brushItems.length + " fırça");
      if (markers.length) parts.push(markers.length + " işaret");
      if (spokeMode && !lineDraft) {
        status.textContent = "Merkezi tıklayın";
      } else if (spokeMode && lineAwaitCount) {
        status.textContent = "Kaç doğru çizilecek?";
      } else if (spokeMode && lineDraft && lineSpokeLeft > 0) {
        status.textContent = "Hedef ili tıklayın (kalan: " + lineSpokeLeft + ")";
      } else if (lineMode && !lineDraft) {
        status.textContent = "Doğrunun başlangıcını tıklayın";
      } else if (lineMode && lineDraft) {
        status.textContent = "Doğrunun bitişini tıklayın";
      } else if (cityLabelMode) {
        status.textContent = "İli tıklayın — adı doğru/ışın etiketi gibi görünsün";
      } else if (ellipseMode) {
        status.textContent = "Elips koymak için haritaya tıklayın";
      } else {
        status.textContent = parts.length
          ? parts.join(" · ")
          : brushMode
            ? "Akıllı Fırça: sürükleyerek boyayın (kara dışına yazılmaz)"
            : paintMode
              ? "İl boyamak için haritaya tıklayın"
              : "Bir araç seçin";
      }
    }

    function renderFills() {
      if (!fillLayer) return;
      fillLayer.innerHTML = "";
      var byId = {};
      provinces.forEach(function (province) {
        byId[province.id] = province;
      });
      fills.forEach(function (fill) {
        var province = byId[fill.province];
        if (!province) return;
        var path = document.createElementNS("http://www.w3.org/2000/svg", "path");
        path.setAttribute("d", polygonPath(province.polygons || []));
        path.setAttribute("fill", fill.color);
        path.setAttribute("fill-opacity", "0.88");
        path.setAttribute("stroke", "none");
        fillLayer.appendChild(path);
      });
    }

    function hitProvince(x, y) {
      for (var i = 0; i < provinces.length; i++) {
        var rings = provinces[i].polygons || [];
        for (var r = 0; r < rings.length; r++) {
          if (pointInRing(x, y, rings[r])) return provinces[i];
        }
      }
      return null;
    }

    function cityAt(x, y) {
      var hit = hitProvince(x, y);
      return hit && hit.name ? hit.name : "";
    }

    function lineEndNames(marker) {
      var startName = String(marker.startLabel || "").trim();
      var endName = String(marker.endLabel || "").trim();
      if (startName || endName) return { start: startName, end: endName };
      var parts = String(marker.label || "")
        .split("·")
        .map(function (part) {
          return part.trim();
        })
        .filter(Boolean);
      if (!parts.length) {
        return { start: cityAt(marker.x, marker.y), end: cityAt(marker.x2, marker.y2) };
      }
      if (parts.length === 1) return { start: "", end: parts[0] };
      return { start: parts[0], end: parts[parts.length - 1] };
    }

    function syncLineLabel(marker) {
      if (!marker || marker.shape !== "line") return;
      var startName = cityAt(marker.x, marker.y);
      var endName = cityAt(marker.x2, marker.y2);
      marker.startLabel = startName;
      if (!marker.labelCustom) marker.endLabel = endName;
      else if (!marker.endLabel) marker.endLabel = endName;
      marker.label = [marker.startLabel, marker.endLabel].filter(Boolean).join(" · ");
    }

    function syncCityLabel(marker) {
      if (!marker || marker.shape !== "city-label" || marker.labelCustom) return;
      marker.label = cityAt(marker.x, marker.y);
    }

    function setCityLabelsOn(on) {
      cityLabelsOn = Boolean(on);
      markers.forEach(function (marker) {
        if (marker.shape === "line") {
          marker.showLabel = cityLabelsOn;
          if (cityLabelsOn) syncLineLabel(marker);
        } else if (marker.shape === "city-label") {
          marker.showLabel = cityLabelsOn;
        }
      });
    }

    function appendCityName(layerEl, name, x, y, extraClass) {
      if (!name) return;
      var el = document.createElement("span");
      el.className = "map-line-city" + (extraClass ? " " + extraClass : "");
      el.textContent = name;
      el.style.left = clamp(x, 1, 99) + "%";
      el.style.top = clamp(y, 1, 99) + "%";
      layerEl.appendChild(el);
    }

    function appendSpokeLabel(layerEl, marker) {
      if (!marker.showLabel) return;
      var names = lineEndNames(marker);
      if (!names.end) return;
      var dx = marker.x2 - marker.x;
      var dy = marker.y2 - marker.y;
      var len = Math.sqrt(dx * dx + dy * dy) || 1;
      appendCityName(
        layerEl,
        names.end,
        marker.x2 + (dx / len) * 3.8,
        marker.y2 + (dy / len) * 3.8
      );
    }

    function appendHubLabels(layerEl) {
      var hubs = {};
      markers.forEach(function (marker) {
        if (marker.shape !== "line" || !marker.showLabel) return;
        var names = lineEndNames(marker);
        var key = Number(marker.x).toFixed(1) + "," + Number(marker.y).toFixed(1);
        if (names.start && !hubs[key]) {
          hubs[key] = { name: names.start, x: marker.x, y: marker.y };
        }
      });
      Object.keys(hubs).forEach(function (key) {
        var hub = hubs[key];
        appendCityName(layerEl, hub.name, hub.x, hub.y - 4.2, "is-hub");
      });
    }

    function toggleFill(provinceId) {
      var index = -1;
      for (var i = 0; i < fills.length; i++) {
        if (fills[i].province === provinceId) {
          index = i;
          break;
        }
      }
      if (index >= 0) {
        if (fills[index].color.toLowerCase() === fillColor.toLowerCase()) {
          fills.splice(index, 1);
        } else {
          fills[index].color = fillColor;
        }
      } else {
        fills.push({ province: provinceId, color: fillColor });
      }
      renderFills();
      serialize();
      notify();
    }

    function pinLabel(index) {
      var n = 0;
      var i;
      for (i = 0; i <= index; i++) {
        if (markers[i].shape !== "line" && markers[i].shape !== "city-label") n += 1;
      }
      return ROMAN[Math.max(0, n - 1)] || String(n);
    }

    function currentLineWidth() {
      if (lineWidthInput) {
        return fixed(clamp(lineWidthInput.value, 0.4, 4));
      }
      return lineWidth;
    }

    function lineStrokePx(marker) {
      return Math.max(2, (mapPlane().clientWidth * (marker.width || 0.5)) / 100);
    }

    function lineHandle(marker, index, which) {
      var handle = document.createElement("button");
      handle.type = "button";
      handle.className = "map-line-handle";
      handle.style.left = (which === "end" ? marker.x2 : marker.x) + "%";
      handle.style.top = (which === "end" ? marker.y2 : marker.y) + "%";
      handle.style.backgroundColor = marker.color;
      handle.setAttribute("aria-label", which === "end" ? "Bitiş noktası" : "Başlangıç noktası");
      handle.addEventListener("click", function (event) {
        event.stopPropagation();
        selected = index;
        render();
      });
      handle.addEventListener("pointerdown", function (event) {
        event.preventDefault();
        event.stopPropagation();
        selected = index;
        suppressMapClick = true;
        handle.setPointerCapture(event.pointerId);
        drag = { type: "line-end", which: which, pointerId: event.pointerId, handle: handle };
        renderControls();
      });
      handle.addEventListener("pointermove", function (event) {
        if (!drag || drag.type !== "line-end" || drag.pointerId !== event.pointerId) return;
        var pt = eventToMapPercent(event, true);
        if (!pt) return;
        var nx = pt.x;
        var ny = pt.y;
        if (which === "end") {
          markers[index].x2 = nx;
          markers[index].y2 = ny;
        } else {
          markers[index].x = nx;
          markers[index].y = ny;
        }
        handle.style.left = nx + "%";
        handle.style.top = ny + "%";
        var svgLine = handle.parentNode && handle.parentNode.querySelector("line");
        if (svgLine) {
          svgLine.setAttribute(which === "end" ? "x2" : "x1", String(nx));
          svgLine.setAttribute(which === "end" ? "y2" : "y1", String(ny));
        }
        serialize();
        renderControls();
        notify();
      });
      handle.addEventListener("pointerup", function () {
        if (drag && drag.type === "line-end") {
          drag = null;
          syncLineLabel(markers[index]);
          render();
        }
      });
      handle.addEventListener("pointercancel", function () {
        if (drag && drag.type === "line-end") drag = null;
      });
      return handle;
    }

    function lineHtml(marker, index) {
      var group = document.createElement("div");
      group.className = "map-line" + (selected === index ? " is-selected" : "");
      group.dataset.index = String(index);
      var svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
      svg.setAttribute("viewBox", "0 0 100 100");
      svg.setAttribute("preserveAspectRatio", "none");
      svg.classList.add("map-line-svg");
      var line = document.createElementNS("http://www.w3.org/2000/svg", "line");
      line.setAttribute("x1", String(marker.x));
      line.setAttribute("y1", String(marker.y));
      line.setAttribute("x2", String(marker.x2));
      line.setAttribute("y2", String(marker.y2));
      line.setAttribute("stroke", marker.color);
      line.setAttribute("stroke-linecap", "round");
      line.setAttribute("vector-effect", "non-scaling-stroke");
      line.setAttribute("stroke-width", String(lineStrokePx(marker)));
      line.addEventListener("click", function (event) {
        if (lineMode || spokeMode || cityLabelMode) return;
        event.stopPropagation();
        selected = index;
        render();
      });
      svg.appendChild(line);
      group.appendChild(svg);
      group.appendChild(lineHandle(marker, index, "start"));
      group.appendChild(lineHandle(marker, index, "end"));
      return group;
    }

    function cityLabelHtml(marker, index) {
      var node = document.createElement("button");
      node.type = "button";
      node.className =
        "map-city-label-pin" + (selected === index ? " is-selected" : "");
      node.dataset.index = String(index);
      node.style.left = marker.x + "%";
      node.style.top = marker.y + "%";
      node.setAttribute("aria-label", (marker.label || "İl adı") + " etiketi");
      var label = document.createElement("span");
      label.className = "map-line-city is-standalone";
      label.textContent = marker.showLabel !== false ? marker.label || "" : "";
      node.appendChild(label);
      node.addEventListener("click", function (event) {
        if (lineMode || spokeMode || cityLabelMode) return;
        event.stopPropagation();
        selected = index;
        render();
      });
      node.addEventListener("pointerdown", function (event) {
        if (lineMode || spokeMode || cityLabelMode) return;
        event.preventDefault();
        event.stopPropagation();
        selected = index;
        suppressMapClick = true;
        node.setPointerCapture(event.pointerId);
        drag = { type: "move", pointerId: event.pointerId, node: node };
        renderControls();
      });
      node.addEventListener("pointermove", function (event) {
        if (!drag || drag.type !== "move" || drag.pointerId !== event.pointerId) return;
        var pt = eventToMapPercent(event, true);
        if (!pt) return;
        markers[index].x = pt.x;
        markers[index].y = pt.y;
        node.style.left = pt.x + "%";
        node.style.top = pt.y + "%";
        if (!markers[index].labelCustom) syncCityLabel(markers[index]);
        label.textContent =
          markers[index].showLabel !== false ? markers[index].label || "" : "";
        serialize();
        renderControls();
        notify();
      });
      node.addEventListener("pointerup", function () {
        if (drag && drag.type === "move") {
          drag = null;
          render();
        }
      });
      node.addEventListener("pointercancel", function () {
        if (drag && drag.type === "move") drag = null;
      });
      return node;
    }

    function appendResizeHandles(node, marker, index, shapeEl) {
      function bindHandle(handle, axis) {
        handle.title = axis === "e" ? "Genişlik" : axis === "s" ? "Yükseklik" : "Boyut";
        handle.addEventListener("pointerdown", function (event) {
          event.preventDefault();
          event.stopPropagation();
          selected = index;
          suppressMapClick = true;
          handle.setPointerCapture(event.pointerId);
          var plane = mapPlane().getBoundingClientRect();
          drag = {
            type: "resize",
            axis: axis,
            pointerId: event.pointerId,
            node: node,
            shape: shapeEl,
            startX: event.clientX,
            startY: event.clientY,
            startWidth: markers[index].width,
            startHeight: markers[index].height,
            planeWidth: plane.width,
            planeHeight: plane.height,
          };
          renderControls();
        });
        handle.addEventListener("pointermove", function (event) {
          if (!drag || drag.type !== "resize" || drag.pointerId !== event.pointerId) return;
          var dx = ((event.clientX - drag.startX) / drag.planeWidth) * 100;
          var dy = ((event.clientY - drag.startY) / drag.planeHeight) * 100;
          if (drag.axis === "e" || drag.axis === "se") {
            markers[index].width = fixed(clamp(drag.startWidth + dx * 2, 1, 15));
          }
          if (drag.axis === "s" || drag.axis === "se") {
            markers[index].height = fixed(clamp(drag.startHeight + dy * 2, 1, 15));
          }
          if (marker.shape === "circle") {
            var next = Math.max(markers[index].width, markers[index].height);
            markers[index].width = next;
            markers[index].height = next;
          }
          node.style.width = markers[index].width + "%";
          if (marker.shape === "circle") {
            node.style.height = "";
          } else {
            node.style.height = markers[index].height + "%";
          }
          serialize();
          notify();
        });
        handle.addEventListener("pointerup", function () {
          if (drag && drag.type === "resize") drag = null;
          renderControls();
        });
        handle.addEventListener("pointercancel", function () {
          if (drag && drag.type === "resize") drag = null;
          renderControls();
        });
        node.appendChild(handle);
      }

      if (marker.shape === "circle") {
        var corner = document.createElement("span");
        corner.className = "map-marker-resize-handle is-se";
        bindHandle(corner, "se");
        return;
      }
      var east = document.createElement("span");
      east.className = "map-marker-resize-handle is-e";
      bindHandle(east, "e");
      var south = document.createElement("span");
      south.className = "map-marker-resize-handle is-s";
      bindHandle(south, "s");
    }

    function markerHtml(marker, index) {
      if (marker.shape === "line") return lineHtml(marker, index);
      if (marker.shape === "city-label") return cityLabelHtml(marker, index);
      var node = document.createElement("button");
      node.type = "button";
      node.className =
        "map-marker" +
        (marker.shape === "circle" ? " is-circle" : " is-ellipse") +
        (selected === index ? " is-selected" : "");
      node.dataset.index = String(index);
      node.style.left = marker.x + "%";
      node.style.top = marker.y + "%";
      node.style.width = marker.width + "%";
      if (marker.shape === "circle") {
        node.style.height = "";
        node.style.aspectRatio = "1 / 1";
      } else {
        node.style.height = marker.height + "%";
        node.style.aspectRatio = "";
      }
      node.style.backgroundColor = "transparent";
      node.setAttribute("aria-label", pinLabel(index) + " numaralı işaret");

      var shape = document.createElement("span");
      shape.className = "map-marker-shape";
      shape.style.backgroundColor = marker.color;
      shape.style.transform =
        marker.shape === "circle" ? "none" : "rotate(" + (marker.rotation || 0) + "deg)";
      node.appendChild(shape);

      if (marker.showLabel !== false) {
        var label = document.createElement("span");
        label.className = "map-marker-label is-" + marker.labelSide;
        label.textContent = pinLabel(index);
        var delta = normalizeLabelSizeDelta(marker.labelSizeDelta);
        if (delta !== 0) {
          label.style.fontSize =
            "calc(clamp(12px, 2.05vw, 21px) + " + delta + "px)";
        }
        node.appendChild(label);
      }

      if (selected === index) {
        appendResizeHandles(node, marker, index, shape);
      }

      if (marker.shape === "ellipse" && selected === index) {
        var arm = document.createElement("span");
        arm.className = "map-marker-rotate-arm";
        arm.style.transform = "rotate(" + (marker.rotation || 0) + "deg)";
        var handle = document.createElement("span");
        handle.className = "map-marker-rotate-handle";
        handle.title = "Sürükleyerek döndür";
        handle.addEventListener("pointerdown", function (event) {
          event.preventDefault();
          event.stopPropagation();
          selected = index;
          suppressMapClick = true;
          handle.setPointerCapture(event.pointerId);
          drag = { type: "rotate", pointerId: event.pointerId, node: node, arm: arm, shape: shape };
          renderControls();
        });
        handle.addEventListener("pointermove", function (event) {
          if (!drag || drag.type !== "rotate" || drag.pointerId !== event.pointerId) return;
          var plane = mapPlane().getBoundingClientRect();
          var cx = plane.left + (markers[index].x / 100) * plane.width;
          var cy = plane.top + (markers[index].y / 100) * plane.height;
          var degrees = (Math.atan2(event.clientY - cy, event.clientX - cx) * 180) / Math.PI + 90;
          markers[index].rotation = Math.round((degrees + 360) % 180);
          shape.style.transform = "rotate(" + markers[index].rotation + "deg)";
          arm.style.transform = "rotate(" + markers[index].rotation + "deg)";
          serialize();
          notify();
        });
        handle.addEventListener("pointerup", function () {
          drag = null;
          renderControls();
        });
        handle.addEventListener("pointercancel", function () {
          drag = null;
          renderControls();
        });
        arm.appendChild(handle);
        node.appendChild(arm);
      }

      node.addEventListener("click", function (event) {
        event.stopPropagation();
        selected = index;
        render();
      });
      node.addEventListener("pointerdown", function (event) {
        if (event.target.closest(".map-marker-rotate-handle")) return;
        if (event.target.closest(".map-marker-resize-handle")) return;
        event.preventDefault();
        event.stopPropagation();
        selected = index;
        suppressMapClick = true;
        node.setPointerCapture(event.pointerId);
        drag = { type: "move", pointerId: event.pointerId, node: node };
        renderControls();
      });
      node.addEventListener("pointermove", function (event) {
        if (!drag || drag.type !== "move" || drag.pointerId !== event.pointerId) return;
        var pt = eventToMapPercent(event, true);
        if (!pt) return;
        markers[index].x = pt.x;
        markers[index].y = pt.y;
        node.style.left = markers[index].x + "%";
        node.style.top = markers[index].y + "%";
        serialize();
        renderControls();
        notify();
      });
      node.addEventListener("pointerup", function () {
        if (drag && drag.type === "move") drag = null;
      });
      node.addEventListener("pointercancel", function () {
        if (drag && drag.type === "move") drag = null;
      });
      return node;
    }

    function numberInput(labelText, key, marker, index, min, max, step) {
      var label = document.createElement("label");
      label.textContent = labelText;
      var input = document.createElement("input");
      input.type = "number";
      input.min = String(min);
      input.max = String(max);
      input.step = String(step);
      input.value = String(marker[key]);
      input.addEventListener("input", function () {
        marker[key] = fixed(clamp(input.value, min, max));
        if (marker.shape === "circle" && key === "width") {
          marker.height = marker.width;
        }
        selected = index;
        renderMarkers();
        serialize();
        notify();
      });
      label.appendChild(input);
      return label;
    }

    function renderControls() {
      controls.innerHTML = "";
      markers.forEach(function (marker, index) {
        var card = document.createElement("div");
        card.className = "map-marker-card" + (selected === index ? " is-selected" : "");
        card.addEventListener("click", function () {
          if (selected !== index) {
            selected = index;
            render();
          }
        });

        var head = document.createElement("div");
        head.className = "map-marker-card-head";
        var title = document.createElement("strong");
        title.textContent =
          marker.shape === "line"
            ? "Doğru"
            : marker.shape === "city-label"
              ? "İl adı"
              : marker.shape === "circle"
                ? "Daire"
                : "Elips";
        head.appendChild(title);

        var order = document.createElement("div");
        order.className = "map-marker-order";
        [
          ["↑", -1, "Yukarı taşı"],
          ["↓", 1, "Aşağı taşı"],
        ].forEach(function (item) {
          var button = document.createElement("button");
          button.type = "button";
          button.className = "btn btn-ghost";
          button.textContent = item[0];
          button.title = item[2];
          button.disabled =
            (item[1] < 0 && index === 0) ||
            (item[1] > 0 && index === markers.length - 1);
          button.addEventListener("click", function (event) {
            event.stopPropagation();
            var target = index + item[1];
            var moved = markers.splice(index, 1)[0];
            markers.splice(target, 0, moved);
            selected = target;
            render();
          });
          order.appendChild(button);
        });
        var remove = document.createElement("button");
        remove.type = "button";
        remove.className = "btn btn-danger";
        remove.textContent = "Sil";
        remove.addEventListener("click", function (event) {
          event.stopPropagation();
          removeMarkerAt(index);
        });
        order.appendChild(remove);
        head.appendChild(order);
        card.appendChild(head);

        var grid = document.createElement("div");
        grid.className = "map-marker-grid";
        if (marker.shape === "line") {
          grid.appendChild(numberInput("X1 (%)", "x", marker, index, 0, 100, 0.01));
          grid.appendChild(numberInput("Y1 (%)", "y", marker, index, 0, 100, 0.01));
          grid.appendChild(numberInput("X2 (%)", "x2", marker, index, 0, 100, 0.01));
          grid.appendChild(numberInput("Y2 (%)", "y2", marker, index, 0, 100, 0.01));
          grid.appendChild(
            numberInput("Kalınlık (%)", "width", marker, index, 0.4, 4, 0.1)
          );
          var cityCheck = document.createElement("label");
          cityCheck.className = "map-line-city-check";
          var cityBox = document.createElement("input");
          cityBox.type = "checkbox";
          cityBox.checked = marker.showLabel !== false;
          cityBox.addEventListener("change", function () {
            marker.showLabel = cityBox.checked;
            cityLabelsOn = cityBox.checked;
            if (marker.showLabel) syncLineLabel(marker);
            selected = index;
            render();
          });
          cityCheck.appendChild(cityBox);
          cityCheck.appendChild(document.createTextNode(" Şehir adı"));
          grid.appendChild(cityCheck);
          var cityName = document.createElement("label");
          cityName.textContent = "Hedef il";
          var cityInput = document.createElement("input");
          cityInput.type = "text";
          cityInput.maxLength = 40;
          cityInput.placeholder = "Otomatik";
          cityInput.value = marker.endLabel || "";
          cityInput.addEventListener("input", function () {
            marker.endLabel = cityInput.value.trim().slice(0, 40);
            marker.labelCustom = marker.endLabel.length > 0;
            if (!marker.labelCustom) syncLineLabel(marker);
            else marker.label = [marker.startLabel, marker.endLabel].filter(Boolean).join(" · ");
            selected = index;
            renderMarkers();
            serialize();
            notify();
          });
          cityName.appendChild(cityInput);
          grid.appendChild(cityName);
        } else if (marker.shape === "city-label") {
          grid.appendChild(numberInput("X (%)", "x", marker, index, 0, 100, 0.01));
          grid.appendChild(numberInput("Y (%)", "y", marker, index, 0, 100, 0.01));
          var cityLabelCheck = document.createElement("label");
          cityLabelCheck.className = "map-line-city-check";
          var cityLabelBox = document.createElement("input");
          cityLabelBox.type = "checkbox";
          cityLabelBox.checked = marker.showLabel !== false;
          cityLabelBox.addEventListener("change", function () {
            marker.showLabel = cityLabelBox.checked;
            cityLabelsOn = cityLabelBox.checked;
            selected = index;
            render();
          });
          cityLabelCheck.appendChild(cityLabelBox);
          cityLabelCheck.appendChild(document.createTextNode(" Göster"));
          grid.appendChild(cityLabelCheck);
          var cityLabelName = document.createElement("label");
          cityLabelName.textContent = "İl adı";
          var cityLabelInput = document.createElement("input");
          cityLabelInput.type = "text";
          cityLabelInput.maxLength = 40;
          cityLabelInput.placeholder = "Otomatik";
          cityLabelInput.value = marker.label || "";
          cityLabelInput.addEventListener("input", function () {
            marker.label = cityLabelInput.value.trim().slice(0, 40);
            marker.labelCustom = marker.label.length > 0;
            if (!marker.labelCustom) syncCityLabel(marker);
            selected = index;
            renderMarkers();
            serialize();
            notify();
          });
          cityLabelName.appendChild(cityLabelInput);
          grid.appendChild(cityLabelName);
        } else {
        grid.appendChild(numberInput("X (%)", "x", marker, index, 0, 100, 0.01));
        grid.appendChild(numberInput("Y (%)", "y", marker, index, 0, 100, 0.01));
        grid.appendChild(
          numberInput(
            marker.shape === "circle" ? "Çap (%)" : "Genişlik (%)",
            "width",
            marker,
            index,
            1,
            15,
            0.01
          )
        );
        if (marker.shape !== "circle") {
          grid.appendChild(
            numberInput("Yükseklik (%)", "height", marker, index, 1, 15, 0.01)
          );
        }

        var shapeLabel = document.createElement("label");
        shapeLabel.textContent = "Şekil";
        var shapeSelect = document.createElement("select");
        [
          ["ellipse", "Elips"],
          ["circle", "Daire"],
        ].forEach(function (optionData) {
          var option = document.createElement("option");
          option.value = optionData[0];
          option.textContent = optionData[1];
          option.selected = marker.shape === optionData[0];
          shapeSelect.appendChild(option);
        });
        shapeSelect.addEventListener("change", function () {
          marker.shape = shapeSelect.value;
          if (marker.shape === "circle") {
            marker.height = marker.width;
            marker.rotation = 0;
          }
          selected = index;
          render();
        });
        shapeLabel.appendChild(shapeSelect);
        grid.appendChild(shapeLabel);

        if (marker.shape !== "circle") {
          var rotLabel = document.createElement("label");
          rotLabel.textContent = "Dönüş (°)";
          var rotInput = document.createElement("input");
          rotInput.type = "number";
          rotInput.min = "0";
          rotInput.max = "179";
          rotInput.step = "1";
          rotInput.value = String(marker.rotation || 0);
          rotInput.addEventListener("input", function () {
            marker.rotation = Math.round(clamp(rotInput.value, 0, 179));
            selected = index;
            renderMarkers();
            serialize();
            notify();
          });
          rotLabel.appendChild(rotInput);
          var rotHint = document.createElement("span");
          rotHint.className = "hint";
          rotHint.textContent = "Haritada yeşil tutaçla döndür; kenar tutaçlarıyla boyutlandır";
          rotLabel.appendChild(rotHint);
          grid.appendChild(rotLabel);
        }
        }

        var colorLabel = document.createElement("label");
        colorLabel.textContent = "Renk";
        var color = document.createElement("input");
        color.type = "color";
        color.value = marker.color;
        color.addEventListener("input", function () {
          marker.color = color.value;
          renderMarkers();
          serialize();
          notify();
        });
        colorLabel.appendChild(color);
        grid.appendChild(colorLabel);

        if (marker.shape === "ellipse" || marker.shape === "circle") {
        var romanCheck = document.createElement("label");
        romanCheck.className = "map-line-city-check";
        var romanBox = document.createElement("input");
        romanBox.type = "checkbox";
        romanBox.checked = marker.showLabel !== false;
        romanBox.addEventListener("change", function () {
          marker.showLabel = romanBox.checked;
          selected = index;
          render();
        });
        romanCheck.appendChild(romanBox);
        romanCheck.appendChild(document.createTextNode(" Romen numarası"));
        grid.appendChild(romanCheck);
        }

        if ((marker.shape === "ellipse" || marker.shape === "circle") && marker.showLabel !== false) {
        var sideLabel = document.createElement("label");
        sideLabel.textContent = "Numara yönü";
        var side = document.createElement("select");
        [
          ["right", "Sağ"],
          ["left", "Sol"],
          ["top", "Üst"],
          ["bottom", "Alt"],
        ].forEach(function (optionData) {
          var option = document.createElement("option");
          option.value = optionData[0];
          option.textContent = optionData[1];
          option.selected = marker.labelSide === optionData[0];
          side.appendChild(option);
        });
        side.addEventListener("change", function () {
          marker.labelSide = side.value;
          renderMarkers();
          serialize();
          notify();
        });
        sideLabel.appendChild(side);
        grid.appendChild(sideLabel);

        var sizeWrap = document.createElement("div");
        sizeWrap.className = "map-roman-size";
        var sizeTitle = document.createElement("span");
        sizeTitle.className = "map-roman-size-title";
        sizeTitle.textContent = "Romen punto";
        sizeWrap.appendChild(sizeTitle);
        var sizeRow = document.createElement("div");
        sizeRow.className = "map-roman-size-row";
        var minusBtn = document.createElement("button");
        minusBtn.type = "button";
        minusBtn.className = "btn btn-ghost map-roman-size-btn";
        minusBtn.textContent = "A-";
        minusBtn.title = "2 punto küçült";
        var sizeVal = document.createElement("span");
        sizeVal.className = "map-roman-size-value";
        var plusBtn = document.createElement("button");
        plusBtn.type = "button";
        plusBtn.className = "btn btn-ghost map-roman-size-btn";
        plusBtn.textContent = "A+";
        plusBtn.title = "2 punto büyüt";
        function refreshSizeLabel() {
          var d = normalizeLabelSizeDelta(marker.labelSizeDelta);
          sizeVal.textContent = d === 0 ? "varsayılan" : (d > 0 ? "+" : "") + d + " pt";
          minusBtn.disabled = d <= -20;
          plusBtn.disabled = d >= 40;
        }
        minusBtn.addEventListener("click", function () {
          marker.labelSizeDelta = normalizeLabelSizeDelta((marker.labelSizeDelta || 0) - 2);
          refreshSizeLabel();
          renderMarkers();
          serialize();
          notify();
        });
        plusBtn.addEventListener("click", function () {
          marker.labelSizeDelta = normalizeLabelSizeDelta((marker.labelSizeDelta || 0) + 2);
          refreshSizeLabel();
          renderMarkers();
          serialize();
          notify();
        });
        sizeRow.appendChild(minusBtn);
        sizeRow.appendChild(sizeVal);
        sizeRow.appendChild(plusBtn);
        sizeWrap.appendChild(sizeRow);
        refreshSizeLabel();
        grid.appendChild(sizeWrap);
        }
        card.appendChild(grid);
        controls.appendChild(card);
      });
    }

    function renderMarkers() {
      layer.innerHTML = "";
      if (lineDraft) {
        var draft = document.createElement("span");
        draft.className = "map-line-handle is-draft";
        draft.style.left = lineDraft.x + "%";
        draft.style.top = lineDraft.y + "%";
        layer.appendChild(draft);
      }
      markers.forEach(function (marker, index) {
        layer.appendChild(markerHtml(marker, index));
      });
      markers.forEach(function (marker) {
        if (marker.shape === "line") appendSpokeLabel(layer, marker);
      });
      appendHubLabels(layer);
    }

    function notify() {
      document.dispatchEvent(new CustomEvent("map-question-change"));
    }

    function render() {
      body.hidden = !mapActive();
      syncFitPlane();
      if (staticMode()) {
        selected = -1;
        markers = [];
        fills = [];
        paintMode = false;
        brushMode = false;
        if (smartBrush) {
          smartBrush.clear();
          smartBrush.setModeVisual(false);
        }
        lineMode = false;
        spokeMode = false;
        cityLabelMode = false;
        ellipseMode = false;
        resetLineDraw();
        layer.innerHTML = "";
        if (fillLayer) fillLayer.innerHTML = "";
        controls.innerHTML = "";
        if (addButton) addButton.hidden = true;
        if (addCircleButton) addCircleButton.hidden = true;
        if (addLineButton) addLineButton.hidden = true;
        if (addSpokeButton) addSpokeButton.hidden = true;
        if (addCityLabelButton) addCityLabelButton.hidden = true;
        if (cityLabelsButton) cityLabelsButton.hidden = true;
        if (lineWidthWrap) lineWidthWrap.hidden = true;
        if (lineCountWrap) lineCountWrap.hidden = true;
        if (clearButton) clearButton.hidden = true;
        if (paintButton) paintButton.hidden = true;
        if (brushButton) brushButton.hidden = true;
        if (fillColorWrap) fillColorWrap.hidden = true;
        if (brushWidthWrap) brushWidthWrap.hidden = true;
        wrap.classList.remove("is-paint", "is-line", "is-brush");
        applyTemplateAssets();
        serialize();
        status.textContent = "Tematik harita — işaret eklenmez.";
        notify();
        return;
      }
      if (addButton) addButton.hidden = false;
      if (addCircleButton) addCircleButton.hidden = false;
      if (addLineButton) addLineButton.hidden = false;
      if (addSpokeButton) addSpokeButton.hidden = false;
      if (addCityLabelButton) addCityLabelButton.hidden = false;
      var hasLine = markers.some(function (marker) {
        return marker.shape === "line" || marker.shape === "city-label";
      });
      var drawingLine = lineMode || spokeMode || cityLabelMode;
      if (cityLabelsButton) {
        cityLabelsButton.hidden = !(drawingLine || hasLine);
        cityLabelsButton.textContent = cityLabelsOn ? "Şehir adları: açık" : "Şehir adları: gizli";
        cityLabelsButton.classList.toggle("btn-primary", cityLabelsOn);
        cityLabelsButton.classList.toggle("btn-ghost", !cityLabelsOn);
        cityLabelsButton.setAttribute("aria-pressed", cityLabelsOn ? "true" : "false");
      }
      if (lineWidthWrap) {
        var selectedLine =
          selected >= 0 && markers[selected] && markers[selected].shape === "line";
        lineWidthWrap.hidden = !(drawingLine || selectedLine);
        if (selectedLine && lineWidthInput) {
          lineWidthInput.value = String(markers[selected].width);
          if (lineWidthVal) lineWidthVal.textContent = String(markers[selected].width);
        }
      }
      if (lineCountWrap) {
        lineCountWrap.hidden = !lineAwaitCount;
        if (lineAwaitCount && lineCountInput) {
          var maxN = Math.max(1, remainingLineSlots());
          lineCountInput.max = String(maxN);
          var current = parseInt(lineCountInput.value, 10);
          if (!current || current < 1) current = Math.min(3, maxN);
          if (current > maxN) current = maxN;
          lineCountInput.value = String(current);
        }
      }
      if (clearButton) clearButton.hidden = false;
      if (paintButton) paintButton.hidden = !paintEnabled();
      if (brushButton) brushButton.hidden = !paintEnabled();
      if (fillColorWrap) fillColorWrap.hidden = !paintEnabled();
      if (brushWidthWrap) brushWidthWrap.hidden = !(paintEnabled() && brushMode);
      if (!paintEnabled()) {
        paintMode = false;
        brushMode = false;
        if (smartBrush) {
          smartBrush.clear();
          smartBrush.setModeVisual(false);
        }
        fills = [];
      }
      if (paintButton) {
        paintButton.classList.toggle("btn-primary", paintMode);
        paintButton.classList.toggle("btn-ghost", !paintMode);
      }
      if (brushButton) {
        brushButton.classList.toggle("btn-primary", brushMode);
        brushButton.classList.toggle("btn-ghost", !brushMode);
      }
      if (smartBrush) smartBrush.setModeVisual(brushMode && paintEnabled());
      wrap.classList.toggle("is-paint", paintMode && paintEnabled());
      wrap.classList.toggle("is-line", lineMode || spokeMode || cityLabelMode);
      if (addLineButton) {
        addLineButton.classList.toggle("btn-primary", lineMode);
        addLineButton.classList.toggle("btn-ghost", !lineMode);
      }
      if (addSpokeButton) {
        addSpokeButton.classList.toggle("btn-primary", spokeMode);
        addSpokeButton.classList.toggle("btn-ghost", !spokeMode);
      }
      if (addCityLabelButton) {
        addCityLabelButton.classList.toggle("btn-primary", cityLabelMode);
        addCityLabelButton.classList.toggle("btn-ghost", !cityLabelMode);
      }
      if (addButton) {
        addButton.classList.toggle("btn-primary", ellipseMode);
        addButton.classList.toggle("btn-ghost", !ellipseMode);
      }
      if (!markerMode()) {
        selected = -1;
        markers = [];
        fills = [];
      } else {
        applyTemplateAssets();
      }
      renderFills();
      renderMarkers();
      renderControls();
      serialize();
      notify();
      if (root.classList.contains("is-expanded")) {
        requestAnimationFrame(layoutAfterExpand);
      }
    }

    function remainingLineSlots() {
      return Math.max(0, MAX_MARKERS - markers.length);
    }

    function resetLineDraw() {
      lineDraft = null;
      lineSpokeLeft = 0;
      lineAwaitCount = false;
    }

    function stopLineModes() {
      lineMode = false;
      spokeMode = false;
      cityLabelMode = false;
      ellipseMode = false;
      resetLineDraw();
    }

    function confirmLineCount() {
      if (!spokeMode || !lineDraft || !lineAwaitCount) return;
      var maxN = remainingLineSlots();
      if (maxN < 1) {
        stopLineModes();
        render();
        return;
      }
      var n = parseInt(lineCountInput && lineCountInput.value, 10);
      if (!n || n < 1) n = 1;
      if (n > maxN) n = maxN;
      if (lineCountInput) lineCountInput.value = String(n);
      lineSpokeLeft = n;
      lineAwaitCount = false;
      render();
    }

    function addMarker(x, y, preset) {
      if (!enabled() || markers.length >= MAX_MARKERS) return;
      var next = normalizeMarker(
        Object.assign({}, preset || DEFAULT_ELLIPSE, {
          x: fixed(clamp(x, 0, 100)),
          y: fixed(clamp(y, 0, 100)),
        })
      );
      if (next.shape === "line") {
        if (!preset || preset.showLabel == null) next.showLabel = cityLabelsOn;
        syncLineLabel(next);
      }
      if (next.shape === "city-label") {
        if (!preset || preset.showLabel == null) next.showLabel = cityLabelsOn;
        syncCityLabel(next);
      }
      markers.push(next);
      selected = markers.length - 1;
      render();
    }

    function removeMarkerAt(index) {
      if (index < 0 || index >= markers.length) return;
      markers.splice(index, 1);
      selected = markers.length === 0 ? -1 : Math.min(index, markers.length - 1);
      render();
    }

    document.addEventListener("keydown", function (event) {
      if (!enabled() || !markerMode()) return;
      var tag = (event.target && event.target.tagName) || "";
      if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT") return;
      if (event.key !== "Delete" && event.key !== "Backspace") return;
      if (selected < 0) return;
      event.preventDefault();
      removeMarkerAt(selected);
    });

    wrap.addEventListener("click", function (event) {
      if (suppressMapClick) {
        suppressMapClick = false;
        return;
      }
      if (!enabled() || event.target.closest(".map-marker, .map-line-handle, .map-city-label-pin")) return;
      if (!lineMode && !spokeMode && event.target.closest(".map-line")) return;
      var pt = eventToMapPercent(event);
      if (!pt) return;
      var x = pt.x;
      var y = pt.y;
      if (paintMode && paintEnabled()) {
        var hit = hitProvince(x, y);
        if (hit) toggleFill(hit.id);
        return;
      }
      if (lineMode) {
        if (!lineDraft) {
          if (remainingLineSlots() < 1) return;
          lineDraft = { x: fixed(clamp(x, 0, 100)), y: fixed(clamp(y, 0, 100)) };
          render();
          return;
        }
        var lineStart = lineDraft;
        lineDraft = null;
        addMarker(lineStart.x, lineStart.y, {
          shape: "line",
          x: lineStart.x,
          y: lineStart.y,
          x2: x,
          y2: y,
          width: currentLineWidth(),
          color: "#ef4444",
          showLabel: cityLabelsOn,
        });
        return;
      }
      if (spokeMode) {
        if (lineAwaitCount) return;
        if (!lineDraft) {
          if (remainingLineSlots() < 1) return;
          lineDraft = { x: fixed(clamp(x, 0, 100)), y: fixed(clamp(y, 0, 100)) };
          lineAwaitCount = true;
          lineSpokeLeft = 0;
          render();
          if (lineCountInput) {
            lineCountInput.focus();
            lineCountInput.select();
          }
          return;
        }
        if (lineSpokeLeft < 1) return;
        var hub = lineDraft;
        lineSpokeLeft -= 1;
        addMarker(hub.x, hub.y, {
          shape: "line",
          x: hub.x,
          y: hub.y,
          x2: x,
          y2: y,
          width: currentLineWidth(),
          color: "#ef4444",
          showLabel: cityLabelsOn,
        });
        if (lineSpokeLeft < 1) {
          stopLineModes();
          render();
        }
        return;
      }
      if (cityLabelMode) {
        var province = hitProvince(x, y);
        if (!province) return;
        addMarker(x, y, {
          shape: "city-label",
          label: province.name,
          showLabel: cityLabelsOn,
        });
        return;
      }
      if (ellipseMode) {
        addMarker(x, y, DEFAULT_ELLIPSE);
      }
    });

    template.addEventListener("change", render);
    function layoutAfterExpand() {
      syncFitPlane();
      renderMarkers();
    }
    function setExpanded(on) {
      root.classList.toggle("is-expanded", on);
      document.body.classList.toggle("map-editor-expanded", on);
      if (expandButton) {
        expandButton.textContent = on ? "%100" : "%170";
        expandButton.classList.toggle("btn-primary", on);
        expandButton.classList.toggle("btn-ghost", !on);
        expandButton.setAttribute("aria-pressed", on ? "true" : "false");
      }
      layoutAfterExpand();
      requestAnimationFrame(layoutAfterExpand);
    }
    if (expandButton) {
      expandButton.addEventListener("click", function () {
        setExpanded(!root.classList.contains("is-expanded"));
      });
    }
    document.addEventListener("keydown", function (event) {
      if (
        event.key === "Escape" &&
        ((lineMode && lineDraft) ||
          (spokeMode && (lineDraft || lineAwaitCount || lineSpokeLeft)))
      ) {
        if (spokeMode) stopLineModes();
        else resetLineDraw();
        render();
        return;
      }
      if (event.key === "Escape" && root.classList.contains("is-expanded")) {
        setExpanded(false);
      }
    });
    addButton.addEventListener("click", function () {
      if (!enabled()) return;
      var next = !ellipseMode;
      stopLineModes();
      ellipseMode = next;
      if (ellipseMode) { paintMode = false; brushMode = false; }
      render();
    });
    if (addCircleButton) {
      addCircleButton.addEventListener("click", function () {
        stopLineModes();
        paintMode = false;
        addMarker(50 + markers.length * 2, 48, DEFAULT_CIRCLE);
      });
    }
    if (addLineButton) {
      addLineButton.addEventListener("click", function () {
        if (!enabled()) return;
        var next = !lineMode;
        stopLineModes();
        lineMode = next;
        if (lineMode) { paintMode = false; brushMode = false; }
        render();
      });
    }
    if (addSpokeButton) {
      addSpokeButton.addEventListener("click", function () {
        if (!enabled()) return;
        var next = !spokeMode;
        stopLineModes();
        spokeMode = next;
        if (spokeMode) { paintMode = false; brushMode = false; }
        render();
      });
    }
    if (addCityLabelButton) {
      addCityLabelButton.addEventListener("click", function () {
        if (!enabled()) return;
        var next = !cityLabelMode;
        stopLineModes();
        cityLabelMode = next;
        if (cityLabelMode) { paintMode = false; brushMode = false; }
        render();
      });
    }
    if (cityLabelsButton) {
      cityLabelsButton.addEventListener("click", function () {
        if (!enabled()) return;
        setCityLabelsOn(!cityLabelsOn);
        render();
      });
    }
    if (lineCountOk) {
      lineCountOk.addEventListener("click", function () {
        confirmLineCount();
      });
    }
    if (lineCountInput) {
      lineCountInput.addEventListener("keydown", function (event) {
        if (event.key === "Enter") {
          event.preventDefault();
          confirmLineCount();
        }
      });
    }
    if (lineWidthInput) {
      lineWidthInput.addEventListener("input", function () {
        lineWidth = currentLineWidth();
        if (lineWidthVal) lineWidthVal.textContent = String(lineWidth);
        if (selected >= 0 && markers[selected] && markers[selected].shape === "line") {
          markers[selected].width = lineWidth;
          renderMarkers();
          serialize();
          notify();
        }
      });
    }
    clearButton.addEventListener("click", function () {
      markers = [];
      fills = [];
      if (smartBrush) smartBrush.clear();
      selected = -1;
      render();
    });
    if (paintButton) {
      paintButton.addEventListener("click", function () {
        if (!paintEnabled()) return;
        paintMode = !paintMode;
        if (paintMode) {
          brushMode = false;
          stopLineModes();
        }
        render();
      });
    }
    if (brushButton) {
      brushButton.addEventListener("click", function () {
        if (!paintEnabled()) return;
        brushMode = !brushMode;
        if (brushMode) {
          paintMode = false;
          stopLineModes();
        }
        render();
      });
    }
    if (brushWidthInput) {
      brushWidthInput.addEventListener("input", function () {
        brushWidth = Number(brushWidthInput.value) || brushWidth;
        if (brushWidthVal) brushWidthVal.textContent = String(brushWidth);
      });
    }
    if (fillColorInput) {
      fillColorInput.addEventListener("input", function () {
        fillColor = fillColorInput.value || DEFAULT_FILL_COLOR;
      });
    }
    if (insertPlaceholderButton) {
      insertPlaceholderButton.addEventListener("click", function () {
        var el =
          document.getElementById("question-stem") ||
          document.querySelector('textarea[name="stem"]');
        var note = insertStatus || status;
        if (!el) {
          if (note) note.textContent = "Soru metni alanı bulunamadı.";
          return;
        }
        var value = el.value || "";
        var found = value.indexOf(MAP_PLACEHOLDER);
        function say(msg) {
          if (note) note.textContent = msg;
          if (status && status !== note) status.textContent = msg;
        }
        if (found !== -1) {
          el.focus();
          try {
            el.setSelectionRange(found, found + MAP_PLACEHOLDER.length);
          } catch (_) {}
          say("Metinde zaten [HARITA] var.");
          if (window.KpssQuestionPreview) window.KpssQuestionPreview.sync();
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
        var insert = padBefore + MAP_PLACEHOLDER + padAfter;
        el.value = before + insert + after;
        var cursor = before.length + insert.length;
        el.focus();
        try {
          el.setSelectionRange(cursor, cursor);
        } catch (_) {}
        el.dispatchEvent(new Event("input", { bubbles: true }));
        if (window.KpssQuestionPreview) window.KpssQuestionPreview.sync();
        notify();
        say(
          mapActive()
            ? "[HARITA] soru metnine eklendi."
            : "[HARITA] eklendi. Haritanın görünmesi için şablon seçin."
        );
      });
    }
    baseImage.addEventListener("load", function () {
      syncFitPlane();
      renderMarkers();
      notify();
    });
    previewImage.addEventListener("load", notify);
    if (window.ResizeObserver) {
      new ResizeObserver(function () {
        syncFitPlane();
        if (drag) return;
        renderMarkers();
      }).observe(wrap);
    } else {
      window.addEventListener("resize", function () {
        syncFitPlane();
        if (drag) return;
        renderMarkers();
      });
    }

    function previewImageSrc() {
      if (staticMode()) {
        var entry = currentTemplate();
        return entry && entry.asset ? entry.asset : "";
      }
      if (!mapActive()) return "";
      var source = previewImage;
      if (!source.complete || !source.naturalWidth) {
        return source.src || (baseImage && baseImage.src) || "";
      }
      var canvas = document.createElement("canvas");
      canvas.width = source.naturalWidth;
      canvas.height = source.naturalHeight;
      var ctx = canvas.getContext("2d");
      ctx.fillStyle = "#f8fafc";
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.drawImage(source, 0, 0, canvas.width, canvas.height);
      var byId = {};
      provinces.forEach(function (province) {
        byId[province.id] = province;
      });
      fills.forEach(function (fill) {
        var province = byId[fill.province];
        if (!province) return;
        ctx.fillStyle = fill.color;
        (province.polygons || []).forEach(function (ring) {
          if (!ring.length) return;
          ctx.beginPath();
          ring.forEach(function (point, index) {
            var px = (point[0] / 100) * canvas.width;
            var py = (point[1] / 100) * canvas.height;
            if (index === 0) ctx.moveTo(px, py);
            else ctx.lineTo(px, py);
          });
          ctx.closePath();
          ctx.fill();
        });
      });
      if (smartBrush && smartBrush.paintPreview) {
        smartBrush.paintPreview(ctx, canvas.width, canvas.height, provinces);
      }
      if ("letterSpacing" in ctx) ctx.letterSpacing = "-0.08em";
      ctx.textBaseline = "middle";
      ctx.fillStyle = "#111827";

      function romanWidth(text) {
        if ("letterSpacing" in ctx) return ctx.measureText(text).width;
        var w = 0;
        for (var i = 0; i < text.length; i++) {
          var gw = ctx.measureText(text[i]).width;
          w += text[i] === "I" ? gw * 0.78 : gw;
        }
        return w;
      }

      function drawRoman(text, x, y) {
        if ("letterSpacing" in ctx) {
          ctx.strokeText(text, x, y);
          ctx.fillText(text, x, y);
          return;
        }
        var cx = x;
        for (var i = 0; i < text.length; i++) {
          ctx.strokeText(text[i], cx, y);
          ctx.fillText(text[i], cx, y);
          var gw = ctx.measureText(text[i]).width;
          cx += text[i] === "I" ? gw * 0.78 : gw;
        }
      }

      var previewLines = [];
      var previewCityLabels = [];
      markers.forEach(function (marker, index) {
        if (marker.shape === "line") {
          var x1 = (marker.x / 100) * canvas.width;
          var y1 = (marker.y / 100) * canvas.height;
          var x2 = (marker.x2 / 100) * canvas.width;
          var y2 = (marker.y2 / 100) * canvas.height;
          var thick = Math.max(2, (marker.width / 100) * canvas.width);
          ctx.strokeStyle = marker.color;
          ctx.lineWidth = thick;
          ctx.lineCap = "round";
          ctx.beginPath();
          ctx.moveTo(x1, y1);
          ctx.lineTo(x2, y2);
          ctx.stroke();
          ctx.fillStyle = marker.color;
          ctx.beginPath();
          ctx.arc(x1, y1, thick * 0.6, 0, Math.PI * 2);
          ctx.fill();
          ctx.beginPath();
          ctx.arc(x2, y2, thick * 0.6, 0, Math.PI * 2);
          ctx.fill();
          previewLines.push(marker);
          return;
        }
        if (marker.shape === "city-label") {
          previewCityLabels.push(marker);
          return;
        }
        var cx = (marker.x / 100) * canvas.width;
        var cy = (marker.y / 100) * canvas.height;
        var rx = (marker.width / 100) * canvas.width / 2;
        var ry = (marker.height / 100) * canvas.height / 2;
        if (marker.shape === "circle") {
          rx = ry = (marker.width / 100) * canvas.width / 2;
        }
        var rot = ((marker.shape === "circle" ? 0 : marker.rotation || 0) * Math.PI) / 180;
        ctx.beginPath();
        ctx.ellipse(cx, cy, rx, ry, rot, 0, Math.PI * 2);
        ctx.fillStyle = marker.color;
        ctx.fill();
        if (marker.showLabel === false) return;

        var romanPx = romanPxForMarker(canvas.width, marker);
        ctx.font = "700 " + romanPx + "px Arial, Helvetica, sans-serif";
        var aabbW = Math.abs(rx * 2 * Math.cos(rot)) + Math.abs(ry * 2 * Math.sin(rot));
        var aabbH = Math.abs(rx * 2 * Math.sin(rot)) + Math.abs(ry * 2 * Math.cos(rot));
        var label = pinLabel(index);
        var measureW = romanWidth(label);
        var gap = Math.max(14, canvas.width * 0.01);
        var tx = cx + aabbW / 2 + gap;
        var ty = cy;
        if (marker.labelSide === "left") tx = cx - aabbW / 2 - gap - measureW;
        if (marker.labelSide === "top") {
          tx = cx - measureW / 2;
          ty = cy - aabbH / 2 - gap - 22;
        }
        if (marker.labelSide === "bottom") {
          tx = cx - measureW / 2;
          ty = cy + aabbH / 2 + gap + 22;
        }
        ctx.strokeStyle = "#ffffff";
        ctx.lineWidth = Math.max(4, Math.round(canvas.width * 0.004));
        ctx.fillStyle = "#111827";
        drawRoman(label, tx, ty);
      });
      (function drawPreviewLineCities() {
        var cityPx = Math.max(22, Math.round(canvas.width * 0.022));
        var extra = canvas.width * 0.038;
        var hubs = {};
        function drawCity(name, px, py) {
          if (!name) return;
          ctx.font = "700 " + cityPx + "px Arial, Helvetica, sans-serif";
          ctx.textAlign = "center";
          ctx.textBaseline = "middle";
          ctx.lineWidth = Math.max(3, Math.round(canvas.width * 0.003));
          ctx.strokeStyle = "#ffffff";
          ctx.fillStyle = "#111827";
          ctx.strokeText(name, px, py);
          ctx.fillText(name, px, py);
        }
        previewLines.forEach(function (marker) {
          if (marker.showLabel === false) return;
          var names = lineEndNames(marker);
          var x1 = (marker.x / 100) * canvas.width;
          var y1 = (marker.y / 100) * canvas.height;
          var x2 = (marker.x2 / 100) * canvas.width;
          var y2 = (marker.y2 / 100) * canvas.height;
          var key = Number(marker.x).toFixed(1) + "," + Number(marker.y).toFixed(1);
          if (names.start && !hubs[key]) {
            hubs[key] = { name: names.start, x: x1, y: y1 - canvas.height * 0.045 };
          }
          if (!names.end) return;
          var dx = x2 - x1;
          var dy = y2 - y1;
          var len = Math.sqrt(dx * dx + dy * dy) || 1;
          drawCity(names.end, x2 + (dx / len) * extra, y2 + (dy / len) * extra);
        });
        Object.keys(hubs).forEach(function (key) {
          drawCity(hubs[key].name, hubs[key].x, hubs[key].y);
        });
        previewCityLabels.forEach(function (marker) {
          if (marker.showLabel === false || !marker.label) return;
          drawCity(
            marker.label,
            (marker.x / 100) * canvas.width,
            (marker.y / 100) * canvas.height
          );
        });
        ctx.textAlign = "start";
      })();
      return canvas.toDataURL("image/png");
    }

    window.KpssMapQuestionEditor = {
      isEnabled: mapActive,
      previewImageSrc: previewImageSrc,
      markers: function () {
        return markers.slice();
      },
    };
    applyTemplateAssets();
    if (window.KpssMapSmartBrush && brushLayer && wrap) {
      smartBrush = window.KpssMapSmartBrush.attach({
        wrap: wrap,
        fitPlane: fitPlane || wrap,
        layer: brushLayer,
        isEnabled: function () {
          return paintEnabled();
        },
        isModeOn: function () {
          return brushMode;
        },
        getColor: function () {
          return fillColor;
        },
        getWidth: function () {
          return brushWidth;
        },
        eventToPercent: eventToMapPercent,
        onChange: function () {
          serialize();
          notify();
        },
        onSuppressClick: function (on) {
          suppressMapClick = Boolean(on);
        },
      });
      if (initialBrushes.length) smartBrush.load(initialBrushes);
    }
    var provincesSrc = root.dataset.provincesSrc;
    if (provincesSrc) {
      fetch(provincesSrc)
        .then(function (response) {
          return response.ok ? response.json() : { provinces: [] };
        })
        .then(function (data) {
          provinces = data.provinces || [];
          if (smartBrush) smartBrush.setProvinces(provinces);
          markers.forEach(syncLineLabel);
          markers.forEach(syncCityLabel);
          renderFills();
          renderMarkers();
          renderControls();
          serialize();
          notify();
        })
        .catch(function () {
          provinces = [];
        });
    }
    render();
  }

  document.addEventListener("DOMContentLoaded", init);
})();
