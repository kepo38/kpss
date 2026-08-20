/**
 * Markdown + LaTeX ($...$ / $$...$$) → HTML (KaTeX).
 */
(function (global) {
  function normalizeLatex(text) {
    var src = repairLatexEscapes(String(text || ""));
    return src
      .replace(/\\\[([\s\S]+?)\\\]/g, function (_, body) {
        return "$$" + body.trim() + "$$";
      })
      .replace(/\\\(([\s\S]+?)\\\)/g, function (_, body) {
        return "$" + body.trim() + "$";
      });
  }

  /** JSON/OCR: \\frac → form-feed+rac; önizlemede geri yamala. */
  function repairLatexEscapes(text) {
    var src = String(text || "")
      .replace(/\x0crac/g, "\\frac")
      .replace(/\x08eta/g, "\\beta")
      .replace(/\x08egin/g, "\\begin")
      .replace(/\x09ext\{/g, "\\text{")
      .replace(/\x09imes/g, "\\times")
      .replace(/\x09heta/g, "\\theta")
      .replace(/\x09an/g, "\\tan")
      .replace(/\x0dight/g, "\\right")
      .replace(/\x0aeq/g, "\\neq")
      .replace(/\$rac\{/g, "$\\frac{")
      .replace(/\$sqrt\{/g, "$\\sqrt{");
    if (src.indexOf("frac") !== -1 && src.indexOf("\\frac") === -1) {
      src = src.replace(/(^|[^\\A-Za-z])frac\{/g, "$1\\frac{");
    }
    return src;
  }

  function looksLikeMath(text) {
    var t = String(text || "").trim();
    if (!t) return false;
    return /\\(?:frac|dfrac|tfrac|sqrt|cdot|times|left|right|text|overline|underline|begin|infty|pm|neq|leq|geq)\b/.test(
      t
    ) || /[\^_{}]/.test(t) || /(^|[^\\A-Za-z])frac\{/.test(t);
  }

  /** Şıkta yalnızca gerçek LaTeX varsa $...$ sarmala; "Yalnız I" düz metin kalsın. */
  function wrapBareLatex(text) {
    var src = repairLatexEscapes(String(text || "")).trim();
    if (!src) return src;
    var display = src.match(/^\$\$([\s\S]+)\$\$$/);
    if (display) {
      var inner = display[1].trim();
      return looksLikeMath(inner) ? src : inner;
    }
    var wrapped = src.match(/^\$([^$]+)\$$/);
    if (wrapped) {
      var inner = wrapped[1].trim();
      return looksLikeMath(inner) ? src : inner;
    }
    if (/\$|\\\(|\\\[/.test(src)) return src;
    if (looksLikeMath(src)) return "$" + src + "$";
    return src;
  }

  function hasLatex(text) {
    return /\$\$|\$[^$\n]+\$|\\\(|\\\[|\\frac|\\sqrt|\\circ|\\cdot|\\left|\\right|\\begin\{|\\hline/.test(
      String(text || "")
    );
  }

  /**
   * Eşleştirme oku: Gemini KaTeX / ASCII `->` → sınav `→`.
   */
  function normalizeExamArrows(text) {
    return String(text || "")
      .replace(/\$\\(?:long)?rightarrow\$/g, "→")
      .replace(/\$\\to\$/g, "→")
      .replace(/\\(?:long)?rightarrow\b/g, "→")
      .replace(/&#0*8594;|&rarr;/gi, "→")
      .replace(/[ \t]*->[ \t]*/g, " → ");
  }

  /**
   * Sohbet kopyasında yutulan Enter'ları geri koy:
   * "...aynıdır ($a^b \\equiv a$).Verilen" → satır kırılır.
   */
  function restoreCollapsedBreaks(text) {
    var src = String(text || "").replace(/\r\n/g, "\n").replace(/\r/g, "\n");
    if (!src) return src;
    var holders = [];
    src = src.replace(/\$\$[\s\S]+?\$\$|\$[^$\n]+\$/g, function (m) {
      holders.push(m);
      return "§§M" + (holders.length - 1) + "§§";
    });
    src = src.replace(/([.!?])(?!\n)(?=[A-ZÇĞİÖŞÜÂÎÛ])/g, "$1\n");
    src = src.replace(/:(?!\n)(?=[A-ZÇĞİÖŞÜÂÎÛ])/g, ":\n");
    src = src.replace(/([.!?])(?!\n)(?=\d+\.\s)/g, "$1\n");
    src = src.replace(/:(?!\n)(?=\d+\.\s)/g, ":\n");
    src = src.replace(/(?<!\n)(\d+\.\s+Adım)/g, "\n$1");
    src = src.replace(/(göre\*{0,2})(?!\n)(?=\s+(?:I|II|III|IV|V)\.)/g, "$1\n");
    var romanCount = (src.match(/\b(?:I|II|III|IV|V|VI|VII|VIII|IX|X)\.\s/g) || []).length;
    if (romanCount >= 2) {
      src = src.replace(/(?<!\n)(?=\b(?:I|II|III|IV|V|VI|VII|VIII|IX|X)\.\s)/g, "\n");
    }
    src = src.replace(/§§M(\d+)§§\s*(?=\*\*[a-zçğıöşüâîû])/g, "§§M$1§§\n");
    src = src.replace(/§§M(\d+)§§\s+(?=(?:ifadelerinden|hangileri|yukarıdakilerden))/g, "§§M$1§§\n");
    src = src.replace(/§§M(\d+)§§/g, function (_, idx) {
      return holders[Number(idx)] || "";
    });
    src = src.replace(/(\$)(?=[A-ZÇĞİÖŞÜÂÎÛ][a-zçğıöşüâîû])/g, "$1\n");
    src = src.replace(/(\$)\s*(?=\*\*[a-zçğıöşüâîû])/g, "$1\n");
    return src.replace(/\n{3,}/g, "\n\n").replace(/^\n+/, "");
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
  function collapseNestedMarks(text) {
    var src = String(text || "");
    var prev;
    do {
      prev = src;
      src = src.replace(/\*\*__\*\*([^*]+)\*\*__\*\*/g, "**__$1__**");
      src = src.replace(/__\*\*__([^_]+)__\*\*__/g, "__**$1**__");
      src = src.replace(/\*\*\s*\*\*([^*]+)\*\*\s*\*\*/g, "**$1**");
      src = src.replace(/__\s*__([^_]+)__\s*__/g, "__$1__");
      src = src.replace(/\*{4,}([^*\n]+)\*{4,}/g, "**$1**");
      src = src.replace(/_{4,}([^_\n]+)_{4,}/g, "__$1__");
    } while (src !== prev);
    return src;
  }

  /** `** metin **` / `__ metin __` gibi boşluklu işaretleri sıkılaştırır. */
  function tightenMarkdownMarkers(text) {
    var src = collapseNestedMarks(text);
    src = src.replace(/\*\*\s+([\s\S]+?)\s+\*\*/g, function (_, inner) {
      return "**" + String(inner).trim() + "**";
    });
    src = src.replace(/__\s+([\s\S]+?)\s+__/g, function (_, inner) {
      return "__" + String(inner).trim() + "__";
    });
    src = src.replace(/(?<!\*)\*\s+([\s\S]+?)\s+\*(?!\*)/g, function (_, inner) {
      return "*" + String(inner).trim() + "*";
    });
    src = src.replace(/\*\*([\s\S]+?)\s+\*\*/g, function (_, inner) {
      return "**" + String(inner).trim() + "**";
    });
    src = src.replace(/__([\s\S]+?)\s+__/g, function (_, inner) {
      return "__" + String(inner).trim() + "__";
    });
    return src;
  }

  /**
   * Flutter FormattedText.normalizeMarkup ile uyumlu ön işleme:
   * CRLF, ZWSP, tam genişlik ＊/＿, boşluklu markdown işaretleri.
   */
  function normalizeMarkup(text) {
    var src = String(text || "")
      .replace(/\r\n/g, "\n")
      .replace(/\r/g, "\n")
      .replace(/[\u200B-\u200D\uFEFF]/g, "")
      .replace(/＊/g, "*")
      .replace(/＿/g, "_");
    return tightenMarkdownMarkers(src);
  }

  function mdMarks(text) {
    var html = escapeHtml(collapseNestedMarks(text))
      .replace(/__\*\*\*(.+?)\*\*\*__/g, "<u><strong class=\"preview-bold\"><em>$1</em></strong></u>")
      .replace(/\*\*__(.+?)__\*\*/g, "<strong class=\"preview-bold\"><u>$1</u></strong>")
      .replace(/__\*\*(.+?)\*\*__/g, "<u><strong class=\"preview-bold\">$1</strong></u>")
      .replace(/\*\*\*(.+?)\*\*\*/g, "<strong class=\"preview-bold\"><em>$1</em></strong>")
      .replace(/\*\*(.+?)\*\*/g, "<strong class=\"preview-bold\">$1</strong>")
      .replace(/__(.+?)__/g, "<u>$1</u>")
      .replace(/\*(.+?)\*/g, "<em>$1</em>");
    return emphasizeSignWords(html);
  }

  function emphasizeSignWords(html) {
    return String(html || "")
      .replace(/\bnegatif\b/gi, '<span class="text-danger-vurgu">$&</span>')
      .replace(/\bpozitif\b/gi, '<span class="text-success-vurgu">$&</span>');
  }

  function restoreHolders(html, holders) {
    var out = String(html || "");
    if (!holders.length) return out;
    var guard = 0;
    while (/§§C\d+§§/.test(out) && guard++ < 40) {
      out = out.replace(/§§C(\d+)§§/g, function (_, idx) {
        var item = holders[Number(idx)];
        return item && item.html != null ? item.html : "";
      });
    }
    return out;
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
          html:
            '<span class="rich-' + color + '">' + mdInline(inner) + "</span>",
        });
        return "§§C" + idx + "§§";
      }
    );
    return restoreHolders(mdMarks(protectedSrc), holders);
  }

  function replaceHlineWithColoredRule(tex) {
    var t = String(tex || "");
    if (t.indexOf("\\hline") === -1) return t;
    t = t.replace(/\\\\\s*\\hline\s*/g, "\\\\ \\rule{5em}{0.05em} \\\\ ");
    t = t.replace(/\\hline\s*(?=\\\\|\\end)/g, "\\rule{5em}{0.05em} \\\\ ");
    return t;
  }

  function forceDisplaySizeAll(tex) {
    var t = String(tex || "").trim();
    if (!t) return t;
    t = t.replace(/\\dfrac/g, "\\frac").replace(/\\tfrac/g, "\\frac");
    t = t.replace(/\{([^{}]+)\\over\s*([^{}]+)\}/g, function (_, a, b) {
      return "\\frac{" + a.trim() + "}{" + b.trim() + "}";
    });
    var isTabular =
      /\\begin\{array\}/.test(t) ||
      /\\begin\{matrix\}/.test(t) ||
      /\\begin\{pmatrix\}/.test(t);
    if (!isTabular && !/\\displaystyle\b/.test(t)) {
      t = "\\displaystyle " + t;
    }
    return t;
  }

  function prepareTex(tex) {
    return forceDisplaySizeAll(replaceHlineWithColoredRule(String(tex || "")));
  }

  function renderMath(tex, displayMode) {
    var body = prepareTex(tex);
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
    var src = normalizeMarkup(String(text));
    src = normalizeExamArrows(normalizeLatex(src));
    var holders = [];
    src = src.replace(
      /\{(green|red|blue)\}([\s\S]+?)\{\/\1\}/g,
      function (_, color, inner) {
        var idx = holders.length;
        holders.push({
          html:
            '<span class="rich-' + color + '">' + richInline(inner) + "</span>",
        });
        return "§§C" + idx + "§§";
      }
    );
    src = src.replace(/\*\*([\s\S]+?)\*\*/g, function (_, inner) {
      var idx = holders.length;
      holders.push({
        html:
          '<strong class="preview-bold">' + richInline(inner) + "</strong>",
      });
      return "§§C" + idx + "§§";
    });
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
    return restoreHolders(out, holders);
  }

  /** Şık metni — kalın/italik/altı çizili yok, yalnızca matematik. */
  function plainInline(text) {
    if (!text) return "";
    var src = wrapBareLatex(normalizeExamArrows(normalizeLatex(String(text))));
    var out = "";
    var re =
      /\$\$([\s\S]+?)\$\$|\$([^$\n]+?)\$|\\\[([\s\S]+?)\\\]|\\\(([\s\S]+?)\\\)/g;
    var last = 0;
    var m;
    while ((m = re.exec(src)) !== null) {
      out += escapeHtml(src.slice(last, m.index));
      var tex = m[1] || m[2] || m[3] || m[4] || "";
      out += renderMath(tex, false);
      last = m.index + m[0].length;
    }
    out += escapeHtml(src.slice(last));
    return out;
  }

  /** Çözüm / ders metni — satır ve madde yapısını korur. */
  function documentHtml(text, options) {
    options = options || {};
    var examMode = !!options.examMode;
    var src = normalizeMarkup(String(text || ""));
    src = restoreCollapsedBreaks(normalizeLatex(src));
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

    var nested = false;

    function closeNested() {
      if (nested) {
        html.push("</ul>");
        nested = false;
      }
    }

    lines.forEach(function (line) {
      var trimmed = line.trim();
      if (!trimmed) {
        closeNested();
        closeList();
        return;
      }

      if (/^\$\$[\s\S]+\$\$$/.test(trimmed)) {
        closeNested();
        closeList();
        html.push(
          '<div class="math-block">' +
            renderMath(trimmed.slice(2, -2), true) +
            "</div>"
        );
        return;
      }

      if (/^(---|\*\*\*|___)$/.test(trimmed)) {
        closeNested();
        closeList();
        html.push('<hr class="preview-rule">');
        return;
      }

      if (/^[-•*◦○–—]+$/.test(trimmed)) {
        return;
      }

      var bullet = line.match(/^(\s*)(?:[-•*◦○–—]\s+)+(.+)/);
      if (bullet) {
        var deep = bullet[1].replace(/\t/g, "  ").length >= 2;
        if (!inList) {
          html.push('<ul class="rich-list">');
          inList = true;
        }
        if (deep && !nested) {
          html.push('<ul class="rich-list nested">');
          nested = true;
        }
        if (!deep) closeNested();
        html.push("<li>" + richInline(bullet[2]) + "</li>");
        return;
      }

      closeNested();
      closeList();

      var heading = trimmed.match(/^#{1,3}\s+(.+)/);
      if (heading) {
        if (examMode) {
          var title = heading[1].replace(/^\*\*|\*\*$/g, "").trim();
          html.push("<p>" + richInline("**" + title + "**") + "</p>");
        } else {
          html.push(
            '<p class="preview-heading">' + richInline(heading[1]) + "</p>"
          );
        }
        return;
      }
      var questionLike =
        /\?\s*\**$/.test(trimmed) ||
        /\b(?:ifadelerinden|hangileri|yukarıdakilerden)\b/i.test(trimmed);
      if (
        !examMode &&
        !questionLike &&
        /^\*\*[^*][\s\S]*\*\*$/.test(trimmed) &&
        trimmed.indexOf("**", 2) === trimmed.length - 2
      ) {
        html.push('<p class="preview-heading">' + richInline(trimmed) + "</p>");
        return;
      }

      html.push("<p>" + richInline(trimmed) + "</p>");
    });
    closeNested();
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

  function examDocumentHtml(text) {
    return documentHtml(text, { examMode: true });
  }

  global.KpssMathRender = {
    examFormat: examFormat,
    normalizeLatex: normalizeLatex,
    normalizeExamArrows: normalizeExamArrows,
    normalizeMarkup: normalizeMarkup,
    restoreCollapsedBreaks: restoreCollapsedBreaks,
    wrapBareLatex: wrapBareLatex,
    forceDisplaySizeAll: forceDisplaySizeAll,
    richInline: richInline,
    plainInline: plainInline,
    paragraphHtml: paragraphHtml,
    documentHtml: documentHtml,
    examDocumentHtml: examDocumentHtml,
  };
})(window);
