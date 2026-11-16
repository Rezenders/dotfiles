"""Route regex hint selections through Kitty's open-actions.conf rules."""


def handle_result(args, data, target_window_id, boss, extra_cli_args, *unused):
    for match in data['match']:
        if match:
            # Omitting the program lets Kitty apply its URL-handling rules.
            boss.open_url(match)
