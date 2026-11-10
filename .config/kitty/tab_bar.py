from datetime import datetime
from glob import glob
from socket import gethostname
from zoneinfo import ZoneInfo

from kitty.boss import get_boss
from kitty.fast_data_types import Screen, add_timer
from kitty.tab_bar import (
    DrawData,
    ExtraData,
    Formatter,
    TabBarData,
    as_rgb,
    draw_attributed_string,
    draw_title,
)
from kitty.utils import color_as_int

# Machine marker at the far left: flame on the personal machine ('beast'), ship on work.
# Written as escapes so the Nerd Font glyphs can't be lost by editors/tools.
MACHINE_ICON = "" if gethostname() == "beast" else ""  # nf-oct-flame / nf-fa-ship
ICON = f" {MACHINE_ICON} "
RIGHT_MARGIN = 1
# Seconds between forced redraws, so the clock and battery stay current.
REFRESH_TIME = 15

# Nerd Font battery glyphs: 10%, 20%, ... 90%, full; and the charging glyph.
BATTERY_LEVELS = [
    "\U000f007a",
    "\U000f007b",
    "\U000f007c",
    "\U000f007d",
    "\U000f007e",
    "\U000f007f",
    "\U000f0080",
    "\U000f0081",
    "\U000f0082",
    "\U000f0079",
]
BATTERY_CHARGING = "\U000f0084"

timer_id = None


def _rgb(color) -> int:
    return as_rgb(color_as_int(color))


def _redraw_tab_bar(_timer_id) -> None:
    tm = get_boss().active_tab_manager
    if tm is not None:
        tm.mark_tab_bar_dirty()


def _battery() -> str:
    """Battery glyph and percentage, or '' on machines without a battery."""
    for path in sorted(glob("/sys/class/power_supply/BAT*")):
        try:
            with open(f"{path}/capacity") as f:
                capacity = int(f.read())
            with open(f"{path}/status") as f:
                status = f.read().strip()
        except (OSError, ValueError):
            continue
        if status == "Charging":
            icon = BATTERY_CHARGING
        else:
            # Nearest 10% step: 82% -> 80% glyph, 100% -> full.
            icon = BATTERY_LEVELS[max(0, min(round(capacity / 10) - 1, 9))]
        return f"{icon} {capacity}%  "
    return ""


def _draw_icon(draw_data: DrawData, screen: Screen, index: int) -> int:
    if index != 1:
        return 0

    fg = screen.cursor.fg
    screen.cursor.fg = _rgb(draw_data.active_fg)
    screen.draw(ICON)
    screen.cursor.fg = fg
    screen.cursor.x = len(ICON)
    return screen.cursor.x


def _draw_left_status(
    draw_data: DrawData,
    screen: Screen,
    tab: TabBarData,
    before: int,
    max_title_length: int,
    index: int,
    is_last: bool,
    extra_data: ExtraData,
) -> int:
    if draw_data.leading_spaces:
        screen.draw(" " * draw_data.leading_spaces)

    draw_title(draw_data, screen, tab, index)
    trailing_spaces = min(max_title_length - 1, draw_data.trailing_spaces)
    max_title_length -= trailing_spaces
    extra = screen.cursor.x - before - max_title_length
    if extra > 0:
        screen.cursor.x -= extra + 1
        screen.draw("…")
    if trailing_spaces:
        screen.draw(" " * trailing_spaces)
    end = screen.cursor.x
    screen.cursor.bold = screen.cursor.italic = False
    screen.cursor.fg = 0
    if not is_last:
        screen.cursor.bg = _rgb(draw_data.inactive_bg)
        screen.draw(draw_data.sep)
    screen.cursor.bg = 0
    return end


# more handy kitty tab_bar things:
# REF: https://github.com/kovidgoyal/kitty/discussions/4447#discussioncomment-2183440
def _draw_right_status(draw_data: DrawData, screen: Screen, is_last: bool) -> int:
    if not is_last:
        return 0

    draw_attributed_string(Formatter.reset, screen)

    clock = datetime.now().strftime("%H:%M")
    nl_time = datetime.now(ZoneInfo("Europe/Amsterdam")).strftime(" (NL %H:%M)")

    # (colour, text): colours come from the active theme's tab colours.
    cells = [
        (_rgb(draw_data.inactive_fg), _battery()),
        (_rgb(draw_data.active_fg), clock),
        (_rgb(draw_data.inactive_fg), nl_time),
    ]

    right_status_length = RIGHT_MARGIN
    for _, text in cells:
        right_status_length += len(text)

    draw_spaces = screen.columns - screen.cursor.x - right_status_length
    if draw_spaces > 0:
        screen.draw(" " * draw_spaces)

    for color, text in cells:
        screen.cursor.fg = color
        screen.draw(text)
    screen.cursor.fg = 0
    screen.cursor.bg = 0

    if screen.columns - screen.cursor.x > right_status_length:
        screen.cursor.x = screen.columns - right_status_length

    return screen.cursor.x


def draw_tab(
    draw_data: DrawData,
    screen: Screen,
    tab: TabBarData,
    before: int,
    max_title_length: int,
    index: int,
    is_last: bool,
    extra_data: ExtraData,
) -> int:
    global timer_id
    if timer_id is None:
        timer_id = add_timer(_redraw_tab_bar, REFRESH_TIME, True)

    _draw_icon(draw_data, screen, index)
    _draw_left_status(
        draw_data,
        screen,
        tab,
        before,
        max_title_length,
        index,
        is_last,
        extra_data,
    )
    _draw_right_status(draw_data, screen, is_last)

    return screen.cursor.x
