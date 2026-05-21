# NeoVim dotfiles
This is my NeoVim configuration.

## Dependencies
- [NeoVim](https://neovim.io/) (>= 0.11 for agentic.nvim)
- [LazyGit](https://github.com/jesseduffield/lazygit)
- [LazyDocker](https://github.com/jesseduffield/lazydocker)

## AI assistant — agentic.nvim + Codex (no API key)

`agentic.nvim` is an ACP (Agent Client Protocol) chat client. It is wired to
**OpenAI Codex** through the `codex-acp` bridge, authenticating with the **ChatGPT
subscription** rather than an API key — so usage counts against the ChatGPT plan
quota and incurs **no per-token API charges**.

### One-time setup (fresh machine)

```sh
npm i -g @openai/codex             # Codex CLI
npm i -g @zed-industries/codex-acp # ACP bridge that agentic.nvim spawns
codex login                        # choose "Sign in with ChatGPT" — NOT an API key
```

`codex login` stores the OAuth session in `~/.codex/auth.json`; the bridge reads it
automatically. Optional image pasting needs `wl-clipboard` (Wayland) or `xclip` (X11).

> ⚠️ Do **not** set `OPENAI_API_KEY` in the `codex-acp` env (see
> `lua/plugins_neovim_only/agentic.lua`). A key silently switches Codex to
> pay-per-token API billing, defeating the subscription setup.

### Verify

```vim
:Lazy sync          " install agentic.nvim and its deps
:checkhealth agentic " confirms Neovim version + codex-acp availability
```

### Keys

| Key | Mode | Action |
| --- | --- | --- |
| `<C-\>` | n/v/i | Toggle the Agentic chat sidebar |
| `<C-'>` | n/v | Add current file / selection to context |
| `<C-,>` | n/v/i | Start a new session |

Inside the chat: `<S-Tab>` switch agent mode, `<localLeader>s` switch provider,
`<localLeader>m` switch model, `<CR>`/`<C-s>` submit, `q` close.
