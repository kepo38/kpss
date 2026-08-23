/**
 * Markdown + LaTeX ($...$ / $$...$$) → HTML (KaTeX).
 */
(function (global) {
  function inlineLatexBodyToDollars(body) {
    var cleaned = String(body || "").trim();
    if (/\n/.test(cleaned)) {
      cleaned = cleaned.replace(/\s*\n\s*/g, " ").trim();
    }
    if (/\\begin\{(?:array|matrix|pmatrix|cases)\}/.test(cleaned)) {
      return "$$" + cleaned + "$$";
    }
    return "$" + cleaned + "$";
  }

  function mergeSplitInlineDollarMath(text) {
    var src = String(text || "").replace(/\r\n/g, "\n").replace(/\r/g, "\n");
    if (!src) return src;
    var display = [];
    src = src.replace(/\$\$[\s\S]+?\$\$/g, function (m) {
      display.push(m);
      return "§§D" + (display.length - 1) + "§§";
    });
    var prev;
    do {
      prev = src;
      src = src.replace(/\$([^$\n]*)\n(\s*[^$\n]+)\$/g, function (_, a, b) {
        a = String(a || "").trim();
        b = String(b || "").trim();
        return a ? "$" + a + " " + b + "$" : "$" + b + "$";
      });
    } while (src !== prev);
    src = src.replace(/§§D(\d+)§§/g, function (_, idx) {
      return display[Number(idx)] || "";
    });
    return src;
  }

  function normalizeLatex(text) {
    var src = mergeSplitInlineDollarMath(repairLatexEscapes(String(text || "")));
    return src
      .replace(/\\\[([\s\S]+?)\\\]/g, function (_, body) {
        return "$$" + body.trim() + "$$";
      })
      .replace(/\\\(([\s\S]+?)\\\)/g, function (_, body) {
        return inlineLatexBodyToDollars(body);
      });
  }

  /** JSON/OCR: \\frac → form-feed+rac; önizlemede geri yamala. */
  function repairGoogleDocsVertBars(text) {
    var src = String(text || "");
    src = src.replace(/\\\(\s*\\vert\{\}\s*\\\)/g, "|");
    src = src.replace(/\(\\vert\{\}\)/g, "|");
    src = src.replace(/\\vert\{\}([^\\]*?)\\vert\{\}/g, function (_, inner) {
      var body = String(inner || "").trim();
      return body ? "\\lvert " + body + " \\rvert" : "\\vert";
    });
    return src;
  }

  function repairLatexEscapes(text) {
    var src = repairGoogleDocsVertBars(
      String(text || "")
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
      .replace(/\$sqrt\{/g, "$\\sqrt{")
    );
    if (src.indexOf("frac") !== -1 && src.indexOf("\\frac") === -1) {
      src = src.replace(/(^|[^\\A-Za-z])frac\{/g, "$1\\frac{");
    }
    return src;
  }

  function looksLikeMath(text) {
    var t = String(text || "").trim();
    if (!t) return false;
    return /\\(?:frac|dfrac|tfrac|sqrt|cdot|times|left|right|text|overline|underline|begin|infty|pm|neq|leq|geq|displaystyle|hline)\b/.test(
      t
    ) || /[\^_{}]/.test(t) || /(^|[^\\A-Za-z])frac\{/.test(t) ||
      /[A-Za-z0-9]\s*[+\-=≠≤≥×·]\s*[A-Za-z0-9]/.test(t);
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
    // Şık: -1/2, 3/4 → $-\frac{1}{2}$ / $\frac{3}{4}$
    var slash = src.match(/^(-?)(\d+)\s*\/\s*(\d+)$/);
    if (slash) {
      return slash[1]
        ? "$-\\frac{" + slash[2] + "}{" + slash[3] + "}$"
        : "$\\frac{" + slash[2] + "}{" + slash[3] + "}$";
    }
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

  function protectMarkdownSpans(text, holders) {
    return String(text || "").replace(/\*\*[\s\S]+?\*\*|__[\s\S]+?__/g, function (m) {
      holders.push(m);
      return "§§K" + (holders.length - 1) + "§§";
    });
  }

  function restoreMarkdownSpans(text, holders) {
    return String(text || "").replace(/§§K(\d+)§§/g, function (_, idx) {
      return holders[Number(idx)] || "";
    });
  }

  /**
   * Google / sohbet kopyasında yutulan Enter'ları geri koy:
   * "...aynıdır ($a^b \\equiv a$).Verilen" → satır kırılır.
   * "GösterimKitabın" / "sayfaİlk" / "$…$3. Gün" / "göre;$120" da.
   */
  function restoreCollapsedBreaks(text) {
    var src = mergeSplitInlineDollarMath(String(text || "").replace(/\r\n/g, "\n").replace(/\r/g, "\n"));
    if (!src) return src;
    var holders = [];
    src = src.replace(
      /\$\$[\s\S]+?\$\$|\$[^$\n]+\$|\\\([\s\S]+?\\\)|\\\[[\s\S]+?\\\]/g,
      function (m) {
        holders.push(m);
        return "§§M" + (holders.length - 1) + "§§";
      }
    );
    var mdHolders = [];
    src = protectMarkdownSpans(src, mdHolders);
    src = src.replace(/\b(I|II|III|IV|V|VI|VII|VIII|IX|X)\.(?=[A-ZÇĞİÖŞÜÂÎÛ])/g, "$1. ");
    src = src.replace(/([.!?])(?!\n)(?=[A-ZÇĞİÖŞÜÂÎÛ])/g, "$1\n");
    src = src.replace(/:(?!\n)(?=[A-ZÇĞİÖŞÜÂÎÛ])/g, ":\n");
    src = src.replace(/([.!?])(?!\n)(?=\d+\.\s)/g, "$1\n");
    src = src.replace(/:(?!\n)(?=\d+\.\s)/g, ":\n");
    src = src.replace(/;(?!\n)(?=§§M|[\$A-ZÇĞİÖŞÜÂÎÛ])/g, ";\n");
    // Google mantık çözümü: A Seçeneği: / B Seçeneği:
    src = src.replace(/(?<!\n)(?=[A-E]\s+Seçeneği\s*:)/gi, "\n");
    src = src.replace(/(Adım Adım Çözüm:)(?!\n)(?=\S)/gi, "$1\n");
    src = src.replace(/(şunlardır:)(?!\n)(?=Rakamlar)/gi, "$1\n");
    src = src.replace(/(§§M\d+§§\))(?!\n)(?=[A-ZÇĞİÖŞÜ])/g, "$1\n");
    src = src.replace(/(§§M\d+§§)(?=§§M\d+§§)/g, "$1\n");
    src = src.replace(/(§§M\d+§§)(?!\n)(?=[A-ZÇĞİÖŞÜ])/g, "$1\n");
    src = src.replace(/(?<=[a-zçğıöşüâîû])(?=§§M)/g, "\n");
    src = src.replace(
      /(§§M\d+§§)(?!\n)(?=(?:Rakamlar|Kendisi|Son maddede|Elde edilen|Kağıda|Şimdi |Bulduğumuz|Görüldüğü|Now:|Çarpım ))/gi,
      "$1\n"
    );
    src = src.replace(/(?<!\n)(?=\d+\.\s+(?:Tek\/|Kağıttaki))/gi, "\n");
    src = src.replace(
      /(?<!\n)(?=[A-E]\)\s+(?:\d|[\u0027\u2019]|[A-Za-zÇĞİÖŞÜçğıöşü]))/g,
      "\n"
    );
    src = src.replace(/([❌✅])(?!\n)(?=[A-E]\))/g, "$1\n");
    src = src.replace(/(olsaydı:)(?!\n)(?=[\$\\\(])/gi, "$1\n");
    src = src.replace(
      /(?<!\n)(?=(?:Kendisi|Rakamlar(?:ı|ları|ın)\s+(?:toplamı|çarpımı|farkı|oranı))\s*:)/gi,
      "\n"
    );
    src = src.replace(/(\((?:Çift|Tek)\))(?!\n)(?=Rakamlar)/gi, "$1\n");
    src = src.replace(/(\(Tek\))(?!\n)(?=Görüldüğü)/gi, "$1\n");
    src = src.replace(/(\d+\.\s+[^:]+:)(\s*)(?=\\\(|\$|§§M)/g, "$1\n");
    src = src.replace(/([a-zçğıöşüâîû]:)(?!\n)(?=\$)/gi, "$1\n");
    src = src.replace(/(\$)(?!\n)(?=[A-ZÇĞİÖŞÜ])/g, "$1\n");
    src = src.replace(/([.!?])(?!\n)(?=\d+\s)/g, "$1\n");
    // camelCase: GösterimKitabın — 5A/pH/iPhone bölünmez (rich_text_common.py ile aynı)
    src = src.replace(
      /(?<=[a-zçğıöşüâîû]{2})(?=[A-ZÇĞİÖŞÜÂÎÛ][a-zçğıöşüâîû])/g,
      "\n"
    );
    src = restoreCollapsedPresenceTable(src);
    src = src.replace(/(?<!\n)(\d+\.\s+Adım)/g, "\n$1");
    src = src.replace(/(göre\*{0,2})(?!\n)(?=\s+(?:I|II|III|IV|V)\.)/g, "$1\n");
    // Yalnızca gerçek madde listesi: en az iki FARKLI Romen (I. + II. …).
    var romanTokens = src.match(/\b(I|II|III|IV|V|VI|VII|VIII|IX|X)\.\s/g) || [];
    var romanUnique = {};
    for (var ri = 0; ri < romanTokens.length; ri++) {
      romanUnique[romanTokens[ri].replace(/\s+$/, "")] = true;
    }
    if (Object.keys(romanUnique).length >= 2) {
      src = src.replace(/(?<!\n)(?=\b(?:I|II|III|IV|V|VI|VII|VIII|IX|X)\.\s)/g, "\n");
    }
    src = restoreMarkdownSpans(src, mdHolders);
    src = src.replace(/§§M(\d+)§§\s*(?=\*\*(?:\d+\.\s+Adım|[a-zçğıöşüâîû]))/g, "§§M$1§§\n");
    src = src.replace(/§§M(\d+)§§\s+(?=(?:ifadelerinden|hangileri|yukarıdakilerden))/g, "§§M$1§§\n");
    src = src.replace(/(§§M\d+§§)(?=\d+\.\s)/g, "$1\n");
    src = src.replace(/§§M(\d+)§§/g, function (_, idx) {
      return holders[Number(idx)] || "";
    });
    return src.replace(/\n{3,}/g, "\n\n").replace(/^\n+/, "");
  }

  var PRESENCE_CELL_RE = /^(Yok|Var)\s*\(\s*[01]\s*\)$/i;
  var ALLCAPS_NAME_RE = /^[A-ZÇĞİÖŞÜÂÎÛ]{3,}$/;
  var BIN_CODE_RE = /^[01]{3}$/;

  function restoreCollapsedPresenceTable(src) {
    if (!src) return src;
    src = src.replace(/(Öğrenci)(?=[A-ZÇĞİÖŞÜÂÎÛ]\s+Harfi)/gi, "$1\n");
    src = src.replace(/(Harfi)(?=[A-ZÇĞİÖŞÜÂÎÛ]\s+Harfi)/g, "$1\n");
    src = src.replace(/(Harfi)(?=Oluşan\s+Benzersiz)/g, "$1\n");
    src = src.replace(/(?<!\n)(?=Oluşan Benzersiz)/g, "\n");
    src = src.replace(/(\))(?=[A-ZÇĞİÖŞÜÂÎÛ]{3,})/g, ")\n");
    src = src.replace(
      /(?<=[A-ZÇĞİÖŞÜÂÎÛ]{3})(?=(?:Yok|Var)\s*\(\s*[01]\s*\))/g,
      "\n"
    );
    src = src.replace(/(\(\s*[01]\s*\))(?=(?:Yok|Var)\s*\()/g, "$1\n");
    src = src.replace(/(\(\s*[01]\s*\))(?=[01]{3}(?:[A-ZÇĞİÖŞÜÂÎÛ]|$))/g, "$1\n");
    src = src.replace(/([01]{3})(?=[A-ZÇĞİÖŞÜÂÎÛ])/g, "$1\n");
    src = src.replace(
      /(?<=[A-ZÇĞİÖŞÜÂÎÛ]{3})(?=[A-ZÇĞİÖŞÜÂÎÛ][a-zçğıöşüâîû]{3,})/g,
      "\n"
    );
    return src;
  }

  function formatPresenceTable(text) {
    var lines = String(text || "").split("\n");
    var start = -1;
    var i;
    for (i = 0; i < lines.length; i++) {
      var probe = lines[i].trim();
      if (probe === "Öğrenci" || /\bHarfi\b/.test(probe) || probe.indexOf("Benzersiz Kod") !== -1) {
        start = i;
        break;
      }
    }
    if (start < 0) return text;

    var headers = [];
    i = start;
    while (i < lines.length) {
      var s = lines[i].trim();
      if (!s) {
        i += 1;
        continue;
      }
      if (ALLCAPS_NAME_RE.test(s) || PRESENCE_CELL_RE.test(s)) break;
      var gluedHeader = s.match(/^(Öğrenci)\s*([A-ZÇĞİÖŞÜÂÎÛ]\s+Harfi)$/i);
      if (gluedHeader) {
        headers.push(gluedHeader[1], gluedHeader[2]);
        i += 1;
        continue;
      }
      headers.push(s);
      i += 1;
    }
    var letterHeaders = [];
    for (var h = 0; h < headers.length; h++) {
      var header = headers[h];
      if (header.toLocaleLowerCase("tr-TR") === "öğrenci" || /kod/i.test(header)) {
        continue;
      }
      letterHeaders.push(header.replace(/\s*Harfi\s*$/i, "").trim());
    }
    var rows = [];
    while (i < lines.length) {
      s = lines[i].trim();
      if (!s) {
        i += 1;
        continue;
      }
      if (!ALLCAPS_NAME_RE.test(s)) break;
      var name = s;
      i += 1;
      var cells = [];
      var code = "";
      while (i < lines.length) {
        var t = lines[i].trim();
        if (PRESENCE_CELL_RE.test(t)) {
          cells.push(t);
          i += 1;
        } else if (BIN_CODE_RE.test(t)) {
          code = t;
          i += 1;
          break;
        } else {
          break;
        }
      }
      if (!cells.length) break;
      rows.push({ name: name, cells: cells, code: code });
    }
    if (rows.length < 2) return text;

    var block = ["**Harf kodu:**"];
    for (var r = 0; r < rows.length; r++) {
      var bits = [];
      for (var c = 0; c < rows[r].cells.length; c++) {
        var label = c < letterHeaders.length ? letterHeaders[c] : String.fromCharCode(72 + c);
        var kind = /^var/i.test(rows[r].cells[c]) ? "var" : "yok";
        bits.push(label + " " + kind);
      }
      var tail = rows[r].code ? " → **" + rows[r].code + "**" : "";
      block.push("- **" + rows[r].name + ":** " + bits.join(", ") + tail);
    }
    var before = lines.slice(0, start).join("\n").replace(/\s+$/, "");
    var after = lines.slice(i).join("\n").replace(/^\s+/, "");
    var parts = [];
    if (before) parts.push(before);
    parts.push(block.join("\n"));
    if (after) parts.push(after);
    return parts.join("\n\n");
  }

  var OPTION_HEADER_RE =
    /^(?:[-•*◦○–—]\s+)?(?:\*\*)?([A-E])\)\s+([A-ZÇĞİÖŞÜÂÎÛİ][A-ZÇĞİÖŞÜÂÎÛİa-zçğıöşüâîû]*)\s*:?(?:\*\*)?\s*$/;
  var OPTION_SECENEGI_INLINE_RE =
    /^(?:[-•*◦○–—]\s+)?(?:\*\*)?([A-E])\s+Seçeneği\s*:\s*(.*)$/i;
  var OPTION_SECENEGI_ONLY_RE =
    /^(?:[-•*◦○–—]\s+)?(?:\*\*)?([A-E])\s+Seçeneği\s*:?\s*(?:\*\*)?\s*$/i;
  var BULLET_STRIP_RE = /^(\s*)[-•*◦○–—]\s+/;
  var KURAL_OZETI_RE = /^Kural\s+Özeti\s*:?\s*$/i;
  var RESULT_TAIL_RE = /(→\s*)(🧍\s*)?(Oturuyor|AYAKTA)\.?\s*$/i;
  var FORMULA_LIST_LABEL_RE =
    /^(Kendisi|Rakamlar(?:ı|ları|ın)\s+(?:toplamı|çarpımı|farkı(?:nın mutlak değeri)?|oranı))\s*:\s*.+/i;
  var NUMBERED_SECTION_RE = /^\d+\.\s+.+\S/;
  var NUMBERED_SECTION_TITLE_RE = /^(\d+\.\s+[^:]+:)([\s\S]*)$/;
  var STEP_HEADER_RE = /^\d+\.\s+Adım:/i;
  var CONDITION_BULLET_RE = /^(?:Rakamlar\s|Son maddede)/i;
  var ADIM_ADIM_HEADER_RE = /^(.*?Adım Adım Çözüm:)\s*(.*)$/i;

  function isOptionHeaderLine(line) {
    var s = String(line || "").trim();
    if (!s) return false;
    return (
      OPTION_HEADER_RE.test(s) ||
      OPTION_SECENEGI_ONLY_RE.test(s) ||
      OPTION_SECENEGI_INLINE_RE.test(s)
    );
  }

  function parseOptionHeader(line) {
    var s = String(line || "").trim();
    var hm = s.match(OPTION_HEADER_RE);
    if (hm) {
      return { letter: hm[1], title: hm[1] + ") " + hm[2], inline: null };
    }
    hm = s.match(OPTION_SECENEGI_INLINE_RE);
    if (hm) {
      var body = String(hm[2] || "").trim();
      return {
        letter: hm[1].toUpperCase(),
        title: hm[1].toUpperCase() + " Seçeneği",
        inline: body || null,
      };
    }
    hm = s.match(OPTION_SECENEGI_ONLY_RE);
    if (hm) {
      return {
        letter: hm[1].toUpperCase(),
        title: hm[1].toUpperCase() + " Seçeneği",
        inline: null,
      };
    }
    return null;
  }

  function stripOuterBold(text) {
    var src = String(text || "").trim();
    if (/^\*\*[^*][\s\S]*\*\*$/.test(src) && src.indexOf("**", 2) === src.length - 2) {
      return src.slice(2, -2).trim();
    }
    return src;
  }

  function emphasizeResultTail(line) {
    return String(line || "").replace(RESULT_TAIL_RE, function (_, arrow, emoji, word) {
      return arrow + (emoji || "") + "**" + word + "**.";
    });
  }

  function structurePreambleLines(lines) {
    var out = [];
    var i = 0;
    while (i < lines.length) {
      var line = String(lines[i] || "").trim();
      if (!line) {
        i += 1;
        continue;
      }
      if (
        i === 0 &&
        (line.indexOf("💡") === 0 ||
          line.indexOf("Adım Adım") !== -1 ||
          line.indexOf("Adim Adim") !== -1)
      ) {
        var hdr = line.match(ADIM_ADIM_HEADER_RE);
        if (hdr && line.indexOf("Adım Adım") !== -1) {
          out.push("**" + hdr[1].trim() + "**");
          out.push("");
          var rest = String(hdr[2] || "").trim();
          if (rest) out.push(rest);
          i += 1;
          continue;
        }
        out.push("**" + stripOuterBold(line) + "**");
        out.push("");
        i += 1;
        continue;
      }
      if (FORMULA_LIST_LABEL_RE.test(line)) {
        while (i < lines.length && FORMULA_LIST_LABEL_RE.test(String(lines[i] || "").trim())) {
          out.push("- " + String(lines[i] || "").trim());
          i += 1;
        }
        out.push("");
        continue;
      }
      if (CONDITION_BULLET_RE.test(line)) {
        while (i < lines.length && CONDITION_BULLET_RE.test(String(lines[i] || "").trim())) {
          out.push("- " + String(lines[i] || "").trim());
          i += 1;
        }
        out.push("");
        continue;
      }
      if (STEP_HEADER_RE.test(line)) {
        var stepCore = line.trim();
        if (/^\*\*[\s\S]+\*\*$/.test(stepCore)) {
          out.push(stepCore);
        } else {
          out.push("**" + stepCore + "**");
        }
        out.push("");
        i += 1;
        continue;
      }
      if (NUMBERED_SECTION_RE.test(line)) {
        var section = line.match(NUMBERED_SECTION_TITLE_RE);
        if (section && String(section[2] || "").trim()) {
          out.push("**" + section[1].trim() + "**");
          out.push("");
          out.push(String(section[2]).trim());
        } else {
          out.push("**" + line + "**");
        }
        out.push("");
        i += 1;
        continue;
      }
      if (KURAL_OZETI_RE.test(line) || /^kural özeti/i.test(line)) {
        out.push("**Kural Özeti:**");
        i += 1;
        while (i < lines.length) {
          var nxt = String(lines[i] || "").trim();
          if (!nxt) {
            i += 1;
            break;
          }
          if (
            nxt.indexOf("Şimdi ") === 0 ||
            nxt.indexOf("Bir öğrenci") === 0 ||
            isOptionHeaderLine(nxt)
          ) {
            break;
          }
          var body = stripOuterBold(nxt.replace(BULLET_STRIP_RE, "").trim());
          if (body) out.push("- " + body);
          i += 1;
        }
        out.push("");
        continue;
      }
      out.push(line);
      i += 1;
    }
    return out;
  }

  /** Google çözüm: madde + A–E iç içe liste (rich_text_common.structure_solution_outline). */
  function structureSolutionOutline(text) {
    var src = String(text || "")
      .replace(/\r\n/g, "\n")
      .replace(/\r/g, "\n")
      .trim();
    if (!src) return src;
    src = formatPresenceTable(src);
    var lines = src.split("\n");
    var optionIdxs = [];
    for (var i = 0; i < lines.length; i++) {
      if (isOptionHeaderLine(String(lines[i] || "").trim())) {
        optionIdxs.push(i);
      }
    }
    if (optionIdxs.length < 2) {
      var preambleOnly = structurePreambleLines(lines);
      return preambleOnly.length ? preambleOnly.join("\n").replace(/^\s+|\s+$/g, "") : src;
    }

    var out = structurePreambleLines(lines.slice(0, optionIdxs[0]));
    if (out.length && out[out.length - 1] !== "") out.push("");

    for (var oi = 0; oi < optionIdxs.length; oi++) {
      var start = optionIdxs[oi];
      var end = oi + 1 < optionIdxs.length ? optionIdxs[oi + 1] : lines.length;
      var block = [];
      for (var j = start; j < end; j++) {
        if (String(lines[j] || "").trim()) block.push(lines[j]);
      }
      if (!block.length) continue;
      var parsed = parseOptionHeader(String(block[0] || "").trim());
      if (!parsed) continue;
      out.push("- **" + parsed.title + ":**");
      if (parsed.inline) {
        var inlineBody = stripOuterBold(parsed.inline);
        if (inlineBody) out.push("  - " + emphasizeResultTail(inlineBody));
      }
      for (var c = 1; c < block.length; c++) {
        var raw = stripOuterBold(
          String(block[c] || "")
            .trim()
            .replace(BULLET_STRIP_RE, "")
            .trim()
        );
        if (!raw) continue;
        out.push("  - " + emphasizeResultTail(raw));
      }
      out.push("");
    }
    return out.join("\n").trim();
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

  function repairSplitBoldLines(text) {
    return String(text || "").replace(
      /\*\*([^\n*][^\n]*?)\n\s+([^\n*][^\n]*?)\*\*/g,
      "**$1$2**"
    );
  }

  /** `** metin **` / `__ metin __` — iç boşluğu dışarı taşı (yutma). */
  function tightenMarkdownMarkers(text) {
    var src = collapseNestedMarks(text);
    function peel(open, close, full, inner) {
      var body = String(inner);
      var leadSpaces = "";
      var trailSpaces = "";
      var mLead = full.match(
        new RegExp("^" + open.replace(/\*/g, "\\*") + "([ \\t]+)")
      );
      if (mLead) leadSpaces = mLead[1];
      var mTrail = full.match(
        new RegExp("([ \\t]+)" + close.replace(/\*/g, "\\*") + "$")
      );
      if (mTrail) trailSpaces = mTrail[1];
      if (body.indexOf("\n") >= 0) {
        return leadSpaces + open + body + close + trailSpaces;
      }
      return leadSpaces + open + body.trim() + close + trailSpaces;
    }
    src = src.replace(/\*\*[ \t]+([\s\S]+?)[ \t]+\*\*/g, function (full, inner) {
      return peel("**", "**", full, inner);
    });
    src = src.replace(/__[ \t]+([\s\S]+?)[ \t]+__/g, function (full, inner) {
      return peel("__", "__", full, inner);
    });
    src = src.replace(/(?<!\*)\*[ \t]+([\s\S]+?)[ \t]+\*(?!\*)/g, function (full, inner) {
      return peel("*", "*", full, inner);
    });
    src = src.replace(/\*\*([\s\S]+?)[ \t]+\*\*/g, function (full, inner) {
      return peel("**", "**", full, inner);
    });
    src = src.replace(/__([\s\S]+?)[ \t]+__/g, function (full, inner) {
      return peel("__", "__", full, inner);
    });
    return src;
  }

  /**
   * Harf/`**` bitişikse (`kelime**kalın**devam`) araya boşluk koy.
   * Math placeholder'ları koru.
   */
  function ensureMarkdownExteriorSpaces(text) {
    var src = String(text || "");
    var holders = [];
    src = src.replace(/\$\$[\s\S]+?\$\$|\$[^$\n]+\$/g, function (m) {
      holders.push(m);
      return "§§M" + (holders.length - 1) + "§§";
    });
    // Açılış: harf/rakam/apostrof + ** veya __ (*** / ___ değil)
    src = src.replace(/([0-9A-Za-zÀ-ÖØ-öø-ÿÇĞİÖŞÜÂÎÛçğıöşüâîû'’])(\*\*)(?!\*)/g, "$1 $2");
    src = src.replace(/([0-9A-Za-zÀ-ÖØ-öø-ÿÇĞİÖŞÜÂÎÛçğıöşüâîû'’])(__)(?!_)/g, "$1 $2");
    // Kapanış: ** veya __ + harf/rakam
    src = src.replace(/(\*\*)(?!\*)([0-9A-Za-zÀ-ÖØ-öø-ÿÇĞİÖŞÜÂÎÛçğıöşüâîû])/g, "$1 $2");
    src = src.replace(/(__)(?!_)([0-9A-Za-zÀ-ÖØ-öø-ÿÇĞİÖŞÜÂÎÛçğıöşüâîû])/g, "$1 $2");
    src = src.replace(/§§M(\d+)§§/g, function (_, idx) {
      return holders[Number(idx)] || "";
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
    src = tightenMarkdownMarkers(src);
    src = ensureMarkdownExteriorSpaces(src);
    src = repairSplitBoldLines(src);
    // Bozuk satır kırığından kalan yalnız ** / __ satırlarını temizle.
    src = src.replace(/^\s*\*\*\s*$/gm, "");
    src = src.replace(/^\s*__\s*$/gm, "");
    return src;
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
    // Sınav metninde otomatik negatif/pozitif renk yok.
    return html;
  }

  function emphasizeSignWords(html) {
    return String(html || "");
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

  function needsDisplayMathBlock(tex) {
    return /\\begin\{(?:array|matrix|pmatrix|cases)\}/.test(tex) || /\\hline/.test(tex);
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
      var display = !!(m[1] || m[3]) || needsDisplayMathBlock(tex);
      if (display && !(m[1] || m[3])) {
        out +=
          '<span class="math-block">' + renderMath(tex, true) + "</span>";
      } else {
        out += renderMath(tex, display);
      }
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
    src = structureSolutionOutline(restoreCollapsedBreaks(normalizeLatex(src)));
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

      if (examMode) {
        var stepHdr = trimmed.match(/^\*\*\s*\d+\.\s+Adım:.+\*\*$/);
        if (stepHdr) {
          if (!inList) {
            html.push('<ul class="rich-list">');
            inList = true;
          }
          closeNested();
          html.push("<li>" + richInline(trimmed) + "</li>");
          return;
        }
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
    mergeSplitInlineDollarMath: mergeSplitInlineDollarMath,
    restoreCollapsedBreaks: restoreCollapsedBreaks,
    structureSolutionOutline: structureSolutionOutline,
    wrapBareLatex: wrapBareLatex,
    forceDisplaySizeAll: forceDisplaySizeAll,
    richInline: richInline,
    plainInline: plainInline,
    paragraphHtml: paragraphHtml,
    documentHtml: documentHtml,
    examDocumentHtml: examDocumentHtml,
  };
})(window);
