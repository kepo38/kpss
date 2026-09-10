(function () {
  const title = document.getElementById("ann-title");
  const body = document.getElementById("ann-body");
  const imageInput = document.getElementById("ann-image");
  const clearImage = document.getElementById("ann-clear-image");
  const pvTitle = document.getElementById("pv-ann-title");
  const pvBody = document.getElementById("pv-ann-body");
  const pvMedia = document.getElementById("pv-ann-media");
  const pvImg = document.getElementById("pv-ann-img");

  let objectUrl = null;

  function syncText() {
    if (pvTitle) {
      const t = (title && title.value.trim()) || "";
      pvTitle.textContent = t || "Başlık buraya…";
    }
    if (pvBody) {
      const b = (body && body.value.trim()) || "";
      pvBody.textContent = b || "Kısa açıklama buraya…";
      pvBody.hidden = false;
    }
  }

  function setImage(src) {
    if (!pvMedia || !pvImg) return;
    if (!src) {
      pvImg.removeAttribute("src");
      pvMedia.hidden = true;
      return;
    }
    pvImg.src = src;
    pvMedia.hidden = false;
  }

  function revoke() {
    if (objectUrl) {
      URL.revokeObjectURL(objectUrl);
      objectUrl = null;
    }
  }

  function syncImage() {
    if (clearImage && clearImage.checked) {
      revoke();
      setImage(null);
      return;
    }
    const file = imageInput && imageInput.files && imageInput.files[0];
    if (file) {
      revoke();
      objectUrl = URL.createObjectURL(file);
      setImage(objectUrl);
      return;
    }
    const existing = document.getElementById("ann-existing-thumb");
    if (existing && existing.getAttribute("src")) {
      setImage(existing.getAttribute("src"));
      return;
    }
    setImage(null);
  }

  document.querySelectorAll("[data-ann-tpl]").forEach(function (chip) {
    chip.addEventListener("click", function () {
      document.querySelectorAll("[data-ann-tpl]").forEach(function (c) {
        c.classList.remove("is-active");
      });
      chip.classList.add("is-active");
      if (title) title.value = chip.getAttribute("data-title") || "";
      if (body) body.value = chip.getAttribute("data-body") || "";
      syncText();
    });
  });

  if (title) title.addEventListener("input", syncText);
  if (body) body.addEventListener("input", syncText);
  if (imageInput) imageInput.addEventListener("change", syncImage);
  if (clearImage) clearImage.addEventListener("change", syncImage);

  syncText();
  syncImage();
})();
