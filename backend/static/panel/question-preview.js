/**
 * Soru formu → sağdaki telefon önizlemesi (sınav formatı, canlı).
 */
(function () {
  var MAP_PLACEHOLDER = "[HARITA]";
  var scenarioCatalog = {};

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
      return window.KpssMathRender.examDocumentHtml(text);
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

  function val(name) {
    var el = document.querySelector('[name="' + name + '"]');
    return el ? (el.value || "").trim() : "";
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
    var stemEl = document.getElementById("pv-stem");
    var imgEl = document.getElementById("pv-img");
    var svgEl = document.getElementById("pv-svg");
    var solWrap = document.getElementById("pv-solution");
    var solBody = document.getElementById("pv-solution-body");
    if (!stemEl) return;

    syncScenarioCard();

    var stem = val("stem");
    if (window.KpssOptionTable && window.KpssOptionTable.visibleStem) {
      stem = window.KpssOptionTable.visibleStem(stem);
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
    var filled = [];
    ["A", "B", "C", "D", "E"].forEach(function (k) {
      var row = document.getElementById("pv-opt-" + k);
      var text = document.getElementById("pv-opt-text-" + k);
      if (!row || !text) return;
      filled.push({
        k: k,
        row: row,
        text: text,
        t: val("option_" + k.toLowerCase()),
      });
    });
    var optsRoot = document.querySelector("#question-preview .quiz-mock-opts");
    var previewHead = document.getElementById("pv-opt-col-head");
    if (window.KpssOptionTable && !visualOpts) {
      window.KpssOptionTable.apply({
        stem: val("stem"),
        stemEl: document.querySelector('[name="stem"]'),
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
      } else if (visual) {
        item.text.textContent = "";
        item.text.classList.add("is-empty");
      } else if (item.t) {
        if (!window.KpssOptionTable) {
          item.text.innerHTML = window.KpssMathRender
            ? window.KpssMathRender.optionInline(item.t)
            : escapeText(formatPlain(item.t));
        }
        item.text.classList.remove("is-empty");
      } else {
        item.text.textContent = "Şık " + item.k;
        item.text.classList.add("is-empty");
      }
      item.text.classList.toggle("has-opt-img", showOptImg);
      item.row.classList.toggle("has-opt-img", showOptImg);
      item.row.classList.toggle("is-correct", correct === item.k);
    });

    var sol = val("solution");
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
        solBody.innerHTML = window.KpssMathRender
          ? (window.KpssMathRender.solutionDocumentHtml
              ? window.KpssMathRender.solutionDocumentHtml(sol)
              : window.KpssMathRender.examDocumentHtml(sol))
          : stemToHtml(sol);
      } else {
        solBody.textContent = "";
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

  document.addEventListener("DOMContentLoaded", function () {
    if (!document.getElementById("question-preview")) return;
    var form = document.querySelector("form.form");
    if (!form) return;
    loadScenarioCatalog();

    form.addEventListener("input", sync);
    form.addEventListener("change", sync);
    document.addEventListener("map-question-change", sync);

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

    sync();
    window.KpssQuestionPreview = { sync: sync };
  });
})();
