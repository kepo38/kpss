(function () {
  const title = document.getElementById("lesson-title");
  const body = document.getElementById("lesson-body");
  const imageInput = document.getElementById("lesson-image");
  const clearImage = document.getElementById("lesson-clear-image");

  const pvTitle = document.getElementById("pv-lesson-title");
  const pvBody = document.getElementById("pv-lesson-body");
  const pvImg = document.getElementById("pv-lesson-img");

  let objectUrl = null;

  function renderMarkupHtml(raw) {
    var text = String(raw || "").trim();
    if (!text) return "";
    if (window.KpssMathRender && window.KpssMathRender.documentHtml) {
      return window.KpssMathRender.documentHtml(text);
    }
    return (
      "<p>" +
      text
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/\n/g, "<br>") +
      "</p>"
    );
  }

  function bodyPreviewHtml(raw) {
    var text = String(raw || "").trim();
    if (!text) {
      return '<p class="lesson-mock-placeholder">İçerik buraya…</p>';
    }
    var html = renderMarkupHtml(text);
    return html || '<p class="lesson-mock-placeholder">İçerik buraya…</p>';
  }

  function syncText() {
    if (pvTitle) {
      const t = (title && title.value.trim()) || "";
      pvTitle.textContent = t || "Başlık buraya…";
      pvTitle.classList.toggle("is-empty", !t);
    }
    if (pvBody) {
      pvBody.innerHTML = bodyPreviewHtml(body && body.value);
    }
  }

  function setPreviewSrc(src) {
    if (!pvImg) return;
    if (!src) {
      pvImg.removeAttribute("src");
      pvImg.hidden = true;
      return;
    }
    pvImg.src = src;
    pvImg.hidden = false;
  }

  function revokeObjectUrl() {
    if (objectUrl) {
      URL.revokeObjectURL(objectUrl);
      objectUrl = null;
    }
  }

  function syncImage() {
    if (clearImage && clearImage.checked) {
      revokeObjectUrl();
      setPreviewSrc(null);
      return;
    }
    const file = imageInput && imageInput.files && imageInput.files[0];
    if (file) {
      revokeObjectUrl();
      objectUrl = URL.createObjectURL(file);
      setPreviewSrc(objectUrl);
      return;
    }
    const existing = document.getElementById("lesson-existing-thumb");
    if (existing && existing.getAttribute("src")) {
      setPreviewSrc(existing.getAttribute("src"));
      return;
    }
    setPreviewSrc(null);
  }

  if (title) title.addEventListener("input", syncText);
  if (body) body.addEventListener("input", syncText);
  if (imageInput) imageInput.addEventListener("change", syncImage);
  if (clearImage) clearImage.addEventListener("change", syncImage);

  // rich-format toolbar da textarea'yı değiştirir
  document.addEventListener("input", function (e) {
    if (e.target === body) syncText();
  });

  function boot() {
    syncText();
    syncImage();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
