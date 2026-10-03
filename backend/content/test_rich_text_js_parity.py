"""Panel JS finalizeSolutionPaste ↔ Python normalize_field parity."""

from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path

from django.test import SimpleTestCase

from content.rich_text_parity import load_parity_fixtures
from content.rich_text_storage import normalize_field

_SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "rich_text_js_parity.js"


class RichTextJsParityTests(SimpleTestCase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        if shutil.which("node") is None:
            cls.node_results = None
            return
        proc = subprocess.run(
            ["node", str(_SCRIPT)],
            capture_output=True,
            text=True,
            encoding="utf-8",
            check=False,
            cwd=str(_SCRIPT.parent),
        )
        if proc.returncode != 0:
            raise RuntimeError(
                f"JS parity script failed ({proc.returncode}): {proc.stderr}"
            )
        cls.node_results = {
            item["id"]: item["output"]
            for item in json.loads(proc.stdout or "[]")
        }

    def test_node_available(self):
        if self.node_results is None:
            self.skipTest("node not installed")

    def test_js_solution_pipeline_matches_python_expected(self):
        if self.node_results is None:
            self.skipTest("node not installed")

        skip = {"html_bold_and_bullets"}  # htmlClipboardToText DOM bağımlı; kayıt sunucuda

        for case in load_parity_fixtures():
            if (case.get("field") or "solution") != "solution":
                continue
            if case["id"] in skip:
                continue
            with self.subTest(case_id=case["id"]):
                py_out = normalize_field(
                    "solution",
                    case.get("input") or "",
                    html=case.get("html") or "",
                )
                js_out = self.node_results.get(case["id"])
                self.assertIsNotNone(js_out, msg="JS script missing case output")
                self.assertEqual(
                    js_out,
                    py_out,
                    msg=(
                        f"JS/Python mismatch for {case['id']}. "
                        "Check finalizeSolutionPaste vs normalize_pasted_solution."
                    ),
                )
                self.assertEqual(js_out, case["expected"])
