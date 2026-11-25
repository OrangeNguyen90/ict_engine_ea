"""Advisory wire framing, source/pin checks and atomic publication contracts."""

from copy import deepcopy
from datetime import datetime, timedelta, timezone
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from .research.prediction_bridge import (
    atomic_write_snapshot, build_snapshot, parse_snapshot, serialize_snapshot,
)


AS_OF = datetime(2026, 11, 20, tzinfo=timezone.utc)
NOW = AS_OF + timedelta(seconds=12)
MODEL_ID = "a" * 64


def bundle():
    return {
        "model_id": MODEL_ID, "fit_cutoff": (AS_OF - timedelta(hours=2)).isoformat(),
        "train_end": (AS_OF - timedelta(hours=3)).isoformat(), "train_n": 120,
        "scope": "RESEARCH_ADVISORY", "execution_allowed": False, "source_gate": "VERIFIED",
        "config": {"symbol": "US500", "timeframe": "M15"},
        "source": {"symbol": "US500", "timeframe": "M15", "timeframe_seconds": 900,
                   "point": 0.01, "tick_size": 0.01, "price_type": "bid",
                   "price_type_historically_verified": True,
                   "quality": {"export_complete": True, "coverage_verified": True}},
    }


def prediction(**changes):
    return {"candidate_id": "b" * 24, "family": "SWEEP_RECLAIM", "direction": 1,
            "status": "SELECTED", "reason": "POSITIVE_EXPECTANCY", "selected_target_r": 3.0,
            "expected_net_r": 0.45, "p_tp": 0.6, **changes}


