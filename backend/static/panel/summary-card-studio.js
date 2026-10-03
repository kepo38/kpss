(function () {
  const kindLabels = {
    formula: "Formül",
    tip: "Püf nokta",
    osym: "ÖSYM buradan sorar",
  };

  const subject = document.getElementById("sc-subject");
  const topic = document.getElementById("sc-topic");
  const kind = document.getElementById("sc-kind");
  const title = document.getElementById("sc-title");
  const body = document.getElementById("sc-body");
  const imageInput = document.getElementById("sc-image");
  const clearImage = document.getElementById("sc-clear-image");

  const pvTopic = document.getElementById("pv-sc-topic");
  const pvKind = document.getElementById("pv-sc-kind");
  const pvTitle = document.getElementById("pv-sc-title");
  const pvBody = document.getElementById("pv-sc-body");
  const pvImg = document.getElementById("pv-sc-img");

  let objectUrl = null;

  function topicLabel() {
    if (!topic || !topic.value) return "Konu";
    const opt = topic.options[topic.selectedIndex];
    return opt ? opt.textContent.trim() : "Konu";
  }

  const SAMPLE_BODY =
    "**Zincir kuralı:** dış fonksiyonun türevi × iç fonksiyonun türevi.\n\n" +
    "Örnek: $f(g(x))$ için {green}ÖSYM{/green} genelde bileşke sorar.\n\n" +
    "__Unutmayın:__ önce iç, sonra dış türev alınır.";

  function renderMarkupHtml(raw) {
    var text = String(raw || "").trim();
    if (!text) return "";
    if (window.KpssMathRender && window.KpssMathRender.documentHtml) {
      return window.KpssMathRender.documentHtml(text);
    }
    return "<p>" + text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") + "</p>";
  }

  function bodyPreviewHtml(raw) {
    var text = String(raw || "").trim();
    if (!text) {
      return '<p class="sc-mock-placeholder">Özet metni buraya…</p>';
    }
    var html = renderMarkupHtml(text);
    return html || '<p class="sc-mock-placeholder">Özet metni buraya…</p>';
  }

  function renderFormatExamples() {
    document.querySelectorAll(".sc-format-demo[data-markup]").forEach(function (cell) {
      var markup = cell.getAttribute("data-markup") || "";
      cell.innerHTML = renderMarkupHtml(markup);
    });
  }

  function bindSampleButton() {
    var btn = document.getElementById("sc-insert-sample");
    if (!btn || !body) return;
    btn.addEventListener("click", function () {
      body.value = SAMPLE_BODY;
      body.dispatchEvent(new Event("input", { bubbles: true }));
      body.focus();
    });
  }

  function syncText() {
    if (pvTopic) pvTopic.textContent = topicLabel();
    if (pvKind) {
      const k = kind ? kind.value : "tip";
      pvKind.textContent = kindLabels[k] || kindLabels.tip;
    }
    if (pvTitle) {
      const t = (title && title.value.trim()) || "";
      pvTitle.textContent = t || "Başlık buraya…";
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
    const existing = document.getElementById("sc-existing-thumb");
    if (existing && existing.getAttribute("src")) {
      setPreviewSrc(existing.getAttribute("src"));
      return;
    }
    setPreviewSrc(null);
  }

  function loadTopics(subjectId, selectedTopicId) {
    if (!topic) return;
    if (!subjectId) {
      topic.innerHTML = '<option value="">Önce ders seçin…</option>';
      syncText();
      return;
    }
    var url = "/panel/ders/" + subjectId + "/konular/";
    if (selectedTopicId) url += "?selected=" + selectedTopicId;
    fetch(url, { headers: { "HX-Request": "true" } })
      .then(function (r) {
        return r.text();
      })
      .then(function (html) {
        topic.innerHTML = html;
        syncText();
      })
      .catch(function () {
        topic.innerHTML = '<option value="">Konular yüklenemedi</option>';
        syncText();
      });
  }

  if (subject) {
    subject.addEventListener("change", function () {
      loadTopics(subject.value, "");
    });
  }
  if (topic) topic.addEventListener("change", syncText);
  if (kind) kind.addEventListener("change", syncText);
  if (title) title.addEventListener("input", syncText);
  if (body) body.addEventListener("input", syncText);
  if (imageInput) imageInput.addEventListener("change", syncImage);
  if (clearImage) clearImage.addEventListener("change", syncImage);

  function boot() {
    syncText();
    syncImage();
    renderFormatExamples();
    bindSampleButton();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
