/**
 * Görsel şık UI — checkbox, önizleme, OCR data URL doldurma.
 */
(function () {
  var PLACEHOLDER = "Görsel şık";

  function formEl() {
    return document.getElementById("question-form");
  }

  function visualToggle() {
    return document.getElementById("options-are-images");
  }

  function storedOptionImageSrc(key) {
    var hidden = document.getElementById("option-" + key + "-image-data");
    if (hidden && (hidden.value || "").trim()) {
      return hidden.value.trim();
    }
    var img = document.getElementById("option-" + key + "-preview");
    if (!img) return "";
    var src = (img.getAttribute("src") || img.currentSrc || img.src || "").trim();
    if (!src || src === window.location.href) return "";
    return src;
  }

  function hasStoredOptionImages() {
    return ["a", "b", "c", "d", "e"].some(function (k) {
      return !!storedOptionImageSrc(k);
    });
  }

  function bootstrapStoredVisualOptions() {
    var toggle = visualToggle();
    if (!toggle) return false;
    var any = false;
    ["a", "b", "c", "d", "e"].forEach(function (k) {
      var src = storedOptionImageSrc(k);
      if (!src) return;
      any = true;
      var img = document.getElementById("option-" + k + "-preview");
      if (img) {
        if (!img.getAttribute("src")) img.setAttribute("src", src);
        img.hidden = false;
      }
    });
    if (any && !toggle.checked) {
      toggle.checked = true;
    }
    if (any) {
      applyVisualModeClasses();
    }
    return any;
  }

  function applyVisualModeClasses() {
    var form = formEl();
    var toggle = visualToggle();
    if (!form || !toggle) return;
    form.classList.toggle("is-visual-options", !!toggle.checked);
    if (toggle.checked) {
      ["a", "b", "c", "d", "e"].forEach(function (k) {
        var field = document.getElementById("option-" + k + "-text");
        if (field && !(field.value || "").trim()) {
          field.value = PLACEHOLDER;
          field.dispatchEvent(new Event("input", { bubbles: true }));
        }
      });
    }
  }

  function syncVisualMode() {
    applyVisualModeClasses();
    if (window.KpssQuestionPreview) window.KpssQuestionPreview.sync();
  }

  function setPreview(letter, src) {
    var img = document.getElementById("option-" + letter.toLowerCase() + "-preview");
    if (!img) return;
    if (src) {
      img.src = src;
      img.hidden = false;
    } else {
      img.removeAttribute("src");
      img.hidden = true;
    }
  }

  function dataUrlToFile(dataUrl, filename) {
    return fetch(dataUrl)
      .then(function (res) {
        return res.blob();
      })
      .then(function (blob) {
        return new File([blob], filename, {
          type: blob.type || "image/png",
        });
      });
  }

  function assignFileInput(input, file) {
    if (!input || !file || typeof DataTransfer === "undefined") return;
    var dt = new DataTransfer();
    dt.items.add(file);
    input.files = dt.files;
  }

  function clearPendingOptionUploads() {
    ["a", "b", "c", "d", "e"].forEach(function (k) {
      var input = document.getElementById("option-" + k + "-image");
      if (input) input.value = "";
      var hidden = document.getElementById("option-" + k + "-image-data");
      if (hidden) hidden.value = "";
      var img = document.getElementById("option-" + k + "-preview");
      if (img && img.getAttribute("src") && img.src.indexOf("data:") === 0) {
        setPreview(k.toUpperCase(), "");
      }
    });
  }

  function applyOcrVisualOptions(data) {
    var visual =
      !!(data && (data.optionsVisual || data.options_are_images));
    var urls =
      (data && (data.optionImageDataUrls || data.option_image_data_urls)) || {};
    var toggle = visualToggle();
    if (!toggle) return Promise.resolve();

    if (!visual || !Object.keys(urls).length) {
      toggle.checked = false;
      clearPendingOptionUploads();
      syncVisualMode();
      return Promise.resolve();
    }

    toggle.checked = true;
    var form = formEl();
    if (form) form.classList.add("is-visual-options");

    var tasks = ["A", "B", "C", "D", "E"].map(function (letter) {
      var url = urls[letter];
      if (!url) return Promise.resolve();
      var key = letter.toLowerCase();
      var text = document.getElementById("option-" + key + "-text");
      if (text) {
        text.value = PLACEHOLDER;
      }
      var hidden = document.getElementById("option-" + key + "-image-data");
      if (hidden) hidden.value = url;
      setPreview(letter, url);
      var input = document.getElementById("option-" + key + "-image");
      return dataUrlToFile(url, "option_" + letter + ".png").then(function (file) {
        assignFileInput(input, file);
        var clear = document.querySelector(
          '[name="clear_option_' + key + '_image"]'
        );
        if (clear) clear.checked = false;
      });
    });
    return Promise.all(tasks).then(function () {
      if (window.KpssQuestionPreview) window.KpssQuestionPreview.sync();
    });
  }

  function bindInputs() {
    var toggle = visualToggle();
    if (toggle) {
      toggle.addEventListener("change", syncVisualMode);
    }
    document.querySelectorAll(".js-option-image-input").forEach(function (input) {
      input.addEventListener("change", function () {
        var letter = (input.name || "").replace("option_", "").replace("_image", "");
        var file = input.files && input.files[0];
        var hidden = document.getElementById("option-" + letter + "-image-data");
        if (hidden) hidden.value = "";
        if (!file) {
          setPreview(letter.toUpperCase(), "");
          return;
        }
        var reader = new FileReader();
        reader.onload = function () {
          setPreview(letter.toUpperCase(), String(reader.result || ""));
          if (window.KpssQuestionPreview) window.KpssQuestionPreview.sync();
        };
        reader.readAsDataURL(file);
        var toggleEl = visualToggle();
        if (toggleEl && !toggleEl.checked) {
          toggleEl.checked = true;
          syncVisualMode();
        }
      });
    });
    document.querySelectorAll(".js-option-clear").forEach(function (cb) {
      cb.addEventListener("change", function () {
        if (!cb.checked) return;
        var name = cb.getAttribute("name") || "";
        var letter = name
          .replace("clear_option_", "")
          .replace("_image", "");
        var input = document.getElementById("option-" + letter + "-image");
        if (input) input.value = "";
        var hidden = document.getElementById("option-" + letter + "-image-data");
        if (hidden) hidden.value = "";
        setPreview(letter.toUpperCase(), "");
        if (window.KpssQuestionPreview) window.KpssQuestionPreview.sync();
      });
    });
    document.querySelectorAll('[id^="option-"][id$="-preview"]').forEach(function (img) {
      img.addEventListener("load", function () {
        if (window.KpssQuestionPreview) window.KpssQuestionPreview.sync();
      });
      img.addEventListener("error", function () {
        if (window.KpssQuestionPreview) window.KpssQuestionPreview.sync();
      });
    });
    bootstrapStoredVisualOptions();
    syncVisualMode();
    if (hasStoredOptionImages()) {
      window.setTimeout(function () {
        if (window.KpssQuestionPreview) window.KpssQuestionPreview.sync();
      }, 0);
    }
  }

  window.KpssQuestionOptions = {
    syncVisualMode: syncVisualMode,
    applyOcrVisualOptions: applyOcrVisualOptions,
    optionImageSrc: function (letter) {
      return storedOptionImageSrc(String(letter).toLowerCase());
    },
    isVisual: function () {
      var toggle = visualToggle();
      if (toggle && toggle.checked) return true;
      return hasStoredOptionImages();
    },
    hasStoredOptionImages: hasStoredOptionImages,
  };

  document.addEventListener("DOMContentLoaded", bindInputs);
})();
