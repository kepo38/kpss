/**
 * Soru formu → sağdaki telefon önizlemesi (sınav formatı, canlı).
 */
(function () {
  var MAP_PLACEHOLDER = "[HARITA]";
  var OPTION_PLACEHOLDERS = { "": true, "—": true, "-": true, "Görsel şık": true };
  var scenarioCatalog = {};
  var formBootstrap = { options: {}, solution: "", correct_option: "" };
  var previewSeed = { stem: "", solution: "", options: {}, correct_option: "" };
  var initialRenderDone = false;

  function loadPreviewSeed() {
    var el = document.getElementById("question-preview-seed");
    if (!el) return;
    try {
      previewSeed = JSON.parse(el.textContent || "{}") || {};
      if (!previewSeed.options) previewSeed.options = {};
    } catch (err) {
      previewSeed = { stem: "", solution: "", options: {}, correct_option: "" };
    }
  }

  function normalizedFieldValue(text) {
    var t = (text || "").trim();
    return isPlaceholderOption(t) ? "" : t;
  }

  function markPreviewDirty(el) {
    if (el) el.dataset.previewDirty = "1";
  }

  function captureServerFieldValues() {
    var form = questionForm();
    if (!form) return;
    form.querySelectorAll("textarea, input[type=text], select").forEach(function (el) {
      if (!el.name && !el.id) return;
      el.setAttribute(
        "data-server-value",
        String(el.value != null ? el.value : "").trim()
      );
    });
  }

  function shouldKeepServerPreview(previewEl, formEl, liveText) {
    if (!previewEl || previewEl.getAttribute("data-server-rendered") !== "1") {
      return false;
    }
    if (formEl && formEl.dataset.previewDirty === "1") {
      return false;
    }
    var seed = (previewEl.getAttribute("data-initial-text") || "").trim();
    if (!seed) return false;
    var serverVal = formEl
      ? normalizedFieldValue(formEl.getAttribute("data-server-value") || "")
      : "";
    return normalizedFieldValue(liveText) === serverVal;
  }

  function previewSeedOption(letter) {
    var opts = previewSeed.options || {};
    return (opts[letter] || "").trim();
  }

  function loadFormBootstrap() {
    var el = document.getElementById("question-form-bootstrap");
    if (!el) return;
    try {
      formBootstrap = JSON.parse(el.textContent || "{}") || {};
      if (!formBootstrap.options) formBootstrap.options = {};
    } catch (err) {
      formBootstrap = { options: {}, solution: "", correct_option: "" };
    }
  }

  function loadScenarioCatalog() {
    var el = document.getElementById("question-scenarios-data");
    if (!el) return;
    try {
      var raw = JSON.parse(el.textContent || "[]");
      scenarioCatalog = {};
      (raw || []).forEach(function (item) {
        if (item && item.id != null) {
          scenarioCatalog[String(item.id)] = item;
        }
      });
    } catch (err) {
      scenarioCatalog = {};
    }
  }

  function selectedScenario() {
    var sel =
      document.getElementById("scenario-select") ||
      document.querySelector('[name="scenario_id"]');
    if (!sel || !(sel.value || "").trim()) return null;
    return scenarioCatalog[String(sel.value)] || null;
  }

  function syncScenarioCard() {
    var card = document.getElementById("pv-scenario-card");
    var titleEl = document.getElementById("pv-scenario-title");
    var stemEl = document.getElementById("pv-scenario-stem");
    if (!card || !titleEl || !stemEl) return;

    var scenario = selectedScenario();
    if (!scenario || !(scenario.stem || "").trim()) {
      card.hidden = true;
      titleEl.textContent = "Olay";
      stemEl.innerHTML = "";
      return;
    }

    var title = (scenario.title || "").trim() || "Olay";
    titleEl.textContent = title;
    titleEl.classList.toggle("is-empty", !((scenario.title || "").trim()));
    stemEl.innerHTML = stemToHtml(scenario.stem);
    stemEl.classList.toggle("is-empty", false);
    card.hidden = false;
  }

  function richHtml(text) {
    if (window.KpssMathRender) {
      return window.KpssMathRender.richInline(text);
    }
    return String(text || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
  }

  function stemToHtml(text) {
    if (window.KpssMathRender) {
      return window.KpssMathRender.examStoredDocumentHtml
        ? window.KpssMathRender.examStoredDocumentHtml(text)
        : window.KpssMathRender.examDocumentHtml(text);
    }
    if (!text) return "";
    return "<p>" + richHtml(text) + "</p>";
  }

  function formatPlain(text) {
    if (window.KpssMathRender) {
      return window.KpssMathRender.examFormat(text);
    }
    return (text || "").trim();
  }

  function escapeText(text) {
    return String(text || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
  }

  function questionForm() {
    return document.getElementById("question-form");
  }

  function fieldEl(name) {
    var form = questionForm();
    var el = null;
    if (form) {
      el = form.querySelector('[name="' + name + '"]');
    }
    if (!el) {
      el = document.querySelector('[name="' + name + '"]');
    }
    if (!el && /^option_[a-e]$/.test(name)) {
      el = document.getElementById(
        "option-" + name.replace("option_", "") + "-text"
      );
    }
    if (!el && name === "solution") {
      el = document.getElementById("question-solution");
    }
    if (!el && name === "stem") {
      el = document.getElementById("question-stem");
    }
    return el;
  }

  function fieldText(name) {
    var el = fieldEl(name);
    if (!el) return "";
    var live = String(el.value != null ? el.value : "").trim();
    if (live) return live;
    var fallback = String(el.defaultValue != null ? el.defaultValue : "").trim();
    if (fallback) return fallback;
    var bootAttr = el.getAttribute("data-bootstrap-value");
    return bootAttr ? String(bootAttr).trim() : "";
  }

  /** Önizleme sync: yalnızca canlı textarea değeri (defaultValue/bootstrap yok). */
  function liveFieldText(name) {
    var el = fieldEl(name);
    if (!el) return "";
    return String(el.value != null ? el.value : "").trim();
  }

  function solutionFieldEl() {
    return document.getElementById("question-solution") || fieldEl("solution");
  }

  function val(name) {
    return fieldText(name);
  }

  function bootstrapOption(letter) {
    var opts = formBootstrap.options || {};
    return (opts[letter] || "").trim();
  }

  function optionFieldEl(letter) {
    var lower = letter.toLowerCase();
    return (
      document.getElementById("option-" + lower + "-text") ||
      fieldEl("option_" + lower)
    );
  }

  function optionValue(letter) {
    var el = optionFieldEl(letter);
    if (el) {
      var live = String(el.value != null ? el.value : "").trim();
      if (el.dataset.previewDirty === "1") {
        return isPlaceholderOption(live) ? "" : live;
      }
      if (live && !isPlaceholderOption(live)) return live;
    }
    var pv = document.getElementById("pv-opt-text-" + letter);
    if (pv) {
      var seed = (pv.getAttribute("data-initial-text") || "").trim();
      if (seed && !isPlaceholderOption(seed)) return seed;
    }
    var fromSeed = previewSeedOption(letter);
    if (fromSeed && !isPlaceholderOption(fromSeed)) return fromSeed;
    var fromBoot = bootstrapOption(letter);
    if (fromBoot && !isPlaceholderOption(fromBoot)) return fromBoot;
    return "";
  }

  function solutionValue() {
    var el = solutionFieldEl();
    if (el) {
      var live = String(el.value != null ? el.value : "").trim();
      if (el.dataset.previewDirty === "1") return live;
      if (live) return live;
    }
    var solBody = document.getElementById("pv-solution-body");
    if (solBody) {
      var seed = (solBody.getAttribute("data-initial-text") || "").trim();
      if (seed) return seed;
    }
    if ((previewSeed.solution || "").trim()) return previewSeed.solution.trim();
    return (formBootstrap.solution || "").trim();
  }

  function seedPreviewElements() {
    ["A", "B", "C", "D", "E"].forEach(function (letter) {
      var el = document.getElementById("pv-opt-text-" + letter);
      if (!el || el.getAttribute("data-initial-text")) return;
      var seed = optionValue(letter) || bootstrapOption(letter);
      if (seed && !isPlaceholderOption(seed)) {
        el.setAttribute("data-initial-text", seed);
      }
    });
    var solBody = document.getElementById("pv-solution-body");
    if (solBody && !solBody.getAttribute("data-initial-text")) {
      var solSeed = solutionValue() || (formBootstrap.solution || "").trim();
      if (solSeed) solBody.setAttribute("data-initial-text", solSeed);
    }
  }

  function hydrateFormFromBootstrap() {
    var opts = formBootstrap.options || {};
    ["A", "B", "C", "D", "E"].forEach(function (letter) {
      var key = "option_" + letter.toLowerCase();
      var el = fieldEl(key);
      var boot = bootstrapOption(letter);
      if (!el || !boot || isPlaceholderOption(boot)) return;
      var cur = liveFieldText(key);
      if (!cur || isPlaceholderOption(cur)) {
        el.value = boot;
      }
    });
    var solEl = solutionFieldEl();
    var bootSol = (formBootstrap.solution || "").trim();
    if (solEl && bootSol && !liveFieldText("solution")) {
      solEl.value = bootSol;
    }
    var bootAnswer = (formBootstrap.correct_option || "").trim();
    if (bootAnswer) {
      var answerSel = fieldEl("correct_option");
      if (answerSel && !(answerSel.value || "").trim()) {
        answerSel.value = bootAnswer;
      }
    }
  }

  function isPlaceholderOption(text) {
    return OPTION_PLACEHOLDERS.hasOwnProperty((text || "").trim());
  }

  function parseEmbeddedOptions(stem) {
    var out = { A: "", B: "", C: "", D: "", E: "" };
    if (!stem) return out;
    var lines = String(stem).split(/\n/);
    var current = "";
    var buf = [];
    function flush() {
      if (current && buf.length) {
        out[current] = buf.join(" ").replace(/\s+/g, " ").trim();
      }
      current = "";
      buf = [];
    }
    lines.forEach(function (ln) {
      var m = ln.match(/^\s*([A-E])\s*[\)\]\.\:\-]\s*(.*)$/i);
      if (m) {
        flush();
        current = m[1].toUpperCase();
        if ((m[2] || "").trim()) buf.push(m[2].trim());
        return;
      }
      if (current && ln.trim()) buf.push(ln.trim());
    });
    flush();
    return out;
  }

  function resolveOptionTexts(stem) {
    var parsed = parseEmbeddedOptions(stem);
    var out = {};
    ["A", "B", "C", "D", "E"].forEach(function (k) {
      out[k] = optionValue(k) || parsed[k] || "";
    });
    return out;
  }

  function peelStemForPreview(stem, optionTexts) {
    var body = stem || "";
    if (!body) return body;
    var filled = ["A", "B", "C", "D", "E"].filter(function (k) {
      return !isPlaceholderOption(optionTexts[k]);
    });
    if (filled.length < 3) return body;
    var lines = body.split("\n");
    var cut = -1;
    for (var i = 0; i < lines.length; i++) {
      if (/^\s*A\s*[\)\]\.\:\-]\s+/i.test(lines[i])) {
        cut = i;
        break;
      }
    }
    if (cut >= 0) {
      return lines.slice(0, cut).join("\n").trim();
    }
    return body;
  }

  function renderOptionPreviewText(el, text) {
    if (!el) return;
    var t = (text || "").trim();
    if (!t || isPlaceholderOption(t)) {
      el.textContent = "";
      el.classList.add("is-empty");
      return;
    }
    el.innerHTML = window.KpssMathRender
      ? window.KpssMathRender.optionInline(t)
      : escapeText(formatPlain(t));
    el.classList.remove("is-empty");
  }

  function currentStemImageSrc() {
    var previewBox = document.getElementById("stem-image-preview-new");
    var previewImg = document.getElementById("stem-image-preview-new-img");
    if (
      previewBox &&
      !previewBox.hidden &&
      previewImg &&
      previewImg.getAttribute("src")
    ) {
      return previewImg.src;
    }

    var existing = document.querySelector(".stem-image-preview img");
    if (existing && existing.getAttribute("src")) {
      return existing.src;
    }
    return "";
  }

  function currentImageSrc() {
    if (
      window.KpssMapQuestionEditor &&
      window.KpssMapQuestionEditor.isEnabled()
    ) {
      return window.KpssMapQuestionEditor.previewImageSrc();
    }

    var stem = currentStemImageSrc();
    if (stem) return stem;

    var ocrPreview = document.getElementById("q-image-preview-img");
    var ocrBox = document.getElementById("q-image-preview");
    if (
      ocrBox &&
      !ocrBox.hidden &&
      ocrPreview &&
      ocrPreview.getAttribute("src")
    ) {
      return ocrPreview.src;
    }
    return "";
  }

  function stemImagePosition() {
    var checked = document.querySelector('[name="stem_image_position"]:checked');
    return checked && checked.value === "above" ? "above" : "below";
  }

  function syncStemImageSection() {
    var section = document.getElementById("stem-image-section");
    if (!section) return;
    var mapEnabled =
      window.KpssMapQuestionEditor &&
      window.KpssMapQuestionEditor.isEnabled();
    section.classList.toggle("is-disabled", mapEnabled);
    section.querySelectorAll("input, button, select, textarea").forEach(function (el) {
      el.disabled = mapEnabled;
    });
  }

  function placeBlockStemImage(imgEl, stemWrap, svgEl, position) {
    if (!imgEl || !stemWrap) return;
    var body = stemWrap.closest(".quiz-mock-body");
    if (!body) return;
    if (position === "above") {
      if (stemWrap.previousElementSibling === imgEl) return;
      body.insertBefore(imgEl, stemWrap);
      return;
    }
    var after = svgEl && svgEl.parentNode === body ? svgEl : stemWrap;
    if (imgEl.previousElementSibling === after) return;
    if (after.nextSibling) {
      body.insertBefore(imgEl, after.nextSibling);
    } else {
      body.appendChild(imgEl);
    }
  }

  function inlineMapHtml(src) {
    if (!src) {
      return '<span class="quiz-mock-img-inline quiz-mock-img-slot">Harita</span>';
    }
    return (
      '<img class="quiz-mock-img-inline" src="' +
      src.replace(/"/g, "&quot;") +
      '" alt="Harita">'
    );
  }

  function stemWithInlineMap(text, src) {
    if (!text || text.indexOf(MAP_PLACEHOLDER) === -1) {
      return { html: stemToHtml(text), inline: false };
    }
    var parts = text.split(MAP_PLACEHOLDER);
    var html = "";
    parts.forEach(function (part, index) {
      var chunk = (part || "").trim();
      if (chunk) {
        html += stemToHtml(chunk);
      }
      if (index < parts.length - 1) {
        html += inlineMapHtml(src);
      }
    });
    return { html: html, inline: true };
  }

  function currentFigureSvg() {
    var el =
      document.getElementById("figure-svg") ||
      document.querySelector('[name="figure_svg"]');
    return el ? (el.value || "").trim() : "";
  }

  function currentSolutionImageSrc() {
    var solutionInput = document.getElementById("solution-image-input");
    var keep = document.querySelector('[name="keep_solution_image"]');
    if (keep && !keep.checked) return "";

    var previewBox = document.getElementById("solution-image-preview");
    var previewImg = document.getElementById("solution-image-preview-img");
    if (
      previewBox &&
      !previewBox.hidden &&
      previewImg &&
      (previewImg.getAttribute("src") || previewImg.src)
    ) {
      return previewImg.src;
    }

    var existing = document.getElementById("solution-existing-thumb");
    if (existing && (existing.getAttribute("src") || existing.src)) {
      return existing.src;
    }

    if (solutionInput && solutionInput.files && solutionInput.files[0]) {
      return "";
    }
    return "";
  }

  function syncFigureSvg(svgBox, svgText) {
    if (!svgBox) return;
    if (svgText && svgText.indexOf("<svg") !== -1) {
      svgBox.innerHTML = svgText.replace(/<script[\s\S]*?<\/script>/gi, "");
      svgBox.classList.add("is-on");
      svgBox.removeAttribute("aria-hidden");
    } else {
      svgBox.innerHTML = "";
      svgBox.classList.remove("is-on");
      svgBox.setAttribute("aria-hidden", "true");
    }
  }

  function sync() {
    try {
      syncPreview();
    } catch (err) {
      console.error("KpssQuestionPreview.sync failed", err);
    }
  }

  function syncPreview() {
    loadFormBootstrap();
    seedPreviewElements();
    var stemEl = document.getElementById("pv-stem");
    var imgEl = document.getElementById("pv-img");
    var svgEl = document.getElementById("pv-svg");
    var solWrap = document.getElementById("pv-solution");
    var solBody = document.getElementById("pv-solution-body");
    if (!stemEl) return;

    syncScenarioCard();

    var stem = liveFieldText("stem") || val("stem");
    var optionTexts = resolveOptionTexts(stem);
    if (window.KpssOptionTable && window.KpssOptionTable.visibleStem) {
      stem = peelStemForPreview(
        window.KpssOptionTable.visibleStem(stem),
        optionTexts
      );
    } else {
      stem = peelStemForPreview(stem, optionTexts);
    }
    var src = currentImageSrc();
    var rendered = stemWithInlineMap(stem, src);
    if (stem) {
      stemEl.innerHTML = rendered.html;
      stemEl.classList.remove("is-empty");
    } else {
      stemEl.innerHTML = "<p>Soru metni buraya…</p>";
      stemEl.classList.add("is-empty");
    }

    var visualOpts =
      window.KpssQuestionOptions && window.KpssQuestionOptions.isVisual
        ? window.KpssQuestionOptions.isVisual()
        : false;
    var hasOptCrop = false;
    if (visualOpts && window.KpssQuestionOptions) {
      ["A", "B", "C", "D", "E"].forEach(function (k) {
        if (window.KpssQuestionOptions.optionImageSrc(k)) hasOptCrop = true;
      });
    }
    if (imgEl) {
      // Görsel şık crop'ları varken tam sayfa kaynağı gösterme (çift şık).
      if (src && !rendered.inline && !(visualOpts && hasOptCrop)) {
        imgEl.src = src;
        imgEl.classList.add("is-on");
        placeBlockStemImage(
          imgEl,
          document.querySelector(".quiz-mock-stem-wrap"),
          svgEl,
          stemImagePosition()
        );
      } else {
        imgEl.removeAttribute("src");
        imgEl.classList.remove("is-on");
      }
    }

    syncStemImageSection();

    syncFigureSvg(svgEl, currentFigureSvg());

    var correct = val("correct_option");
    if (!correct && (formBootstrap.correct_option || "").trim()) {
      correct = (formBootstrap.correct_option || "").trim();
    }
    var filled = [];
    ["A", "B", "C", "D", "E"].forEach(function (k) {
      var row = document.getElementById("pv-opt-" + k);
      var text = document.getElementById("pv-opt-text-" + k);
      if (!row || !text) return;
      filled.push({
        k: k,
        row: row,
        text: text,
        t: optionTexts[k] || "",
      });
    });
    var optsRoot = document.querySelector("#question-preview .quiz-mock-opts");
    var previewHead = document.getElementById("pv-opt-col-head");
    var tableMode =
      window.KpssOptionTable && window.KpssOptionTable.readTableMode
        ? window.KpssOptionTable.readTableMode()
        : "none";
    var tableApplied = false;
    if (window.KpssOptionTable && !visualOpts && tableMode !== "none") {
      tableApplied = true;
      window.KpssOptionTable.apply({
        stem: val("stem"),
        stemEl: fieldEl("stem"),
        optionTexts: filled.map(function (item) {
          return item.t;
        }),
        optionEls: filled.map(function (item) {
          return item.text;
        }),
        optionRows: filled.map(function (item) {
          return item.row;
        }),
        previewHead: previewHead,
        formHead: document.getElementById("option-table-head"),
        optsRoot: optsRoot,
        emptyHtml: function (index) {
          return "Şık " + filled[index].k;
        },
        plainHtml: function (t) {
          if (!t || isPlaceholderOption(t)) return "";
          return window.KpssMathRender
            ? window.KpssMathRender.optionInline(t)
            : escapeText(formatPlain(t));
        },
      });
    } else {
      if (previewHead) {
        previewHead.innerHTML = "";
        previewHead.hidden = true;
        previewHead.classList.remove("is-opt-table");
      }
      if (optsRoot) optsRoot.classList.remove("is-opt-table");
      filled.forEach(function (item) {
        if (item.row) {
          item.row.classList.remove("is-opt-table");
          item.row.style.gridTemplateColumns = "";
        }
        item.text.classList.remove("quiz-opt-cols");
      });
    }
    if (optsRoot) {
      optsRoot.classList.toggle("is-visual-preview", !!(visualOpts && hasOptCrop));
    }
    filled.forEach(function (item) {
      var visual =
        window.KpssQuestionOptions && window.KpssQuestionOptions.isVisual
          ? window.KpssQuestionOptions.isVisual()
          : false;
      var imgSrc =
        visual && window.KpssQuestionOptions
          ? window.KpssQuestionOptions.optionImageSrc(item.k)
          : "";
      var showOptImg = !!(visual && imgSrc);
      if (showOptImg) {
        item.text.innerHTML =
          '<img class="quiz-mock-opt-img" src="' +
          imgSrc.replace(/"/g, "&quot;") +
          '" alt="Şık ' +
          item.k +
          '">';
        item.text.classList.remove("is-empty");
      } else if (
        tableApplied &&
        item.t &&
        !isPlaceholderOption(item.t) &&
        item.text.classList.contains("quiz-opt-cols")
      ) {
        item.text.classList.remove("is-empty");
      } else if (item.t && !isPlaceholderOption(item.t)) {
        var optFormEl = optionFieldEl(item.k);
        if (shouldKeepServerPreview(item.text, optFormEl, item.t)) {
          item.text.classList.remove("is-empty");
        } else {
          renderOptionPreviewText(item.text, item.t);
          item.text.setAttribute("data-initial-text", item.t);
        }
      } else if (visual) {
        item.text.textContent = "";
        item.text.classList.add("is-empty");
      } else {
        item.text.textContent = "Şık " + item.k;
        item.text.classList.add("is-empty");
        item.text.removeAttribute("data-initial-text");
      }
      item.text.classList.toggle("has-opt-img", showOptImg);
      item.row.classList.toggle("has-opt-img", showOptImg);
      item.row.classList.toggle("is-correct", correct === item.k);
    });

    var sol = solutionValue();
    var solImgEl = document.getElementById("pv-solution-img");
    var solImgSrc = currentSolutionImageSrc();
    if (solWrap && solBody) {
      if (solImgEl) {
        if (solImgSrc) {
          solImgEl.src = solImgSrc;
          solImgEl.hidden = false;
          solImgEl.classList.add("is-on");
        } else {
          solImgEl.removeAttribute("src");
          solImgEl.hidden = true;
          solImgEl.classList.remove("is-on");
        }
      }
      if (sol) {
        // Sunucu gövdesi düz markdown metnidir (HTML değil); her sync'te
        // MathRender ile boya — aksi halde ## / * literal görünür.
        solBody.innerHTML = window.KpssMathRender
          ? (window.KpssMathRender.solutionStoredDocumentHtml
              ? window.KpssMathRender.solutionStoredDocumentHtml(sol)
              : window.KpssMathRender.solutionDocumentHtml
                ? window.KpssMathRender.solutionDocumentHtml(sol)
                : window.KpssMathRender.examDocumentHtml(sol))
          : stemToHtml(sol);
        solBody.setAttribute("data-initial-text", sol);
        solBody.removeAttribute("data-server-rendered");
        solBody.classList.remove("is-empty");
      } else if (solBody.dataset.previewDirty !== "1") {
        solBody.textContent = "";
        solBody.removeAttribute("data-initial-text");
      }
      if (sol || solImgSrc) {
        solWrap.classList.add("is-on");
      } else {
        solWrap.classList.remove("is-on");
      }
    }

    var osymEl = document.getElementById("pv-osym");
    var osymCheck = document.getElementById("osym-sordu");
    if (osymEl && osymCheck) {
      osymEl.hidden = !osymCheck.checked;
    }
  }

  function bindRichTextSync(el) {
    if (!el || el.dataset.previewSyncBound === "1") return;
    el.dataset.previewSyncBound = "1";
    ["input", "paste", "cut", "keyup", "compositionend", "change"].forEach(
      function (evt) {
        el.addEventListener(evt, function () {
          markPreviewDirty(el);
          sync();
        });
      }
    );
  }

  function renderInitialPreview() {
    if (initialRenderDone) return;
    if (!window.KpssMathRender) return;
    initialRenderDone = true;
    sync();
  }

  function bindAllRichTextSync() {
    var form = questionForm();
    if (form) {
      form.querySelectorAll("textarea.js-rich, input.js-rich").forEach(
        bindRichTextSync
      );
    }
    bindRichTextSync(document.getElementById("question-stem"));
    bindRichTextSync(document.getElementById("question-solution"));
    ["a", "b", "c", "d", "e"].forEach(function (k) {
      bindRichTextSync(document.getElementById("option-" + k + "-text"));
    });
  }

  function initPreview() {
    if (!document.getElementById("question-preview")) return;
    loadScenarioCatalog();
    loadPreviewSeed();
    loadFormBootstrap();
    hydrateFormFromBootstrap();
    captureServerFieldValues();
    seedPreviewElements();
    bindAllRichTextSync();

    var form = questionForm();
    if (form) {
      form.addEventListener("input", function (ev) {
        if (ev.target) markPreviewDirty(ev.target);
        sync();
      });
      form.addEventListener("change", function (ev) {
        if (ev.target) markPreviewDirty(ev.target);
        sync();
      });
    }
    document.addEventListener(
      "input",
      function (ev) {
        var target = ev.target;
        if (!target || !target.closest) return;
        if (!target.closest("#question-form")) return;
        markPreviewDirty(target);
        sync();
      },
      true
    );
    document.addEventListener("map-question-change", sync);
    document.addEventListener("kpss-rich-field-ready", function (ev) {
      if (ev.detail && ev.detail.el) bindRichTextSync(ev.detail.el);
    });

    var file = document.getElementById("q-image");
    if (file) {
      file.addEventListener("change", function () {
        setTimeout(sync, 50);
      });
    }

    var previewImg = document.getElementById("q-image-preview-img");
    if (previewImg) {
      var obs = new MutationObserver(sync);
      obs.observe(previewImg, { attributes: true, attributeFilter: ["src"] });
    }

    var solutionInput = document.getElementById("solution-image-input");
    if (solutionInput) {
      solutionInput.addEventListener("change", function () {
        var file = solutionInput.files && solutionInput.files[0];
        var box = document.getElementById("solution-image-preview");
        var img = document.getElementById("solution-image-preview-img");
        if (!file || !box || !img) {
          sync();
          return;
        }
        var reader = new FileReader();
        reader.onload = function () {
          img.src = String(reader.result || "");
          box.hidden = false;
          sync();
        };
        reader.readAsDataURL(file);
      });
    }
    var keepSolutionImage = document.querySelector('[name="keep_solution_image"]');
    if (keepSolutionImage) {
      keepSolutionImage.addEventListener("change", sync);
    }

    var stemInput = document.getElementById("stem-image-input");
    if (stemInput) {
      stemInput.addEventListener("change", function () {
        var file = stemInput.files && stemInput.files[0];
        var box = document.getElementById("stem-image-preview-new");
        var img = document.getElementById("stem-image-preview-new-img");
        if (!file || !box || !img) {
          sync();
          return;
        }
        var reader = new FileReader();
        reader.onload = function () {
          img.src = String(reader.result || "");
          box.hidden = false;
          sync();
        };
        reader.readAsDataURL(file);
      });
    }
    var keepStemImage = document.querySelector('[name="keep_image"]');
    if (keepStemImage) {
      keepStemImage.addEventListener("change", sync);
    }
    document.querySelectorAll('[name="stem_image_position"]').forEach(function (el) {
      el.addEventListener("change", sync);
    });

    if (window.KpssMathRender) {
      renderInitialPreview();
    } else {
      window.addEventListener("load", renderInitialPreview);
    }
  }

  window.KpssQuestionPreview = {
    sync: sync,
    hydrateFormFromBootstrap: hydrateFormFromBootstrap,
    reloadBootstrap: loadFormBootstrap,
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initPreview);
  } else {
    initPreview();
  }
})();
