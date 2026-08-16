/**
 * Coordinate editor for reusable Turkey map questions.
 * Coordinates and marker sizes are normalized percentages.
 */
(function () {
  "use strict";

  var MAX_MARKERS = 12;
  var MAP_PLACEHOLDER = "[HARITA]";
  var ROMAN = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"];
  var DEFAULT_MARKER = {
    x: 50,
    y: 50,
    width: 4.5,
    height: 3.5,
    color: "#ef4444",
    labelSide: "right",
  };

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
    var clearButton = document.getElementById("map-clear-markers");
    var insertPlaceholderButton = document.getElementById("map-insert-placeholder");
    var stemField = document.getElementById("question-stem");
    var status = document.getElementById("map-editor-status");
    var initialData = document.getElementById("map-markers-data");
    var templatesData = document.getElementById("map-templates-data");
    var mapTemplates = {};
    var markers = [];
    var selected = -1;
    var drag = null;

    try {
      mapTemplates = templatesData ? JSON.parse(templatesData.textContent || "{}") : {};
    } catch (_) {
      mapTemplates = {};
    }

    try {
      markers = initialData ? JSON.parse(initialData.textContent || "[]") : [];
      if (!Array.isArray(markers)) markers = [];
    } catch (_) {
      markers = [];
    }

    markers = markers.slice(0, MAX_MARKERS).map(function (marker) {
      return {
        x: fixed(clamp(marker.x, 0, 100)),
        y: fixed(clamp(marker.y, 0, 100)),
        width: fixed(clamp(marker.width || 4.5, 1, 15)),
        height: fixed(clamp(marker.height || 3.5, 1, 15)),
        color: /^#[0-9a-f]{6}$/i.test(marker.color || "")
          ? marker.color
          : DEFAULT_MARKER.color,
        labelSide: ["left", "right", "top", "bottom"].includes(marker.labelSide)
          ? marker.labelSide
          : "right",
      };
    });

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
      hidden.value = JSON.stringify(markers);
      status.textContent = markers.length
        ? markers.length + " işaret"
        : "Haritaya tıklayarak işaret ekleyin";
    }

    function markerHtml(marker, index) {
      var node = document.createElement("button");
      node.type = "button";
      node.className = "map-marker" + (selected === index ? " is-selected" : "");
      node.dataset.index = String(index);
      node.style.left = marker.x + "%";
      node.style.top = marker.y + "%";
      node.style.width = marker.width + "%";
      node.style.height = marker.height + "%";
      node.style.backgroundColor = marker.color;
      node.setAttribute("aria-label", ROMAN[index] + " numaralı işaret");

      var label = document.createElement("span");
      label.className = "map-marker-label is-" + marker.labelSide;
      label.textContent = ROMAN[index];
      node.appendChild(label);

      node.addEventListener("click", function (event) {
        event.stopPropagation();
        selected = index;
        render();
      });
      node.addEventListener("pointerdown", function (event) {
        event.preventDefault();
        event.stopPropagation();
        selected = index;
        node.setPointerCapture(event.pointerId);
        drag = { pointerId: event.pointerId, node: node };
        renderControls();
      });
      node.addEventListener("pointermove", function (event) {
        if (!drag || drag.pointerId !== event.pointerId) return;
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
        drag = null;
      });
      node.addEventListener("pointercancel", function () {
        drag = null;
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
          markers.splice(index, 1);
          selected = Math.min(index, markers.length - 1);
          render();
        });
        order.appendChild(remove);
        head.appendChild(order);
        card.appendChild(head);

        var grid = document.createElement("div");
        grid.className = "map-marker-grid";
        grid.appendChild(numberInput("X (%)", "x", marker, index, 0, 100, 0.01));
        grid.appendChild(numberInput("Y (%)", "y", marker, index, 0, 100, 0.01));
        grid.appendChild(
          numberInput("Genişlik (%)", "width", marker, index, 1, 15, 0.01)
        );
        grid.appendChild(
          numberInput("Yükseklik (%)", "height", marker, index, 1, 15, 0.01)
        );

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
        layer.innerHTML = "";
        controls.innerHTML = "";
        if (addButton) addButton.hidden = true;
        if (clearButton) clearButton.hidden = true;
        applyTemplateAssets();
        status.textContent = "Tematik harita — işaret eklenmez.";
        serialize();
        notify();
        return;
      }
      if (addButton) addButton.hidden = false;
      if (clearButton) clearButton.hidden = false;
      if (!markerMode()) {
        selected = -1;
        markers = [];
      } else {
        applyTemplateAssets();
      }
      renderMarkers();
      renderControls();
      serialize();
      notify();
    }

    function addMarker(x, y) {
      if (!enabled() || markers.length >= MAX_MARKERS) return;
      markers.push(
        Object.assign({}, DEFAULT_MARKER, {
          x: fixed(clamp(x, 0, 100)),
          y: fixed(clamp(y, 0, 100)),
        })
      );
      selected = markers.length - 1;
      render();
    }

    wrap.addEventListener("click", function (event) {
      if (!enabled() || event.target.closest(".map-marker")) return;
      var rect = wrap.getBoundingClientRect();
      addMarker(
        ((event.clientX - rect.left) / rect.width) * 100,
        ((event.clientY - rect.top) / rect.height) * 100
      );
    });

    template.addEventListener("change", render);
    addButton.addEventListener("click", function () {
      addMarker(50 + markers.length * 2, 50);
    });
    clearButton.addEventListener("click", function () {
      markers = [];
      selected = -1;
      render();
    });
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
      ctx.font = "700 " + Math.max(28, Math.round(canvas.width * 0.025)) + "px Georgia";
      ctx.textBaseline = "middle";
      ctx.lineWidth = 3;
      ctx.strokeStyle = "#ffffff";
      ctx.fillStyle = "#111827";

      markers.forEach(function (marker, index) {
        var cx = (marker.x / 100) * canvas.width;
        var cy = (marker.y / 100) * canvas.height;
        var w = (marker.width / 100) * canvas.width;
        var h = (marker.height / 100) * canvas.height;
        ctx.beginPath();
        ctx.ellipse(cx, cy, w / 2, h / 2, 0, 0, Math.PI * 2);
        ctx.fillStyle = marker.color;
        ctx.fill();
        ctx.lineWidth = 3;
        ctx.strokeStyle = "#7f1d1d";
        ctx.stroke();

        var label = ROMAN[index];
        var measure = ctx.measureText(label);
        var gap = Math.max(10, canvas.width * 0.008);
        var tx = cx + w / 2 + gap;
        var ty = cy;
        if (marker.labelSide === "left") tx = cx - w / 2 - gap - measure.width;
        if (marker.labelSide === "top") {
          tx = cx - measure.width / 2;
          ty = cy - h / 2 - gap - 14;
        }
        if (marker.labelSide === "bottom") {
          tx = cx - measure.width / 2;
          ty = cy + h / 2 + gap + 14;
        }
        ctx.strokeStyle = "#ffffff";
        ctx.lineWidth = 3;
        ctx.strokeText(label, tx, ty);
        ctx.fillStyle = "#111827";
        ctx.fillText(label, tx, ty);
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
    render();
  }

  document.addEventListener("DOMContentLoaded", init);
})();
