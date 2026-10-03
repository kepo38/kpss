#!/usr/bin/env node
/** Panel JS çözüm yapıştırma — Python normalize_field("solution") ile parity. */
const fs = require("fs");
const path = require("path");

global.window = global;
global.document = {
  addEventListener: function () {},
  querySelector: function () {
    return null;
  },
};

require(path.join(__dirname, "../static/panel/math-render.js"));
require(path.join(__dirname, "../static/panel/rich-format.js"));

const fixturePath = path.join(
  __dirname,
  "../content/fixtures/rich_text_parity.json",
);
const fixtures = JSON.parse(fs.readFileSync(fixturePath, "utf8"));
const finalize = global.KpssRichFormat.finalizeSolutionPaste;

const results = [];
for (const caseItem of fixtures.cases || []) {
  if ((caseItem.field || "solution") !== "solution") continue;
  const input = caseItem.effective_input || caseItem.input || "";
  const html = caseItem.html || "";
  let plain = input;
  if (!plain && html && global.KpssRichFormat.choosePasteText) {
    plain = global.KpssRichFormat.choosePasteText("", html);
  }
  results.push({
    id: caseItem.id,
    output: finalize(plain),
  });
}

process.stdout.write(JSON.stringify(results));
