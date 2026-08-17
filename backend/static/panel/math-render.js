/**
 * Markdown + LaTeX ($...$ / $$...$$) → HTML (KaTeX).
 */
(function (global) {
  function normalizeLatex(text) {
    return String(text || "")
      .replace(/\\\[([\s\S]+?)\\\]/g, function (_, body) {
        return "$$" + body.trim() + "$$";
      })
      .replace(/\\\(([\s\S]+?)\\\)/g, function (_, body) {
        return "$" + body.trim() + "$";
      });
  }

  function hasLatex(text) {
    return /\$\$|\$[^$\n]+\$|\\\(|\\\[|\\frac|\\sqrt|\\circ|\\cdot|\\left|\\right/.test(
      String(text || "")
    );
  }

  function collapseSoftLines(chunk) {
    return String(chunk || "")
      .split(/\n\s*\n+/)
      .map(function (para) {
        return para
          .replace(/[ \t]*\n[ \t]*/g, " ")
          .replace(/[ \t]{2,}/g, " ")
          .trim();
      })
      .filter(Boolean)
      .join("\n\n");
  }

  function examFormat(text) {
    if (!text) return "";
    var src = String(text).replace(/\r\n/g, "\n").replace(/\r/g, "\n");
    var parts = [];
    var re = /\$\$[\s\S]+?\$\$/g;
    var last = 0;
    var m;
    while ((m = re.exec(src)) !== null) {
      var before = collapseSoftLines(src.slice(last, m.index));
      if (before) parts.push(before);
      parts.push(m[0].trim());
      last = m.index + m[0].length;
    }
    var tail = collapseSoftLines(src.slice(last));
    if (tail) parts.push(tail);
    return parts.join("\n\n");
  }

  function escapeHtml(text) {
    return String(text)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
  }

  /** Renk etiketleri olmadan kalın / italik / altı çizili. */
  function mdMarks(text) {
    return escapeHtml(text)
      .replace(/__\*\*\*(.+?)\*\*\*__/g, "<u><strong><em>$1</em></strong></u>")
      .replace(/\*\*__(.+?)__\*\*/g, "<strong><u>$1</u></strong>")
      .replace(/__\*\*(.+?)\*\*__/g, "<u><strong>$1</strong></u>")
      .replace(/\*\*\*(.+?)\*\*\*/g, "<strong><em>$1</em></strong>")
      .replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
      .replace(/__(.+?)__/g, "<u>$1</u>")
      .replace(/\*(.+?)\*/g, "<em>$1</em>");
  }

  /**
   * Renk + markdown.
   * Renkli kelime, çevresindeki kalın/altı çiziliyi bozmaz:
   * __cümle {green}kelime{/green} devam__ → tümü altı çizili, kelime yeşil.
   */
  function mdInline(text) {
    if (!text) return "";
    var src = String(text);
    var holders = [];
    // Önce renk bölgelerini yer tutucuya al; markdown tüm cümlede çalışsın.
    var protectedSrc = src.replace(
      /\{(green|red|blue)\}([\s\S]+?)\{\/\1\}/g,
      function (_, color, inner) {
        var idx = holders.length;
        holders.push({
          color: color,
          html: mdInline(inner),
        });
        return "§§C" + idx + "§§";
      }
    );
    var html = mdMarks(protectedSrc);
    if (!holders.length) return html;
    return html.replace(/§§C(\d+)§§/g, function (_, idx) {
      var item = holders[Number(idx)];
      if (!item) return "";
      return (
        '<span class="rich-' + item.color + '">' + item.html + "</span>"
      );
    });
  }

  function renderMath(tex, displayMode) {
    var body = String(tex || "").trim();
    if (!body) return "";
    if (typeof global.katex === "undefined") {
      return escapeHtml(displayMode ? "$$" + body + "$$" : "$" + body + "$");
    }
    try {
      return global.katex.renderToString(body, {
        throwOnError: false,
        displayMode: !!displayMode,
        output: "html",
      });
    } catch (e) {
      return escapeHtml(displayMode ? "$$" + body + "$$" : "$" + body + "$");
    }
  }

  /** Metin içinde markdown + inline/display LaTeX. */
  function richInline(text) {
    if (!text) return "";
    var src = normalizeLatex(String(text));
    var out = "";
    var re =
      /\$\$([\s\S]+?)\$\$|\$([^$\n]+?)\$|\\\[([\s\S]+?)\\\]|\\\(([\s\S]+?)\\\)/g;
    var last = 0;
    var m;
    while ((m = re.exec(src)) !== null) {
      out += mdInline(src.slice(last, m.index));
      var tex = m[1] || m[2] || m[3] || m[4] || "";
      out += renderMath(tex, !!(m[1] || m[3]));
      last = m.index + m[0].length;
    }
    out += mdInline(src.slice(last));
    return out;
  }

  /** Şık metni — kalın/italik/altı çizili yok, yalnızca matematik. */
  function plainInline(text) {
    if (!text) return "";
    var src = normalizeLatex(String(text));
    var out = "";
    var re =
      /\$\$([\s\S]+?)\$\$|\$([^$\n]+?)\$|\\\[([\s\S]+?)\\\]|\\\(([\s\S]+?)\\\)/g;
    var last = 0;
    var m;
    while ((m = re.exec(src)) !== null) {
      out += escapeHtml(src.slice(last, m.index));
      var tex = m[1] || m[2] || m[3] || m[4] || "";
      out += renderMath(tex, !!(m[1] || m[3]));
      last = m.index + m[0].length;
    }
    out += escapeHtml(src.slice(last));
    return out;
  }

  /** Çözüm / ders metni — satır ve madde yapısını korur. */
  function documentHtml(text) {
    var src = normalizeLatex(String(text || ""))
      .replace(/\r\n/g, "\n")
      .replace(/\r/g, "\n");
    if (!src.trim()) return "";

    var lines = src.split("\n");
    var html = [];
    var inList = false;

    function closeList() {
      if (inList) {
        html.push("</ul>");
        inList = false;
      }
    }

    lines.forEach(function (line) {
      var trimmed = line.trim();
      if (!trimmed) {
        closeList();
        return;
      }

      if (/^\$\$[\s\S]+\$\$$/.test(trimmed)) {
        closeList();
        html.push(
          '<div class="math-block">' +
            renderMath(trimmed.slice(2, -2), true) +
            "</div>"
        );
        return;
      }

      var bullet = trimmed.match(/^[-•*–—]\s+(.+)/);
      if (bullet) {
        if (!inList) {
          html.push('<ul class="rich-list">');
          inList = true;
        }
        html.push("<li>" + richInline(bullet[1]) + "</li>");
        return;
      }

      closeList();
      html.push("<p>" + richInline(trimmed) + "</p>");
    });
    closeList();
    return html.join("");
  }

  /** Paragraflı soru metni (OCR — yumuşak satır birleştirme). */
  function paragraphHtml(text) {
    var clean = examFormat(text);
    if (!clean) return "";
    return clean
      .split(/\n\n+/)
      .map(function (p) {
        return "<p>" + richInline(p) + "</p>";
      })
      .join("");
  }

  global.KpssMathRender = {
    examFormat: examFormat,
    normalizeLatex: normalizeLatex,
    hasLatex: hasLatex,
    richInline: richInline,
    plainInline: plainInline,
    paragraphHtml: paragraphHtml,
    documentHtml: documentHtml,
  };
})(window);
