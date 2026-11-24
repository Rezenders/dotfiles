<div align="center">
<img src="https://github.com/sxyazi/yazi/blob/main/assets/logo.png?raw=true" alt="Yazi logo" width="20%">
</div>

<h3 align="center">
	Gruvbox Light Flavor for <a href="https://github.com/sxyazi/yazi">Yazi</a>
</h3>

## Preview

<img src="https://github.com/Sh00Fly/gruvbox-light.yazi/blob/main/preview.png?raw=true" width="600" />

## Installation

```bash
ya pkg add Sh00Fly/gruvbox-light
```

## Usage

Add these lines to your `theme.toml`:

```toml
[flavor]
light = "gruvbox-light"
```

## Tip: keep icon colors on the hovered row

By default, yazi strips a file's `[icon]` style when the row is hovered, so the icon glyph gets re-styled with the row's `[filetype]` color — which makes the icons in this flavor turn dark on hover. To preserve icon colors on the hovered row, drop this into your `init.lua`:

```lua
function Entity:icon()
	local icon = self._file:icon()
	if not icon then
		return ""
	end
	return ui.Line(icon.text .. " "):style(icon.style)
end
```

This overrides yazi's built-in `Entity:icon` so `icon.style` is applied unconditionally.

## Credits

- `flavor.toml` derived from [bennyyip/gruvbox-dark.yazi](https://github.com/bennyyip/gruvbox-dark.yazi), with the palette inverted and bright accents swapped for faded variants per the [official Gruvbox palette](https://github.com/morhetz/gruvbox/wiki/Configuration#palette).
- `tmtheme.xml` is `gruvbox (Light) (Medium).tmTheme` from [ethe/gruvbox-sublime](https://github.com/ethe/gruvbox-sublime), originally by Brian Reilly ([Briles/gruvbox](https://github.com/Briles/gruvbox)), based on Pavel Pertsev's [gruvbox for Vim](https://github.com/morhetz/gruvbox).
- `[icon]` section adapted from yazi's preset [`theme-light.toml`](https://github.com/sxyazi/yazi/blob/main/yazi-config/preset/theme-light.toml), with icon colors retoned to the gruvbox palette.

## License

All components are MIT-licensed:

- [`LICENSE`](LICENSE) — this flavor's overall license (Sh00Fly).
- [`LICENSE-tmtheme`](LICENSE-tmtheme) — Brian Reilly's MIT, for the included `tmtheme.xml`.
- [`LICENSE-yazi`](LICENSE-yazi) — sxyazi's MIT, for the `[icon]` section adapted from yazi's preset `theme-light.toml`.
- [`LICENSE-flavor`](LICENSE-flavor) — Subhaditya Nath's MIT, for the `flavor.toml` structure derived from `bennyyip/gruvbox-dark.yazi`.
