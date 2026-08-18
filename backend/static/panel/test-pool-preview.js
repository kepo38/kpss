/**
 * Test düzenle: soru kimliğine tıklayınca sağda telefon önizlemesi.
 */
(function () {
  function examFormat(text) {
    if (!text) return "";
    return text
      .replace(/\r\n/g, "\n")
      .replace(/\r/g, "\n")
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

  function escapeHtml(text) {
    return String(text)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
  }

  function mdInline(text) {
    return escapeHtml(text)
      .replace(/__\*\*\*(.+?)\*\*\*__/g, "<u><strong><em>$1</em></strong></u>")
      .replace(/\*\*__(.+?)__\*\*/g, "<strong><u>$1</u></strong>")
      .replace(/__\*\*(.+?)\*\*__/g, "<u><strong>$1</strong></u>")
      .replace(/\*\*\*(.+?)\*\*\*/g, "<strong><em>$1</em></strong>")
      .replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
      .replace(/__(.+?)__/g, "<u>$1</u>")
      .replace(/\*(.+?)\*/g, "<em>$1</em>");
  }

  function stemToHtml(text) {
    if (window.KpssMathRender) {
      return window.KpssMathRender.examDocumentHtml(text);
    }
    var clean = examFormat(text);
    if (!clean) return "";
    return clean
      .split(/\n\n+/)
      .map(function (p) {
        return "<p>" + mdInline(p) + "</p>";
      })
      .join("");
  }

  function richHtml(text) {
    if (window.KpssMathRender) {
      return window.KpssMathRender.richInline(text);
    }
    return mdInline(text);
  }

  function loadPool() {
    var el = document.getElementById("test-pool-data");
    if (!el) return {};
    try {
      var list = JSON.parse(el.textContent || "[]");
      var map = {};
      list.forEach(function (q) {
        map[String(q.id)] = q;
      });
      return map;
    } catch (e) {
      return {};
    }
  }

  function showQuestion(q, checked) {
    var stemEl = document.getElementById("tpv-stem");
    var metaEl = document.getElementById("tpv-meta");
    var solWrap = document.getElementById("tpv-solution");
    var solBody = document.getElementById("tpv-solution-body");
    var includeEl = document.getElementById("tpv-include");
    if (!stemEl || !q) return;

    if (metaEl) metaEl.textContent = q.public_id || "Soru";

    if (q.stem) {
      stemEl.innerHTML = stemToHtml(q.stem);
      stemEl.classList.remove("is-empty");
    } else {
      stemEl.innerHTML = "<p>Soru metni yok.</p>";
      stemEl.classList.add("is-empty");
    }

    var correct = q.correct || "A";
    var opts = q.options || {};
    ["A", "B", "C", "D", "E"].forEach(function (k) {
      var row = document.getElementById("tpv-opt-" + k);
      var text = document.getElementById("tpv-opt-text-" + k);
      if (!row || !text) return;
      var t = examFormat(opts[k] || "");
      if (t) {
        text.innerHTML = window.KpssMathRender
          ? window.KpssMathRender.plainInline(t)
          : richHtml(t).replace(/<\/?(?:strong|b|em|i|u)\b[^>]*>/gi, "");
        text.classList.remove("is-empty");
      } else {
        text.textContent = "—";
        text.classList.add("is-empty");
      }
      row.classList.toggle("is-correct", correct === k);
    });

    if (solWrap && solBody) {
      if (q.solution) {
        solBody.innerHTML = window.KpssMathRender
          ? window.KpssMathRender.examDocumentHtml(q.solution)
          : stemToHtml(q.solution);
        solWrap.classList.add("is-on");
      } else {
        solBody.textContent = "";
        solWrap.classList.remove("is-on");
      }
    }

    if (includeEl) {
      includeEl.hidden = false;
      includeEl.textContent = checked
        ? "Bu soru teste dahil"
        : "Bu soru teste dahil değil";
      includeEl.classList.toggle("is-on", !!checked);
      includeEl.classList.toggle("is-off", !checked);
    }
  }

  document.addEventListener("DOMContentLoaded", function () {
    var poolRoot = document.getElementById("test-q-pool");
    var preview = document.getElementById("test-question-preview");
    if (!poolRoot || !preview) return;

    var byId = loadPool();

    function syncRowState(row) {
      var box = row.querySelector('input[type="checkbox"]');
      row.classList.toggle("is-in-test", !!(box && box.checked));
    }

    poolRoot.addEventListener("click", function (e) {
      var btn = e.target.closest(".js-q-preview");
      if (!btn) return;
      e.preventDefault();
      var id = btn.getAttribute("data-qid");
      var q = byId[id];
      if (!q) return;

      poolRoot.querySelectorAll(".q-pool-row").forEach(function (r) {
        r.classList.toggle("is-active", r.getAttribute("data-qid") === id);
      });

      var row = poolRoot.querySelector('.q-pool-row[data-qid="' + id + '"]');
      var box = row ? row.querySelector('input[type="checkbox"]') : null;
      showQuestion(q, box && box.checked);
    });

    poolRoot.addEventListener("change", function (e) {
      var box = e.target.closest('input[type="checkbox"]');
      if (!box) return;
      var row = box.closest(".q-pool-row");
      if (row) syncRowState(row);
      if (row && row.classList.contains("is-active")) {
        var q = byId[box.value];
        if (q) showQuestion(q, box.checked);
      }
    });

    // İlk seçili veya listedeki ilk soruyu göster
    var first =
      poolRoot.querySelector(".q-pool-row.is-in-test .js-q-preview") ||
      poolRoot.querySelector(".js-q-preview");
    if (first) first.click();
  });
})();
