/**
 * Ctrl+V ile panodaki görseli file input'a yazar ve önizleme gösterir.
 * data-paste-image attributes on .media-box:
 *   data-input, data-preview, data-preview-img, data-status (optional)
 */
(function () {
  function extFromType(type) {
    if (type === "image/jpeg") return "jpg";
    if (type === "image/webp") return "webp";
    if (type === "image/gif") return "gif";
    return "png";
  }

  function applyFile(input, previewBox, previewImg, statusEl, file) {
    const name = file.name || "yapistirilan-soru." + extFromType(file.type || "image/png");
    const typed = new File([file], name, {
      type: file.type || "image/png",
      lastModified: Date.now(),
    });
    const dt = new DataTransfer();
    dt.items.add(typed);
    input.files = dt.files;
    input.dispatchEvent(new Event("change", { bubbles: true }));

    if (previewImg && previewBox) {
      previewImg.src = URL.createObjectURL(typed);
      previewBox.hidden = false;
    }
    if (statusEl) {
      statusEl.hidden = false;
      statusEl.textContent = "Panodan görsel alındı · " + name;
    }
    const box = input.closest(".media-box");
    if (box) {
      box.classList.add("is-pasted");
      setTimeout(function () {
        box.classList.remove("is-pasted");
      }, 900);
    }
  }

  function imageFromClipboard(clipboardData) {
    if (!clipboardData) return null;
    const items = clipboardData.items;
    if (items) {
      for (let i = 0; i < items.length; i++) {
        if (items[i].type && items[i].type.indexOf("image/") === 0) {
          return items[i].getAsFile();
        }
      }
    }
    const files = clipboardData.files;
    if (files && files.length) {
      for (let i = 0; i < files.length; i++) {
        if (files[i].type && files[i].type.indexOf("image/") === 0) {
          return files[i];
        }
      }
    }
    return null;
  }

  function bindBox(box) {
    const input = document.getElementById(box.getAttribute("data-input"));
    if (!input) return;
    const previewBox = document.getElementById(box.getAttribute("data-preview"));
    const previewImg = document.getElementById(box.getAttribute("data-preview-img"));
    const statusEl = document.getElementById(box.getAttribute("data-status"));

    input.addEventListener("change", function () {
      const file = input.files && input.files[0];
      if (!file) {
        if (previewBox) previewBox.hidden = true;
        if (statusEl) statusEl.hidden = true;
        return;
      }
      if (previewImg && previewBox) {
        previewImg.src = URL.createObjectURL(file);
        previewBox.hidden = false;
      }
    });

    box.addEventListener("paste", function (e) {
      const file = imageFromClipboard(e.clipboardData);
      if (!file) return;
      e.preventDefault();
      applyFile(input, previewBox, previewImg, statusEl, file);
    });

    // Sayfa genelinde Ctrl+V (metin alanına yazı yapıştırmayı bozmaz; sadece görsel varsa)
    document.addEventListener("paste", function (e) {
      const file = imageFromClipboard(e.clipboardData);
      if (!file) return;
      e.preventDefault();
      applyFile(input, previewBox, previewImg, statusEl, file);
    });
  }

  document.addEventListener("DOMContentLoaded", function () {
    document.querySelectorAll("[data-paste-image]").forEach(bindBox);
  });
})();
