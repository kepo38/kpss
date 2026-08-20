/**
 * Tablo / eşleştirme şıkları (ÖSYM: İnanç | Mağara | Termal).
 * Şık: "Şanlıurfa - Antalya - Afyonkarahisar" → eşit sütun, dikey çizgi yok.
 */
(function (global) {
  var ROMANS = ["I", "II", "III", "IV", "V"];
  var DASH_SPLIT = /\s+(?:[-–—―−]{1,3}|---+)\s+/;
  var TIGHT_DASH = /[-–—―−]{1,3}/;
  var PIPE_SPLIT = /\s*\|\s*/;
  var MARK = /<!--optcols:([^>]*)-->/;

  function stripMarkup(text) {
    return String(text || "")
      .replace(/&mdash;|&#8212;|&#x2014;/gi, "—")
      .replace(/&ndash;|&#8211;|&#x2013;/gi, "–")
      .replace(/\{(?:green|red|blue|g|r|m)\}/gi, "")
      .replace(/\{\/(?:green|red|blue|g|r|m)\}/gi, "")
      .replace(/\*\*/g, "")
      .replace(/__/g, "")
      .replace(/\u00a0/g, " ")
      .replace(/\s+/g, " ")
      .trim();
  }

  function partsOf(text, re) {
    return String(text)
      .split(re)
      .map(function (p) {
        return p.trim();
      })
      .filter(Boolean);
  }

  function labeledRow(raw) {
    var text = stripMarkup(raw);
    if (!text || text.indexOf(":") === -1) return null;
    var chunks = text.split(/\s*[,;]\s*(?=[^,:]{1,24}:)/);
    if (chunks.length < 3) return null;
    var keys = [];
    var vals = [];
    var i;
    for (i = 0; i < chunks.length; i++) {
      var idx = chunks[i].indexOf(":");
      if (idx < 1) return null;
      var key = chunks[i].slice(0, idx).trim();
      var val = chunks[i].slice(idx + 1).trim();
      if (!key || !val || key.length > 24) return null;
      keys.push(key);
      vals.push(val);
    }
    return { keys: keys, vals: vals };
  }

  function splitCells(raw) {
    var labeled = labeledRow(raw);
    if (labeled) return labeled.vals;
    var text = stripMarkup(raw);
    if (!text) return null;
    var parts = partsOf(text, DASH_SPLIT);
    if (parts.length < 3) parts = partsOf(text, PIPE_SPLIT);
    if (parts.length < 3) {
      var tight = partsOf(text, TIGHT_DASH);
      if (
        tight.length >= 3 &&
        tight.every(function (p) {
          return p.indexOf(" ") === -1;
        })
      ) {
        parts = tight;
      }
    }
    if (parts.length < 3) return null;
    return parts;
  }

  function alignedCount(texts) {
    var counts = {};
    var i;
    for (i = 0; i < texts.length; i++) {
      var cells = splitCells(texts[i]);
      if (!cells) continue;
      var n = cells.length;
      counts[n] = (counts[n] || 0) + 1;
    }
    var best = 0;
    var bestN = 0;
    Object.keys(counts).forEach(function (key) {
      var n = Number(key);
      var seen = counts[n];
      if (n >= 3 && seen > best) {
        best = seen;
        bestN = n;
      }
    });
    if (best < 2) return 0;
    return bestN;
  }

  function visibleStem(stem) {
    return String(stem || "")
      .replace(/\s*<!--optcols:[^>]*-->\s*/g, "\n")
      .replace(/\n{3,}/g, "\n\n")
      .trim();
  }

  function markerHeaders(stem, columns) {
    var m = String(stem || "").match(MARK);
    if (!m) return null;
    var parts = m[1]
      .split("|")
      .map(function (p) {
        return p.trim();
      })
      .filter(Boolean);
    return parts.length === columns ? parts : null;
  }

  function writeMarker(stem, labels) {
    var body = visibleStem(stem);
    if (!labels.some(Boolean)) return body;
    return body + "\n<!--optcols:" + labels.join("|") + "-->";
  }

  function pipeHeaders(stem, columns) {
    var lines = visibleStem(stem).split(/\n/);
    var i;
    for (i = 0; i < lines.length; i++) {
      var parts = stripMarkup(lines[i])
        .split("|")
        .map(function (p) {
          return p.trim();
        })
        .filter(Boolean);
      if (parts.length === columns && parts.every(function (p) {
        return p.length <= 24;
      })) {
        return parts;
      }
    }
    return null;
  }

  function wordHeaders(stem, columns) {
    var lines = visibleStem(stem).split(/\n/);
    var i;
    for (i = 0; i < lines.length; i++) {
      var words = stripMarkup(lines[i].replace(/_+/g, " "))
        .split(/\s+/)
        .filter(Boolean);
      if (words.length !== columns) continue;
      if (
        words.every(function (w) {
          return w.length <= 24 && /^[A-ZÇĞİÖŞÜÂÎÛ]/.test(w);
        })
      ) {
        return words;
      }
    }
    return null;
  }

  function headersFromOptions(texts, columns) {
    var i;
    for (i = 0; i < texts.length; i++) {
      var row = labeledRow(texts[i]);
      if (row && row.keys.length === columns) return row.keys;
    }
    return null;
  }

  function headersFromStem(stem, columns) {
    if (columns < 3 || columns > ROMANS.length) return null;
    var marked = markerHeaders(stem, columns);
    if (marked) return marked;
    var src = visibleStem(stem);
    var labels = [];
    var i;
    for (i = 0; i < columns; i++) {
      var re = new RegExp(
        "(^|[^IVX])" + ROMANS[i] + "\\.\\s+([A-ZÇĞİÖŞÜa-zçğıöşüÂÎÛâîû]+)"
      );
      var m = src.match(re);
      if (!m) return pipeHeaders(stem, columns) || wordHeaders(stem, columns);
      labels.push(m[2]);
    }
    return labels;
  }

  function escapeText(text) {
    return String(text || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
  }

  function cellHtml(cell) {
    if (global.KpssMathRender && global.KpssMathRender.plainInline) {
      return global.KpssMathRender.plainInline(cell);
    }
    return escapeText(cell);
  }

  function renderCols(el, cells) {
    el.classList.add("quiz-opt-cols");
    el.innerHTML = cells
      .map(function (c) {
        return "<span>" + cellHtml(c) + "</span>";
      })
      .join("");
  }

  function readFormHeaders(formHead, columns) {
    if (!formHead) return [];
    var inputs = formHead.querySelectorAll("input.option-table-h");
    var out = [];
    var i;
    for (i = 0; i < columns; i++) {
      out.push(inputs[i] ? inputs[i].value.trim() : "");
    }
    return out;
  }

  function bindFormHead(formHead, stemEl) {
    if (!formHead || formHead.getAttribute("data-bound")) return;
    formHead.setAttribute("data-bound", "1");
    formHead.addEventListener("input", function () {
      if (!stemEl) return;
      var inputs = formHead.querySelectorAll("input.option-table-h");
      var labels = [];
      var i;
      for (i = 0; i < inputs.length; i++) labels.push(inputs[i].value.trim());
      stemEl.value = writeMarker(stemEl.value, labels);
      if (global.KpssQuestionPreview && global.KpssQuestionPreview.sync) {
        global.KpssQuestionPreview.sync();
      }
    });
  }

  function bindSubmit(stemEl, formHead) {
    var form = stemEl && stemEl.form;
    if (!form || !formHead || form.getAttribute("data-optcols-submit")) return;
    form.setAttribute("data-optcols-submit", "1");
    form.addEventListener("submit", function () {
      var inputs = formHead.querySelectorAll("input.option-table-h");
      var labels = [];
      var i;
      for (i = 0; i < inputs.length; i++) labels.push(inputs[i].value.trim());
      stemEl.value = writeMarker(stemEl.value, labels);
    });
  }

  function ensureFormInputs(formHead, columns, labels, stemEl) {
    if (!formHead || !columns) {
      if (formHead) {
        formHead.hidden = true;
        formHead.innerHTML = "";
        formHead.removeAttribute("data-bound");
      }
      return;
    }
    var inputs = formHead.querySelectorAll("input.option-table-h");
    var focused = formHead.contains(document.activeElement);
    if (inputs.length !== columns) {
      var html = "";
      var i;
      for (i = 0; i < columns; i++) {
        html +=
          '<input class="option-table-h" type="text" maxlength="32" placeholder="Sütun ' +
          (i + 1) +
          '">';
      }
      formHead.innerHTML = html;
      formHead.removeAttribute("data-bound");
      inputs = formHead.querySelectorAll("input.option-table-h");
    }
    formHead.style.gridTemplateColumns =
      "repeat(" + columns + ", minmax(0, 1fr))";
    bindFormHead(formHead, stemEl);
    bindSubmit(stemEl, formHead);
    if (!focused) {
      for (var j = 0; j < columns; j++) {
        if (inputs[j] && labels[j]) inputs[j].value = labels[j];
      }
    }
    formHead.hidden = false;
  }

  function apply(opts) {
    var texts = opts.optionTexts || [];
    var els = opts.optionEls || [];
    var nonempty = [];
    var i;
    for (i = 0; i < texts.length; i++) {
      if (stripMarkup(texts[i])) nonempty.push(texts[i]);
    }
    var colN = alignedCount(nonempty);
    var parsed = colN
      ? headersFromStem(opts.stem || "", colN) ||
        headersFromOptions(nonempty, colN) ||
        []
      : [];
    var fromForm = colN ? readFormHeaders(opts.formHead, colN) : [];
    var labels = fromForm.some(Boolean) ? fromForm : parsed;
    if (colN && labels.length < colN) {
      while (labels.length < colN) labels.push("");
    }

    ensureFormInputs(opts.formHead, colN, labels, opts.stemEl);

    var previewHead = opts.previewHead;
    if (previewHead) {
      if (colN) {
        previewHead.innerHTML =
          '<span class="quiz-opt-col-spacer"></span>' +
          labels
            .map(function (label) {
              return "<span>" + escapeText(label) + "</span>";
            })
            .join("");
        previewHead.hidden = false;
        previewHead.classList.add("is-opt-table");
        previewHead.style.gridTemplateColumns =
          "26px " + Array(colN + 1).join("minmax(0,1fr) ").trim();
      } else {
        previewHead.innerHTML = "";
        previewHead.hidden = true;
        previewHead.classList.remove("is-opt-table");
      }
    }

    var optsRoot = opts.optsRoot;
    if (optsRoot) {
      optsRoot.classList.toggle("is-opt-table", !!colN);
    }

    for (i = 0; i < els.length; i++) {
      var el = els[i];
      var row = opts.optionRows ? opts.optionRows[i] : el.closest(".quiz-mock-opt");
      var t = texts[i] || "";
      el.classList.remove("quiz-opt-cols");
      if (row) {
        row.classList.toggle("is-opt-table", !!colN);
        if (colN) {
          row.style.gridTemplateColumns =
            "26px " + Array(colN + 1).join("minmax(0,1fr) ").trim();
        } else {
          row.style.gridTemplateColumns = "";
        }
      }
      if (!stripMarkup(t)) {
        if (opts.emptyHtml) el.innerHTML = opts.emptyHtml(i);
        else el.textContent = "";
        continue;
      }
      var cells = splitCells(t);
      if (colN && cells && cells.length === colN) {
        renderCols(el, cells);
      } else if (opts.plainHtml) {
        el.innerHTML = opts.plainHtml(t);
      } else {
        el.innerHTML = cellHtml(t);
      }
    }
  }

  global.KpssOptionTable = {
    cellsOf: splitCells,
    alignedCount: alignedCount,
    headersFromStem: headersFromStem,
    visibleStem: visibleStem,
    apply: apply,
  };
})(window);
