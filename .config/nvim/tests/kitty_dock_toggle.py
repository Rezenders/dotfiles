"""Run with: kitty +runpy 'import runpy; runpy.run_path("tests/kitty_dock_toggle.py", run_name="__main__")'"""
import importlib.util
from contextlib import nullcontext
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock

spec = importlib.util.spec_from_file_location(
    'dock_toggle', Path(__file__).resolve().parents[1] / 'kitty/dock_toggle.py')
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


def check_toggle(parked=False, reuse=False):
    home = Mock(os_window_id=1)
    parking = Mock()
    parking.name = 'NVIM docks [10]'
    owner = Mock()
    owner.tabref.return_value = home
    window = Mock(id=20)
    source = parking if parked else home
    window.tabref.return_value = source
    source.detach_window.return_value = SimpleNamespace(windows=(window,))
    manager = Mock()
    manager.__iter__ = Mock(return_value=iter([parking] if reuse else []))
    manager.new_tab.return_value = parking
    boss = Mock(window_id_map={10: owner, 20: window}, os_window_map={1: manager})
    boss.suppress_focus_change_events.side_effect = nullcontext
    helper.handle_result(['dock_toggle.py', '10', '20'], None, 10, boss)
    source.detach_window.assert_called_once_with(window)
    boss.set_active_window.assert_called_once_with(owner)
    if parked:
        home._take_ownership_of_window.assert_called_once_with(window)
        dock = home._add_window.call_args.kwargs['dock']
        assert (dock.edge, dock.size, dock.size_is_percent) == ('right', 25, True)
        boss._cleanup_tab_after_window_removal.assert_called_once_with(parking)
    else:
        parking.attach_windows.assert_called_once()
        assert manager.new_tab.call_count == (0 if reuse else 1)


check_toggle()
check_toggle(reuse=True)
check_toggle(parked=True)
print('Kitty dock helper: park, reuse parking tab, and restore tests passed')
