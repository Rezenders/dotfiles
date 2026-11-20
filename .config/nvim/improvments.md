## 4. Make external AI edits easy to notice and review

Pi and Claude run outside Neovim and can change files while you are looking at them. I would explicitly test this workflow:

1. Open a file in Neovim.
2. Have the external agent modify it.
3. Return to the editor.
4. Verify that the buffer updates—or clearly reports a conflict if you have unsaved edits.

If updates are not reliably detected, add **`:checktime` on appropriate focus/buffer-entry events**:

- **`FocusGained`** checks when Neovim receives focus again.
- **`BufEnter`** checks when returning to a buffer.

Neovim already has automatic-reload behavior; this is about ensuring checks happen reliably in your Kitty workflow, not blindly setting another option.

**Do not use forced reloads such as `:edit!`.** Unsaved local edits must remain protected.

You already have Diffview and Gitsigns, so I would also make “review everything the agent changed” a habitual step using `<leader>gd`, rather than add another review plugin.

