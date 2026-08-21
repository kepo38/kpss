/**
 * Matematik formül parçacıkları (panel soru formu).
 *
 * Kullanım:
 *   KpssMathFormulas.snippets.arrayIslem  → string
 *   KpssMathFormulas.insert(el, key)     → textarea/input'a yazar
 *   KpssMathFormulas.toolbarItems()      → [{key,label,title}, ...]
 *
 * Snippet anahtarları (toolbar / düzenleme):
 *   arrayIslem  — dikey çıkarma/toplama (ÖSYM array + hline)
 *   kesir       — \\frac{a}{b}
 *   kok         — \\sqrt{x}
 *   uslu        — x^{n}
 *   altIndis    — a_{n}
 *   denklem     — satır içi $A + B + C$
 *   displayFrac — $$\\displaystyle \\frac{a}{b}$$
 *   kokKesir    — \\sqrt{\\frac{a}{b}}
 *   parantez    — \\left( ... \\right)
 *   mutlak      — \\left| ... \\right|
 *   carpim      — \\cdot
 *   esitsizlik  — \\leq / \\geq
 */
(function (global) {
  var SNIPPETS = {
    arrayIslem:
      "$$\\displaystyle \\begin{array}{r} AB8 \\\\ -16C \\\\ \\hline CA3 \\end{array}$$",
    kesir: "$\\frac{a}{b}$",
    kok: "$\\sqrt{x}$",
    uslu: "$x^{n}$",
    altIndis: "$a_{n}$",
    denklem: "$A + B + C$",
    displayFrac: "$$\\displaystyle \\frac{a}{b}$$",
    kokKesir: "$\\sqrt{\\frac{a}{b}}$",
    parantez: "$\\left( \\right)$",
    mutlak: "$\\left| \\right|$",
    carpim: "$\\cdot$",
    esitsizlik: "$\\leq$",
  };

  var TOOLBAR = [
    { key: "arrayIslem", label: "İşlem", title: "Dikey işlem (array)" },
    { key: "kesir", label: "a/b", title: "Kesir" },
    { key: "kok", label: "√", title: "Kök" },
    { key: "uslu", label: "xⁿ", title: "Üslü" },
    { key: "denklem", label: "A+B", title: "Satır içi denklem" },
    { key: "displayFrac", label: "$$", title: "Display kesir" },
  ];

  function insertAtCursor(el, text) {
    if (!el) return;
    var start = typeof el.selectionStart === "number" ? el.selectionStart : el.value.length;
    var end = typeof el.selectionEnd === "number" ? el.selectionEnd : start;
    var val = el.value || "";
    el.value = val.slice(0, start) + text + val.slice(end);
    var pos = start + text.length;
    try {
      el.focus();
      el.setSelectionRange(pos, pos);
    } catch (e) { /* input type may not support */ }
    el.dispatchEvent(new Event("input", { bubbles: true }));
  }

  function insert(el, key) {
    var snip = SNIPPETS[key];
    if (!snip) return;
    insertAtCursor(el, snip);
  }

  function toolbarItems() {
    return TOOLBAR.slice();
  }

  global.KpssMathFormulas = {
    snippets: SNIPPETS,
    toolbarItems: toolbarItems,
    insert: insert,
    insertAtCursor: insertAtCursor,
  };
})(typeof window !== "undefined" ? window : globalThis);
