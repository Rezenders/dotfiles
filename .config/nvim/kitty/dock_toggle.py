"""Park/restore an existing Neovim dock without stopping its child process.

Uses Kitty's internal tab APIs because detach-window does not restore DockSpec.
Invoked by init.lua through `kitten @ kitten /absolute/path/to/this/file`.
"""
from kittens.tui.handler import result_handler


def main(args):
    pass


@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss):
    owner_id, dock_id = map(int, args[1:3])
    owner = boss.window_id_map.get(owner_id)
    window = boss.window_id_map.get(dock_id)
    if owner is None or window is None:
        raise ValueError('Neovim or dock window no longer exists')
    home = owner.tabref()
    source = window.tabref()
    if home is None or source is None:
        raise ValueError('Neovim or dock tab no longer exists')

    with boss.suppress_focus_change_events():
        if source is home:
            group = source.windows.group_for_window(window)
            if group is None or group.dock is None:
                raise ValueError('Window is not a dock')
            # Detaching drops the group's DockSpec. Keep it on the live window
            # so it survives separate kitten invocations without global state.
            window._nvim_dock_spec = group.dock
            # Share a parking tab between this Neovim's Pi and Claude windows.
            title = f'NVIM docks [{owner_id}]'
            manager = boss.os_window_map[home.os_window_id]
            parking = next((tab for tab in manager if tab.name == title), None)
            if parking is None:
                parking = manager.new_tab(empty_tab=True, title=title)
            parking.attach_windows(source.detach_window(window))
        else:
            # A parked dock is an ordinary window. Restore its full DockSpec,
            # including edge, size units, and focusability.
            dock = getattr(window, '_nvim_dock_spec', None)
            if dock is None:
                raise ValueError('Parked window has no saved dock specification')
            detached = source.detach_window(window)
            for index, item in enumerate(detached.windows):
                home._take_ownership_of_window(item)
                if index == 0:
                    home._add_window(item, dock=dock)
                else:
                    home._add_window(item, overlay_for=window.id)
            boss._cleanup_tab_after_window_removal(source)
        boss.set_active_window(owner)
