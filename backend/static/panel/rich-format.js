/**
 * Textarea / input üzerinde seçili metni **kalın** / *italik* / __altı çizili__ yapar.
 * Yapıştırma: HTML paragraf/madde yapısını ve \\(...\\) LaTeX'i korur.
 */
(function () {
  function normalizePasteText(text) {
    if (window.KpssMathRender && window.KpssMathRender.normalizeLatex) {
      return window.KpssMathRender.normalizeLatex(text);
    }
    return String(text || "")
      .replace(/\\\[([\s\S]+?)\\\]/g, function (_, body) {
        return "$$" + body.trim() + "$$";
      })
      .replace(/\\\(([\s\S]+?)\\\)/g, function (_, body) {
        return "$" + body.trim() + "$";
      });
  }

  function styleOf(node) {
    try {
      return (node.getAttribute && (node.getAttribute("style") || "")) || "";
    } catch (e) {
      return "";
    }
  }

  function wrapMarkdown(text, bold, italic, underline) {
    var core = String(text || "").trim();
    if (!core) return "";
    if (bold && italic) core = "***" + core + "***";
    else if (bold) core = "**" + core + "**";
    else if (italic) core = "*" + core + "*";
    if (underline) core = "__" + core + "__";
    return core;
  }

  function wrapColor(text, color) {
    var core = String(text || "").trim();
    if (!core || !color) return core;
    return "{" + color + "}" + core + "{/" + color + "}";
  }

  function parseTextColor(style) {
    var s = String(style || "").toLowerCase();
    if (!s) return "";
    var m = s.match(/(?:^|[;\s])color\s*:\s*([^;]+)/);
    var raw = m ? m[1].trim() : s.trim();
    if (/^(#22c55e|#16a34a|#4ade80|#34d399|green|lime|yeşil|yesil)\b/.test(raw)) {
      return "green";
    }
    if (/^(#ef4444|#dc2626|#f87171|#fb7185|red|kırmızı|kirmizi)\b/.test(raw)) {
      return "red";
    }
    if (/^(#3b82f6|#2563eb|#60a5fa|#38bdf8|blue|mavi)\b/.test(raw)) {
      return "blue";
    }
    return "";
  }

  function nodeText(node) {
    if (!node) return "";
    if (node.nodeType === Node.TEXT_NODE) return node.textContent || "";
    var tag = (node.nodeName || "").toUpperCase();
    if (tag === "BR") return "\n";
    if (tag === "HR") return "\n\n";
    if (tag === "H1" || tag === "H2" || tag === "H3" || tag === "H4") {
      var heading = Array.prototype.map
        .call(node.childNodes, nodeText)
        .join("")
        .replace(/\n+/g, " ")
        .trim();
      if (!heading) return "";
      if (!/^\*\*/.test(heading)) heading = "**" + heading + "**";
      return heading + "\n\n";
    }
    if (tag === "P" || tag === "DIV" || tag === "SECTION" || tag === "BLOCKQUOTE") {
      var inner = Array.prototype.map
        .call(node.childNodes, nodeText)
        .join("")
        .replace(/\n+$/g, "");
      return inner + "\n\n";
    }
    if (tag === "LI") {
      return (
        "- " +
        Array.prototype.map
          .call(node.childNodes, nodeText)
          .join("")
          .trim() +
        "\n"
      );
    }
    if (tag === "UL" || tag === "OL") {
      return Array.prototype.map.call(node.childNodes, nodeText).join("");
    }

    var child = Array.prototype.map.call(node.childNodes, nodeText).join("");
    var style = styleOf(node).toLowerCase();
    var cls = ((node.getAttribute && node.getAttribute("class")) || "").toLowerCase();
    var bold =
      tag === "STRONG" ||
      tag === "B" ||
      /font-weight\s*:\s*(bold|[6-9]00)/.test(style) ||
      /\b(bold|font-bold|font-semibold|fw-bold|fw-semibold)\b/.test(cls);
    var italic =
      tag === "EM" ||
      tag === "I" ||
      /font-style\s*:\s*italic/.test(style) ||
      /\b(italic|font-italic)\b/.test(cls);
    var underline =
      tag === "U" ||
      /text-decoration\s*:[^;]*underline/.test(style) ||
      /\b(underline|font-underline)\b/.test(cls);
    var color = parseTextColor(style);

    var inner = child;
    if (bold || italic || underline) {
      inner = wrapMarkdown(child, bold, italic, underline);
    }
    if (color) {
      return wrapColor(inner, color);
    }
    return inner;
  }

  function wrapTex(tex, display) {
    var body = String(tex || "").trim();
    if (!body) return "";
    return display ? "$$" + body + "$$" : "$" + body + "$";
  }

  function texFromKatexNode(node) {
    if (!node || !node.querySelector) return "";
    var ann = node.querySelector('annotation[encoding="application/x-tex"]');
    if (ann && ann.textContent) return ann.textContent.trim();
    var attr =
      node.getAttribute("data-latex") ||
      node.getAttribute("data-tex") ||
      node.getAttribute("aria-label");
    return (attr || "").trim();
  }

  function replaceClipboardMath(root) {
    var displays = root.querySelectorAll(".katex-display, .MathJax_Display");
    Array.prototype.forEach.call(displays, function (node) {
      var tex = texFromKatexNode(node);
      if (!tex) return;
      node.parentNode.replaceChild(root.ownerDocument.createTextNode(wrapTex(tex, true)), node);
    });
    var inlines = root.querySelectorAll(".katex, .MathJax, math");
    Array.prototype.forEach.call(inlines, function (node) {
      if (!node.parentNode) return;
      var tex = texFromKatexNode(node);
      if (!tex) return;
      node.parentNode.replaceChild(root.ownerDocument.createTextNode(wrapTex(tex, false)), node);
    });
  }

  function latexScore(text) {
    var src = String(text || "");
    var dollars = (src.match(/\$/g) || []).length;
    var commands = (src.match(/\\(frac|sqrt|circ|cdot|left|right|text)/g) || []).length;
    return dollars + commands * 2;
  }

  function htmlClipboardToText(html) {
    try {
      var doc = new DOMParser().parseFromString(html, "text/html");
      var body = doc.body;
      if (!body) return "";
      replaceClipboardMath(body);
      var text = nodeText(body)
        .replace(/\u00a0/g, " ")
        .replace(/[ \t]+\n/g, "\n")
        .replace(/\n{3,}/g, "\n\n")
        .trim();
      return normalizePasteText(text);
    } catch (e) {
      return "";
    }
  }

  function structureScore(text) {
    var src = String(text || "");
    var bolds = (src.match(/\*\*/g) || []).length;
    var breaks = (src.match(/\n/g) || []).length;
    var bullets = (src.match(/^\s*[-•]/gm) || []).length;
    return bolds * 3 + breaks + bullets * 2;
  }

  function choosePasteText(plain, html) {
    var fromPlain = normalizePasteText(plain || "");
    var fromHtml = html ? htmlClipboardToText(html) : "";
    if (!fromHtml) return fromPlain;
    if (!fromPlain) return fromHtml;
    if (structureScore(fromHtml) > structureScore(fromPlain)) {
      return fromHtml;
    }
    var plainHas =
      window.KpssMathRender && window.KpssMathRender.hasLatex
        ? window.KpssMathRender.hasLatex(fromPlain)
        : /\$|\\frac|\\sqrt|\\\(/.test(fromPlain);
    var htmlHas =
      window.KpssMathRender && window.KpssMathRender.hasLatex
        ? window.KpssMathRender.hasLatex(fromHtml)
        : /\$|\\frac|\\sqrt|\\\(/.test(fromHtml);
    if (plainHas && (!htmlHas || latexScore(fromPlain) >= latexScore(fromHtml))) {
      return fromPlain;
    }
    return fromHtml || fromPlain;
  }

  function insertAtCursor(el, text) {
    var start = el.selectionStart != null ? el.selectionStart : 0;
    var end = el.selectionEnd != null ? el.selectionEnd : 0;
    var value = el.value || "";
    el.value = value.slice(0, start) + text + value.slice(end);
    var pos = start + text.length;
    el.focus();
    el.setSelectionRange(pos, pos);
    el.dispatchEvent(new Event("input", { bubbles: true }));
  }

  function bindPaste(el) {
    if (el.dataset.richPaste) return;
    el.dataset.richPaste = "1";
    el.addEventListener("paste", function (e) {
      var clip = e.clipboardData;
      if (!clip) return;
      var html = clip.getData("text/html");
      var plain = clip.getData("text/plain") || "";
      var converted = choosePasteText(plain, html);
      converted = window.KpssMathRender && window.KpssMathRender.restoreCollapsedBreaks
        ? window.KpssMathRender.restoreCollapsedBreaks(converted)
        : converted;
      if (!converted) return;
      e.preventDefault();
      insertAtCursor(el, converted);
    });
  }

  function wrapSelection(el, open, close) {
    const start = el.selectionStart ?? 0;
    const end = el.selectionEnd ?? 0;
    const value = el.value;
    const selected = value.slice(start, end);

    // Zaten sarılıysa kaldır
    if (
      selected.startsWith(open) &&
      selected.endsWith(close) &&
      selected.length >= open.length + close.length
    ) {
      const inner = selected.slice(open.length, selected.length - close.length);
      el.value = value.slice(0, start) + inner + value.slice(end);
      el.focus();
      el.setSelectionRange(start, start + inner.length);
      el.dispatchEvent(new Event("input", { bubbles: true }));
      return;
    }

    // Dışarıdan sarılı mı?
    const before = value.slice(Math.max(0, start - open.length), start);
    const after = value.slice(end, end + close.length);
    if (before === open && after === close) {
      el.value =
        value.slice(0, start - open.length) +
        selected +
        value.slice(end + close.length);
      el.focus();
      el.setSelectionRange(start - open.length, end - open.length);
      el.dispatchEvent(new Event("input", { bubbles: true }));
      return;
    }

    const insert = selected.length ? selected : "metin";
    el.value = value.slice(0, start) + open + insert + close + value.slice(end);
    el.focus();
    if (selected.length) {
      el.setSelectionRange(start, start + open.length + insert.length + close.length);
    } else {
      el.setSelectionRange(start + open.length, start + open.length + insert.length);
    }
    el.dispatchEvent(new Event("input", { bubbles: true }));
  }

  function applyFormat(el, fmt) {
    if (fmt === "bold") wrapSelection(el, "**", "**");
    if (fmt === "italic") wrapSelection(el, "*", "*");
    if (fmt === "underline") wrapSelection(el, "__", "__");
    if (fmt === "green") wrapSelection(el, "{green}", "{/green}");
    if (fmt === "red") wrapSelection(el, "{red}", "{/red}");
    if (fmt === "blue") wrapSelection(el, "{blue}", "{/blue}");
  }

  function buildToolbar(el) {
    if (el.dataset.richReady) return;
    el.dataset.richReady = "1";

    const wrap = document.createElement("div");
    wrap.className = "rich-field";
    el.parentNode.insertBefore(wrap, el);

    const bar = document.createElement("div");
    bar.className = "rich-toolbar";
    bar.innerHTML =
      '<button type="button" class="rich-btn" data-fmt="bold" title="Kalın (Ctrl+B)"><strong>K</strong></button>' +
      '<button type="button" class="rich-btn" data-fmt="italic" title="İtalik (Ctrl+I)"><em>I</em></button>' +
      '<button type="button" class="rich-btn" data-fmt="underline" title="Altı çizili (Ctrl+U)"><span class="rich-u">A</span></button>' +
      '<span class="rich-sep" aria-hidden="true"></span>' +
      '<button type="button" class="rich-btn rich-btn-color rich-btn-green" data-fmt="green" title="Yeşil">G</button>' +
      '<button type="button" class="rich-btn rich-btn-color rich-btn-red" data-fmt="red" title="Kırmızı">R</button>' +
      '<button type="button" class="rich-btn rich-btn-color rich-btn-blue" data-fmt="blue" title="Mavi">M</button>' +
      '<span class="rich-hint">Seç → Kalın / İtalik / Altı çizili / Renk</span>';

    wrap.appendChild(bar);
    wrap.appendChild(el);
    bindPaste(el);

    bar.addEventListener("mousedown", function (e) {
      // Odak kaybını engelle (seçim bozulmasın)
      if (e.target.closest("[data-fmt]")) e.preventDefault();
    });

    bar.addEventListener("click", function (e) {
      const btn = e.target.closest("[data-fmt]");
      if (!btn) return;
      applyFormat(el, btn.getAttribute("data-fmt"));
    });

    el.addEventListener("keydown", function (e) {
      if (!(e.ctrlKey || e.metaKey)) return;
      const key = e.key.toLowerCase();
      if (key === "b") {
        e.preventDefault();
        applyFormat(el, "bold");
      } else if (key === "i") {
        e.preventDefault();
        applyFormat(el, "italic");
      } else if (key === "u") {
        e.preventDefault();
        applyFormat(el, "underline");
      }
    });
  }

  document.addEventListener("DOMContentLoaded", function () {
    document.querySelectorAll("textarea.js-rich, input.js-rich").forEach(buildToolbar);
  });
})();
