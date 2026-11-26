#!/usr/bin/env python3
"""Unit tests for narrative validators using fixtures (no Godot required)."""

from __future__ import annotations

import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

import save_roundtrip  # noqa: E402
import simulate_strategies  # noqa: E402
import validate_narrative  # noqa: E402

FIX = Path(__file__).parent / "fixtures"


class ValidatorFixtureTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        content = self.tmp / "content"
        shutil.copytree(FIX / "content", content)
        (self.tmp / "project.godot").write_text(
            '; Engine configuration file.\nconfig_version=5\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',
            encoding="utf-8",
        )

    def tearDown(self) -> None:
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_validate_passes_good_content(self) -> None:
        report = validate_narrative.run_validation(self.tmp)
        self.assertEqual(report.errors, [], [e.message for e in report.errors])
        self.assertGreaterEqual(report.stats.get("dialogue_nodes", 0), 5)
        self.assertGreaterEqual(report.stats.get("characters", 0), 3)

    def test_broken_ref_detected(self) -> None:
        # poison a next pointer
        path = self.tmp / "content" / "dialogue" / "reception.json"
        data = json.loads(path.read_text(encoding="utf-8"))
        data["nodes"][0]["choices"][0]["next"] = "does.not.exist"
        path.write_text(json.dumps(data), encoding="utf-8")
        report = validate_narrative.run_validation(self.tmp)
        self.assertTrue(any(f.check == "broken_ref" for f in report.errors))

    def test_missing_character_detected(self) -> None:
        path = self.tmp / "content" / "dialogue" / "reception.json"
        data = json.loads(path.read_text(encoding="utf-8"))
        data["nodes"][0]["speaker"] = "ghost_npc"
        path.write_text(json.dumps(data), encoding="utf-8")
        report = validate_narrative.run_validation(self.tmp)
        self.assertTrue(any(f.check == "missing_character" for f in report.errors))

    def test_contradictory_flags_detected(self) -> None:
        path = self.tmp / "content" / "dialogue" / "reception.json"
        data = json.loads(path.read_text(encoding="utf-8"))
        data["nodes"][0]["effects"] = [
            {"op": "set_flag", "flag": "briefed", "value": True},
            {"op": "set_flag", "flag": "briefed", "value": False},
        ]
        path.write_text(json.dumps(data), encoding="utf-8")
        report = validate_narrative.run_validation(self.tmp)
        self.assertTrue(any(f.check == "contradictory_flags" for f in report.errors))

    def test_strategy_divergence(self) -> None:
        result = simulate_strategies.run(self.tmp)
        self.assertTrue(result["divergent"], result)
        self.assertGreaterEqual(result["unique_outcomes"], 3)
        self.assertTrue(result["pass"], result.get("errors"))

    def test_save_roundtrip_sample(self) -> None:
        import os

        os.environ["QA_SKIP_GODOT"] = "1"
        try:
            result = save_roundtrip.run(self.tmp)
        finally:
            os.environ.pop("QA_SKIP_GODOT", None)
        self.assertTrue(result["python_roundtrip"]["ok"])


if __name__ == "__main__":
    unittest.main()
