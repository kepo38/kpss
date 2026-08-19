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
    color: "#ef4444",
    labelSide: "right",
  };
  var DEFAULT_CIRCLE = {
    shape: "circle",
    x: 50,
    y: 50,
    width: 2.6,
    height: 2.6,
    rotation: 0,
    color: "#ef4444",
    labelSide: "right",
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
    var shape = marker && marker.shape === "circle" ? "circle" : "ellipse";
    var width = fixed(clamp(marker && marker.width ? marker.width : (shape === "circle" ? 2.6 : 4.5), 1, 15));
    var height = fixed(clamp(marker && marker.height ? marker.height : (shape === "circle" ? 2.6 : 3.5), 1, 15));
    if (shape === "circle") {
      height = width;
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
        : DEFAULT_MARKER.color,
      labelSide: ["left", "right", "top", "bottom"].includes(marker && marker.labelSide)
        ? marker.labelSide
        : "right",
    };
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
    var layer = document.getElementById("map-marker-layer");
    var baseImage = document.getElementById("map-base-image");
    var previewImage = document.createElement("img");
    previewImage.src = root.dataset.mapSrc || baseImage.src;
    var controls = document.getElementById("map-marker-controls");
    var addButton = document.getElementById("map-add-marker");
    var addCircleButton = document.getElementById("map-add-circle");
    var clearButton = document.getElementById("map-clear-markers");
    var insertPlaceholderButton = document.getElementById("map-insert-placeholder");
    var stemField = document.getElementById("question-stem");
    var status = document.getElementById("map-editor-status");
    var initialData = document.getElementById("map-markers-data");
    var templatesData = document.getElementById("map-templates-data");
    var mapTemplates = {};
    var fillLayer = document.getElementById("map-fill-layer");
    var paintButton = document.getElementById("map-paint-toggle");
    var fillColorInput = document.getElementById("map-fill-color");
    var fillColorWrap = document.getElementById("map-fill-color-wrap");
    var markers = [];
    var fills = [];
    var provinces = [];
    var paintMode = false;
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
        } else {
          markers.push(normalizeMarker(item));
        }
      });
    } catch (_) {
      markers = [];
      fills = [];
    }
    markers = markers.slice(0, MAX_MARKERS);

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
      hidden.value = JSON.stringify(
        fills
          .map(function (fill) {
            return { shape: "fill", province: fill.province, color: fill.color };
          })
          .concat(markers)
      );
      var parts = [];
      if (fills.length) parts.push(fills.length + " il boyalı");
      if (markers.length) parts.push(markers.length + " işaret");
      status.textContent = parts.length
        ? parts.join(" · ")
        : paintMode
          ? "İl boyamak için haritaya tıklayın"
          : "Haritaya tıklayarak işaret ekleyin";
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

    function markerHtml(marker, index) {
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
      node.setAttribute("aria-label", ROMAN[index] + " numaralı işaret");

      var shape = document.createElement("span");
      shape.className = "map-marker-shape";
      shape.style.backgroundColor = marker.color;
      shape.style.transform =
        marker.shape === "circle" ? "none" : "rotate(" + (marker.rotation || 0) + "deg)";
      node.appendChild(shape);

      var label = document.createElement("span");
      label.className = "map-marker-label is-" + marker.labelSide;
      label.textContent = ROMAN[index];
      node.appendChild(label);

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
          var rect = wrap.getBoundingClientRect();
          var cx = rect.left + (markers[index].x / 100) * rect.width;
          var cy = rect.top + (markers[index].y / 100) * rect.height;
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
        var rect = wrap.getBoundingClientRect();
        markers[index].x = fixed(clamp(((event.clientX - rect.left) / rect.width) * 100, 0, 100));
        markers[index].y = fixed(clamp(((event.clientY - rect.top) / rect.height) * 100, 0, 100));
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
        title.textContent = ROMAN[index] + ". işaret";
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
          rotHint.textContent = "Haritada yeşil tutamacı sürükleyin";
          rotLabel.appendChild(rotHint);
          grid.appendChild(rotLabel);
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
        card.appendChild(grid);
        controls.appendChild(card);
      });
    }

    function renderMarkers() {
      layer.innerHTML = "";
      markers.forEach(function (marker, index) {
        layer.appendChild(markerHtml(marker, index));
      });
    }

    function notify() {
      document.dispatchEvent(new CustomEvent("map-question-change"));
    }

    function render() {
      body.hidden = !mapActive();
      if (staticMode()) {
        selected = -1;
        markers = [];
        fills = [];
        paintMode = false;
        layer.innerHTML = "";
        if (fillLayer) fillLayer.innerHTML = "";
        controls.innerHTML = "";
        if (addButton) addButton.hidden = true;
        if (addCircleButton) addCircleButton.hidden = true;
        if (clearButton) clearButton.hidden = true;
        if (paintButton) paintButton.hidden = true;
        if (fillColorWrap) fillColorWrap.hidden = true;
        wrap.classList.remove("is-paint");
        applyTemplateAssets();
        serialize();
        status.textContent = "Tematik harita — işaret eklenmez.";
        notify();
        return;
      }
      if (addButton) addButton.hidden = false;
      if (addCircleButton) addCircleButton.hidden = false;
      if (clearButton) clearButton.hidden = false;
      if (paintButton) paintButton.hidden = !paintEnabled();
      if (fillColorWrap) fillColorWrap.hidden = !paintEnabled();
      if (!paintEnabled()) {
        paintMode = false;
        fills = [];
      }
      if (paintButton) {
        paintButton.classList.toggle("btn-primary", paintMode);
        paintButton.classList.toggle("btn-ghost", !paintMode);
      }
      wrap.classList.toggle("is-paint", paintMode && paintEnabled());
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
    }

    function addMarker(x, y, preset) {
      if (!enabled() || markers.length >= MAX_MARKERS) return;
      markers.push(
        normalizeMarker(
          Object.assign({}, preset || DEFAULT_ELLIPSE, {
            x: fixed(clamp(x, 0, 100)),
            y: fixed(clamp(y, 0, 100)),
          })
        )
      );
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
      if (!enabled() || event.target.closest(".map-marker")) return;
      var rect = wrap.getBoundingClientRect();
      var x = ((event.clientX - rect.left) / rect.width) * 100;
      var y = ((event.clientY - rect.top) / rect.height) * 100;
      if (paintMode && paintEnabled()) {
        var hit = hitProvince(x, y);
        if (hit) toggleFill(hit.id);
        return;
      }
      addMarker(x, y);
    });

    template.addEventListener("change", render);
    addButton.addEventListener("click", function () {
      addMarker(50 + markers.length * 2, 50, DEFAULT_ELLIPSE);
    });
    if (addCircleButton) {
      addCircleButton.addEventListener("click", function () {
        addMarker(50 + markers.length * 2, 48, DEFAULT_CIRCLE);
      });
    }
    clearButton.addEventListener("click", function () {
      markers = [];
      fills = [];
      selected = -1;
      render();
    });
    if (paintButton) {
      paintButton.addEventListener("click", function () {
        if (!paintEnabled()) return;
        paintMode = !paintMode;
        render();
      });
    }
    if (fillColorInput) {
      fillColorInput.addEventListener("input", function () {
        fillColor = fillColorInput.value || DEFAULT_FILL_COLOR;
      });
    }
    if (insertPlaceholderButton && stemField) {
      insertPlaceholderButton.addEventListener("click", function () {
        var start = stemField.selectionStart;
        var end = stemField.selectionEnd;
        var value = stemField.value || "";
        if (value.indexOf(MAP_PLACEHOLDER) !== -1) {
          status.textContent = "Metinde zaten [HARITA] var.";
          return;
        }
        var insert = (start > 0 && value[start - 1] !== "\n" ? "\n\n" : "") +
          MAP_PLACEHOLDER +
          (end < value.length && value[end] !== "\n" ? "\n\n" : "");
        stemField.value = value.slice(0, start) + insert + value.slice(end);
        stemField.dispatchEvent(new Event("input", { bubbles: true }));
        var cursor = start + insert.length;
        stemField.focus();
        stemField.setSelectionRange(cursor, cursor);
        status.textContent = "[HARITA] soru metnine eklendi.";
      });
    }
    baseImage.addEventListener("load", notify);
    previewImage.addEventListener("load", notify);

    function previewImageSrc() {
      if (staticMode()) {
        var entry = currentTemplate();
        return entry && entry.asset ? entry.asset : "";
      }
      if (!enabled()) return "";
      var source = previewImage;
      if (!source.complete || !source.naturalWidth) return "";
      var canvas = document.createElement("canvas");
      canvas.width = source.naturalWidth;
      canvas.height = source.naturalHeight;
      var ctx = canvas.getContext("2d");
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
      var romanPx = Math.max(68, Math.round(canvas.width * 0.048));
      ctx.font = "700 " + romanPx + "px Arial, Helvetica, sans-serif";
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

      markers.forEach(function (marker, index) {
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
        ctx.lineWidth = 3;
        ctx.strokeStyle = "#7f1d1d";
        ctx.stroke();

        var aabbW = Math.abs(rx * 2 * Math.cos(rot)) + Math.abs(ry * 2 * Math.sin(rot));
        var aabbH = Math.abs(rx * 2 * Math.sin(rot)) + Math.abs(ry * 2 * Math.cos(rot));
        var label = ROMAN[index];
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
    var provincesSrc = root.dataset.provincesSrc;
    if (provincesSrc) {
      fetch(provincesSrc)
        .then(function (response) {
          return response.ok ? response.json() : { provinces: [] };
        })
        .then(function (data) {
          provinces = data.provinces || [];
          renderFills();
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
