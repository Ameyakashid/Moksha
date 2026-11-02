#!/usr/bin/env python3
"""Positive and negative controls for the replay observer, independent of Godot."""
import unittest
from replay_checks import first_difference, schedule, engine_errors, sources


class ReplayObserverTests(unittest.TestCase):
    def test_colored_indented_script_error(self):
        self.assertEqual(engine_errors("  \x1b[31mSCRIPT ERROR: simulated zero-exit error\x1b[0m"),
                         ["SCRIPT ERROR: simulated zero-exit error"])

    def test_plain_and_indented_errors(self):
        self.assertEqual(engine_errors("Godot Engine\n\tERROR: failure\nREPLAY_RESULT ticks=12"),
                         ["ERROR: failure"])
        self.assertEqual(engine_errors("REPLAY_RESULT ticks=12\nWARNING: sample"), [])

    def test_budget_config_pinned(self):
        self.assertIn('campaign/quality/assets_budgets.json', sources())

    def test_identical_trace(self):
        self.assertIsNone(first_difference([{'health': 60}], [{'health': 60}]))

    def test_first_divergence(self):
        self.assertEqual(first_difference([{'health': 60}, {'health': 60}],
                                         [{'health': 60}, {'health': 48}])['tick'], 1)

    def test_truncated_trace_is_not_pass(self):
        self.assertEqual(first_difference([{}, {}], [{}])['tick'], 1)

    def test_seed_reproducible(self):
        self.assertEqual(schedule(7, 60, 3), schedule(7, 60, 3))
        self.assertNotEqual(schedule(7, 60, 3)['frames'], schedule(83, 60, 3)['frames'])

    def test_real_button_names_and_length(self):
        for hz in (60, 120):
            frames = schedule(7, hz, 12)['frames']
            self.assertEqual(len(frames), hz * 12)
            keys = set().union(*(set(frame) for frame in frames))
            self.assertEqual(keys, {'left', 'right', 'jump', 'attack', 'shield'})


if __name__ == '__main__':
    unittest.main()
