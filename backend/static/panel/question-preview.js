/**
 * Soru formu → sağdaki telefon önizlemesi (sınav formatı, canlı).
 */
(function () {
  var MAP_PLACEHOLDER = "[HARITA]";

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

  function currentImageSrc() {
    if (
      window.KpssMapQuestionEditor &&
      window.KpssMapQuestionEditor.isEnabled()
    ) {
      return window.KpssMapQuestionEditor.previewImageSrc();
    }

    var clear = document.querySelector('[name="clear_image"]');
    if (clear && clear.checked) return "";

    var box = document.getElementById("q-image-preview");
    var fresh = document.getElementById("q-image-preview-img");
    if (box && !box.hidden && fresh && fresh.getAttribute("src")) {
      return fresh.src;
    }

    var existing = document.querySelector(
      ".media-preview img[src]:not(#q-image-preview-img)"
    );
    if (existing && existing.getAttribute("src")) return existing.src;
    return "";
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

    if (imgEl) {
      if (src && !rendered.inline) {
        imgEl.src = src;
        imgEl.classList.add("is-on");
      } else {
        imgEl.removeAttribute("src");
        imgEl.classList.remove("is-on");
      }
    }

    syncFigureSvg(svgEl, currentFigureSvg());

    var correct = val("correct_option") || "A";
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
    if (window.KpssOptionTable) {
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
        previewHead: document.getElementById("pv-opt-col-head"),
        formHead: document.getElementById("option-table-head"),
        optsRoot: document.querySelector("#question-preview .quiz-mock-opts"),
        emptyHtml: function (index) {
          return "Şık " + filled[index].k;
        },
        plainHtml: function (t) {
          var formatted = formatPlain(t);
          return window.KpssMathRender
            ? window.KpssMathRender.plainInline(formatted)
            : escapeText(formatted);
        },
      });
    }
    filled.forEach(function (item) {
      if (item.t) item.text.classList.remove("is-empty");
      else {
        item.text.textContent = "Şık " + item.k;
        item.text.classList.add("is-empty");
      }
      item.row.classList.toggle("is-correct", correct === item.k);
    });

    var sol = val("solution");
    if (solWrap && solBody) {
      if (sol) {
        solBody.innerHTML = window.KpssMathRender
          ? window.KpssMathRender.examDocumentHtml(sol)
          : stemToHtml(sol);
        solWrap.classList.add("is-on");
      } else {
        solBody.textContent = "";
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

    sync();
    window.KpssQuestionPreview = { sync: sync };
  });
})();
