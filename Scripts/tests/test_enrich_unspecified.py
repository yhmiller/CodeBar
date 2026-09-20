#!/usr/bin/env python3
"""Tests for enrich_unspecified.py using a mock TypeSafe client."""
import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

SCRIPTS = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(SCRIPTS))


def _make_noul_answer(noul_value):
    """Build a mock Noul answer with the given probability."""
    answer = MagicMock()
    answer.noul = noul_value
    return answer


def _make_response(noul_values):
    """Build a mock TypeSafe response for a batch of noul_values (in order)."""
    response = MagicMock()
    response.answers = {
        f"code_{i}": _make_noul_answer(v)
        for i, v in enumerate(noul_values)
    }
    return response


class EnrichBatchTests(unittest.TestCase):
    """Unit tests for the enrich_batch() function with a mocked client."""

    def setUp(self):
        # Import the functions under test (after sys.path is set)
        from enrich_unspecified import enrich_batch
        self.enrich_batch = enrich_batch

        # Patch typesafe_sdk so the import doesn't require the real package
        self.noul_patcher = patch.dict("sys.modules", {
            "typesafe_sdk": MagicMock(),
        })
        self.noul_patcher.start()

        # Re-import with the mock in place
        import importlib
        import enrich_unspecified as mod
        importlib.reload(mod)
        self.enrich_batch = mod.enrich_batch

    def tearDown(self):
        self.noul_patcher.stop()

    def _run(self, noul_values, threshold_yes=0.80, threshold_no=0.35):
        batch = [
            {"code": f"C{i}", "display": f"Display {i}"}
            for i in range(len(noul_values))
        ]
        client = MagicMock()
        client.system_one.return_value = _make_response(noul_values)
        return self.enrich_batch(
            client, batch, threshold_yes, threshold_no
        )

    def test_high_noul_gives_unspecified_true(self):
        results = self._run([0.95])
        self.assertEqual(results, [True])

    def test_low_noul_gives_unspecified_false(self):
        results = self._run([0.10])
        self.assertEqual(results, [False])

    def test_ambiguous_noul_gives_none(self):
        results = self._run([0.55])
        self.assertEqual(results, [None])

    def test_boundary_at_threshold_yes_is_true(self):
        results = self._run([0.80])
        self.assertEqual(results, [True])

    def test_boundary_at_threshold_no_is_false(self):
        results = self._run([0.35])
        self.assertEqual(results, [False])

    def test_batch_of_three_mixed(self):
        results = self._run([0.92, 0.05, 0.60])
        self.assertEqual(results, [True, False, None])

    def test_makes_exactly_one_api_call_per_batch(self):
        batch = [
            {"code": f"A{i}", "display": f"Desc {i}"}
            for i in range(10)
        ]
        client = MagicMock()
        client.system_one.return_value = _make_response([0.9] * 10)
        self.enrich_batch(client, batch, 0.80, 0.35)
        self.assertEqual(client.system_one.call_count, 1)


class EnrichBatchingTests(unittest.TestCase):
    """Verifies that 60 codes produce exactly 2 API calls with batch_size=50."""

    def setUp(self):
        self.noul_patcher = patch.dict("sys.modules", {
            "typesafe_sdk": MagicMock(),
        })
        self.noul_patcher.start()
        import importlib
        import enrich_unspecified as mod
        importlib.reload(mod)
        self.mod = mod

    def tearDown(self):
        self.noul_patcher.stop()

    def test_60_codes_produce_two_api_calls(self):
        entries = [
            {"code": f"E{i:02d}", "display": f"Condition {i}"}
            for i in range(60)
        ]

        call_counts = []

        def fake_enrich_batch(client, batch, ty, tn, dry_run=False):
            call_counts.append(len(batch))
            return [True] * len(batch)

        with patch.object(self.mod, "enrich_batch", side_effect=fake_enrich_batch), \
             patch.object(self.mod, "_typesafe_available", return_value=True):
            mock_client_cm = MagicMock()
            mock_client_cm.__enter__ = MagicMock(return_value=MagicMock())
            mock_client_cm.__exit__ = MagicMock(return_value=False)

            ts_mock = MagicMock()
            ts_mock.TypeSafeClient.return_value = mock_client_cm
            with patch.dict("sys.modules", {"typesafe_sdk": ts_mock}):
                self.mod.enrich_entries(entries, batch_size=50)

        self.assertEqual(len(call_counts), 2)
        self.assertEqual(call_counts[0], 50)
        self.assertEqual(call_counts[1], 10)


class ResumeTests(unittest.TestCase):
    """Already-annotated codes are skipped by enrich_entries()."""

    def setUp(self):
        self.noul_patcher = patch.dict("sys.modules", {
            "typesafe_sdk": MagicMock(),
        })
        self.noul_patcher.start()
        import importlib
        import enrich_unspecified as mod
        importlib.reload(mod)
        self.mod = mod

    def tearDown(self):
        self.noul_patcher.stop()

    def test_already_annotated_codes_are_skipped(self):
        entries = [
            {"code": "E11.9", "display": "Unspecified diabetes", "unspecified": True},
            {"code": "E11.65", "display": "Diabetes with hyperglycemia"},
        ]

        batches_seen = []

        def fake_enrich_batch(client, batch, ty, tn, dry_run=False):
            batches_seen.append([e["code"] for e in batch])
            return [False] * len(batch)

        with patch.object(self.mod, "enrich_batch", side_effect=fake_enrich_batch), \
             patch.object(self.mod, "_typesafe_available", return_value=True):
            mock_client_cm = MagicMock()
            mock_client_cm.__enter__ = MagicMock(return_value=MagicMock())
            mock_client_cm.__exit__ = MagicMock(return_value=False)

            ts_mock = MagicMock()
            ts_mock.TypeSafeClient.return_value = mock_client_cm
            with patch.dict("sys.modules", {"typesafe_sdk": ts_mock}):
                result = self.mod.enrich_entries(entries)

        # Only the unannotated code should have been queried
        flat = [c for batch in batches_seen for c in batch]
        self.assertNotIn("E11.9", flat)
        self.assertIn("E11.65", flat)
        # Result for E11.9 is absent (it was already annotated; not returned by enrich_entries)
        self.assertNotIn("E11.9", result)


if __name__ == "__main__":
    unittest.main()
