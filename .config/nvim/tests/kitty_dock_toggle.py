"""Run with: kitty +runpy 'import runpy; runpy.run_path("tests/kitty_dock_toggle.py", run_name="__main__")'"""
import importlib.util
import unittest
from contextlib import nullcontext
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock, call

from kitty.types import DockSpec


def load_helper():
    spec = importlib.util.spec_from_file_location(
        'dock_toggle', Path(__file__).resolve().parents[1] / 'kitty/dock_toggle.py')
    assert spec is not None and spec.loader is not None
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    return helper


class DockToggleTests(unittest.TestCase):
    def setUp(self):
        self.home = Mock(os_window_id=1)
        self.parking = Mock()
        self.parking.name = 'NVIM docks [10]'
        self.owner = SimpleNamespace(tabref=lambda: self.home)
        self.window = SimpleNamespace(id=20, tabref=Mock(return_value=self.home))
        self.group = SimpleNamespace(dock=None)
        self.home.windows.group_for_window.return_value = self.group
        self.detached = SimpleNamespace(windows=(self.window,))
        self.home.detach_window.side_effect = self.detach_from_home
        self.parking.detach_window.return_value = self.detached
        self.manager = Mock()
        self.manager.__iter__ = Mock(side_effect=lambda: iter([]))
        self.manager.new_tab.return_value = self.parking
        self.boss = Mock(window_id_map={10: self.owner, 20: self.window},
                         os_window_map={1: self.manager})
        self.boss.suppress_focus_change_events.side_effect = nullcontext

    def detach_from_home(self, window):
        # Kitty discards the dock group when its windows are detached.
        self.group.dock = None
        return self.detached

    def toggle(self):
        # Kitty can reload the helper for every invocation; state must not rely
        # on module globals from the previous hide/restore call.
        load_helper().handle_result(['dock_toggle.py', '10', '20'], None, 10, self.boss)

    def check_round_trip(self, dock, reuse=False, overlays=False):
        if reuse:
            self.manager.__iter__.side_effect = lambda: iter([self.parking])
        overlay = SimpleNamespace(id=21)
        if overlays:
            self.detached.windows = (self.window, overlay)
        for cycle in range(2):
            self.group.dock = dock
            self.window.tabref.return_value = self.home
            self.toggle()
            self.assertIsNone(self.group.dock)
            self.assertIs(self.window._nvim_dock_spec, dock)
            self.parking.attach_windows.assert_called_with(self.detached)
            if cycle == 0:
                self.assertEqual(self.manager.new_tab.call_count, 0 if reuse else 1)
                # Subsequent hides share the existing parking tab.
                self.manager.__iter__.side_effect = lambda: iter([self.parking])
            self.window.tabref.return_value = self.parking
            self.toggle()
            self.home._take_ownership_of_window.assert_any_call(self.window)
            self.home._add_window.assert_any_call(self.window, dock=dock)
            restored = self.home._add_window.call_args_list[-2 if overlays else -1].kwargs['dock']
            self.assertIs(restored, dock)
            self.assertEqual(restored._asdict(), dock._asdict())
            if overlays:
                self.home._take_ownership_of_window.assert_any_call(overlay)
                self.assertEqual(self.home._add_window.call_args_list[-1],
                                 call(overlay, overlay_for=self.window.id))
            self.boss._cleanup_tab_after_window_removal.assert_called_with(self.parking)
        self.assertEqual(self.home.detach_window.call_count, 2)
        self.assertEqual(self.parking.detach_window.call_count, 2)
        self.assertEqual(self.boss.set_active_window.call_args_list, [call(self.owner)] * 4)

    def test_right_dock_round_trip(self):
        self.check_round_trip(DockSpec(edge='right', size=25, size_is_percent=True))

    def test_left_dock_round_trip(self):
        self.check_round_trip(DockSpec(edge='left', size=25, size_is_percent=True))

    def test_non_default_percent_size_and_reuse(self):
        self.check_round_trip(DockSpec(edge='left', size=37.5, size_is_percent=True), reuse=True)

    def test_cell_size_focusability_and_overlays(self):
        self.check_round_trip(DockSpec(edge='right', size=42, size_is_percent=False,
                                      focusable=False), overlays=True)

    def test_hide_requires_dock(self):
        with self.assertRaisesRegex(ValueError, 'Window is not a dock'):
            self.toggle()
        self.home.detach_window.assert_not_called()
        self.manager.new_tab.assert_not_called()

    def test_restore_requires_saved_specification(self):
        self.window.tabref.return_value = self.parking
        with self.assertRaisesRegex(ValueError, 'no saved dock specification'):
            self.toggle()
        self.parking.detach_window.assert_not_called()
        self.home._add_window.assert_not_called()

    def test_hide_recaptures_changed_specification(self):
        self.window._nvim_dock_spec = DockSpec(edge='right', size=25, size_is_percent=True)
        self.group.dock = updated = DockSpec(edge='left', size=60, size_is_percent=False)
        self.toggle()
        self.window.tabref.return_value = self.parking
        self.toggle()
        self.home._add_window.assert_called_once_with(self.window, dock=updated)


if __name__ == '__main__':
    unittest.main()