class PredictionBridgeTests(unittest.TestCase):
    def snapshot(self, *, model=None, result=None, **changes):
        return build_snapshot(bundle() if model is None else model,
                              prediction() if result is None else result,
                              **{"symbol": "US500", "timeframe": "M15", "as_of": AS_OF,
                                 "now": NOW, **changes})

    def parse(self, text, **changes):
        return parse_snapshot(text, **{"expected_model_id": MODEL_ID, "symbol": "US500",
                                       "timeframe": "M15", "as_of": AS_OF, "now": NOW, **changes})

    def replace_field(self, text, index, value):
        fields = text.rstrip("\n").split(";")
        fields[index] = value
        return ";".join(fields) + "\n"

    def test_selected_roundtrip_is_exactly_twenty_two_ascii_fields(self):
        snapshot = self.snapshot()
        text = serialize_snapshot(snapshot)
        self.assertTrue(text.isascii())
        self.assertTrue(text.endswith("\n"))
        self.assertEqual(text.count("\n"), 1)
        self.assertEqual(len(text.rstrip("\n").split(";")), 22)
        self.assertEqual(self.parse(text), snapshot)
        self.assertFalse(snapshot["execution_allowed"])
        self.assertEqual(snapshot["expires_at"], int(NOW.timestamp()) + 60)

    def test_probability_can_be_missing_and_is_not_imputed(self):
        snapshot = self.snapshot(result=prediction(p_tp=None))
        text = serialize_snapshot(snapshot)
        self.assertEqual(text.split(";")[16], "NA")
        self.assertIsNone(self.parse(text)["p_tp"])

    def test_abstention_can_omit_candidate_and_all_prediction_numbers(self):
        snapshot = self.snapshot(result={"status": "ABSTAIN", "reason": "NO_CANDIDATE"})
        parsed = self.parse(serialize_snapshot(snapshot))
        self.assertEqual((parsed["candidate_id"], parsed["family"], parsed["direction"]), ("-", "-", 0))
        self.assertIsNone(parsed["selected_target_r"])
        self.assertIsNone(parsed["expected_net_r"])

    def test_abstention_can_retain_valid_candidate_diagnostics(self):
        snapshot = self.snapshot(result=prediction(status="ABSTAIN", reason="LOW_EXPECTANCY",
                                                   selected_target_r=None, expected_net_r=-0.2))
        self.assertEqual(self.parse(serialize_snapshot(snapshot)), snapshot)

    def test_rejects_execution_permission_and_incorrect_scope(self):
        for key, value in (("scope", "LIVE"), ("execution_allowed", True),
                           ("execution_allowed", 0), ("source_gate", "UNVERIFIED_SOURCE")):
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                model = bundle()
                model[key] = value
                self.snapshot(model=model)
        text = serialize_snapshot(self.snapshot())
        for index, value in ((18, "LIVE"), (19, "1"), (19, "False"), (20, "UNVERIFIED")):
            with self.subTest(index=index), self.assertRaises(ValueError):
                self.parse(self.replace_field(text, index, value))

    def test_verified_gate_cannot_hide_unverified_source_flags(self):
        for key, value in (("price_type_historically_verified", False), ("price_type", "last"),
                           ("symbol", "OTHER"), ("timeframe_seconds", 60), ("point", 0)):
            model = bundle()
            model["source"][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.snapshot(model=model)
        for key in ("export_complete", "coverage_verified"):
            model = bundle()
            model["source"]["quality"][key] = False
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.snapshot(model=model)
        model = bundle()
        model["config"]["timeframe"] = "M5"
        with self.assertRaises(ValueError):
            self.snapshot(model=model)

    def test_rejects_each_consumer_pin_mismatch(self):
        text = serialize_snapshot(self.snapshot())
        for changes in ({"expected_model_id": "c" * 64}, {"symbol": "US500.cash"},
                        {"timeframe": "M5"}, {"as_of": AS_OF - timedelta(minutes=15)}):
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                self.parse(text, **changes)

    def test_rejects_ascii_injection_unicode_whitespace_and_bad_identifiers(self):
        for symbol in ("US500;M15", "US500\n", "US 500", "US500\t", "US500é", "X" * 41, ""):
            with self.subTest(symbol=symbol), self.assertRaises(ValueError):
                self.snapshot(symbol=symbol)
        for result in (prediction(reason="bad_reason"), prediction(reason="OK;1"),
                       prediction(reason="OK\n"), prediction(candidate_id="b" * 23),
                       prediction(candidate_id="g" * 24), prediction(family="UNKNOWN"),
                       prediction(direction=True), prediction(candidate_id="-")):
            with self.subTest(result=result), self.assertRaises(ValueError):
                self.snapshot(result=result)

    def test_rejects_nonfinite_or_out_of_range_predictions(self):
        cases = [(key, value) for key in ("selected_target_r", "expected_net_r", "p_tp")
                 for value in (float("nan"), float("inf"), -float("inf"), True, "0.5")]
        cases += [("selected_target_r", 0), ("selected_target_r", -2),
                  ("expected_net_r", None), ("p_tp", -0.1), ("p_tp", 1.1)]
        for key, value in cases:
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                self.snapshot(result=prediction(**{key: value}))
        for train_n in (0, -1, True, 1.5, 2_147_483_648):
            model = bundle()
            model["train_n"] = train_n
            with self.subTest(train_n=train_n), self.assertRaises(ValueError):
                self.snapshot(model=model)

    def test_rejects_malformed_partial_and_extra_line_payloads(self):
        text = serialize_snapshot(self.snapshot())
        cases = (text[:-1], text + "\n", text + text, text.replace(";END", ""),
                 text.replace(";END", ";END;EXTRA"), "\ufeff" + text, "X" * 8193,
                 text.replace("ICTML1", "ICTML2"), text.replace(";END", ";STOP"))
        for value in cases:
            with self.subTest(value=value[:100]), self.assertRaises(ValueError):
                self.parse(value)
        self.assertEqual(self.parse(text[:-1] + "\r\n")["status"], "SELECTED")
        self.assertEqual(self.parse(text[:-1] + "\r")["status"], "SELECTED")

    def test_rejects_invalid_numeric_wire_tokens(self):
        text = serialize_snapshot(self.snapshot())
        for value in ("NaN", "inf", "1e999", " 1", "1 ", "", "0x10", "1,2", "+", "1" * 65):
            with self.subTest(value=value), self.assertRaises(ValueError):
                self.parse(self.replace_field(text, 14, value))
        for index in (14, 15):
            with self.subTest(index=index), self.assertRaises(ValueError):
                self.parse(self.replace_field(text, index, "NA"))
        self.assertAlmostEqual(self.parse(self.replace_field(text, 15, "+.5e-1"))["expected_net_r"], 0.05)

    def test_rejects_invalid_uint_and_direction_wire_tokens(self):
        text = serialize_snapshot(self.snapshot())
        for index in (4, 5, 6, 7, 8, 17):
            for value in ("0", "-1", "+1", "1.0", "1e9", " 1", "99999999999"):
                with self.subTest(index=index, value=value), self.assertRaises(ValueError):
                    self.parse(self.replace_field(text, index, value))
        for value in ("+1", "1.0", "2", "01"):
            with self.subTest(direction=value), self.assertRaises(ValueError):
                self.parse(self.replace_field(text, 11, value))

    def test_requires_coherent_candidate_fields_and_abstention_target(self):
        text = serialize_snapshot(self.snapshot())
        for index, value in ((9, "-"), (10, "-"), (11, "0"), (12, "UNKNOWN"),
                             (13, "NOT A TOKEN"), (16, "1.1")):
            with self.subTest(index=index, value=value), self.assertRaises(ValueError):
                self.parse(self.replace_field(text, index, value))
        with self.assertRaises(ValueError):
            self.snapshot(result=prediction(status="ABSTAIN"))

    def test_expiry_is_clamped_at_next_confirmation_and_boundary_is_stale(self):
        snapshot = self.snapshot(ttl_seconds=3600)
        self.assertEqual(snapshot["expires_at"], int((AS_OF + timedelta(minutes=15)).timestamp()))
        text = serialize_snapshot(snapshot)
        self.assertEqual(self.parse(text, now=AS_OF + timedelta(seconds=899))["status"], "SELECTED")
        with self.assertRaises(ValueError):
            self.parse(text, now=AS_OF + timedelta(minutes=15))
        snapshot["expires_at"] += 1
        with self.assertRaises(ValueError):
            serialize_snapshot(snapshot)

    def test_build_forces_stale_or_preconfirmation_clock_to_abstain(self):
        for now, reason in ((AS_OF - timedelta(seconds=1), "CLOCK_BEFORE_ASOF"),
                            (AS_OF + timedelta(minutes=15), "DATA_STALE")):
            with self.subTest(now=now):
                snapshot = self.snapshot(now=now)
                self.assertEqual(snapshot["status"], "ABSTAIN")
                self.assertEqual(snapshot["reason"], reason)
                self.assertIsNone(snapshot["selected_target_r"])
                with self.assertRaises(ValueError):
                    self.parse(serialize_snapshot(snapshot), now=now)

    def test_parser_tolerates_at_most_five_seconds_of_generation_clock_skew(self):
        snapshot = self.snapshot()
        snapshot["generated_at"] = int(NOW.timestamp()) + 5
        self.assertEqual(self.parse(serialize_snapshot(snapshot))["status"], "SELECTED")
        snapshot["generated_at"] += 1
        with self.assertRaises(ValueError):
            self.parse(serialize_snapshot(snapshot))

    def test_invalid_training_times_or_naive_clocks_never_produce_snapshot(self):
        for key, value in (("train_end", bundle()["fit_cutoff"]),
                           ("fit_cutoff", (AS_OF + timedelta(seconds=1)).isoformat()),
                           ("train_end", "not-a-time"), ("fit_cutoff", "2026-11-19T00:00:00")):
            model = bundle()
            model[key] = value
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                self.snapshot(model=model)
        for changes in ({"now": NOW.replace(tzinfo=None)}, {"as_of": AS_OF.replace(tzinfo=None)},
                        {"ttl_seconds": 0}, {"ttl_seconds": True}):
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                self.snapshot(**changes)

    def test_atomic_write_creates_directory_and_complete_readable_payload(self):
        snapshot = self.snapshot()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "nested" / "prediction.txt"
            atomic_write_snapshot(path, snapshot)
            self.assertEqual(self.parse(path.read_text(encoding="ascii")), snapshot)
            self.assertEqual(list(path.parent.iterdir()), [path])

    def test_failed_atomic_replace_preserves_prior_file_and_cleans_temporary(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "prediction.txt"
            path.write_text("PRIOR\n", encoding="ascii")
            with patch("market.research.prediction_bridge.os.replace", side_effect=OSError("replace failed")):
                with self.assertRaises(OSError):
                    atomic_write_snapshot(path, self.snapshot())
            self.assertEqual(path.read_text(encoding="ascii"), "PRIOR\n")
            self.assertEqual(list(path.parent.iterdir()), [path])

    def test_invalid_snapshot_does_not_replace_existing_file(self):
        snapshot = self.snapshot()
        snapshot["execution_allowed"] = True
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "prediction.txt"
            path.write_text("PRIOR\n", encoding="ascii")
            with self.assertRaises(ValueError):
                atomic_write_snapshot(path, snapshot)
            self.assertEqual(path.read_text(encoding="ascii"), "PRIOR\n")

    def test_build_does_not_mutate_model_or_prediction(self):
        model, result = bundle(), prediction()
        original_model, original_result = deepcopy(model), deepcopy(result)
        self.snapshot(model=model, result=result)
        self.assertEqual(model, original_model)
        self.assertEqual(result, original_result)
