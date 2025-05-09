# python-lspconfig

This plugin can automatically configure `lspconfig` to use the right
`pythonPath` for `pyright` and `basedpyright`. Additionally you can opt to used
`python_path(dir)` if you just want a helper to determine the python interpreter
that should be used for this env.

Note that this plugin does not try and activate virtual envs, it just finds them
and configures the LSP. For my own use this seems to work well for the
monorepo setup we have at work.

If using lazy just add the following to get things autoatically configured.
`opts` can also contain a `on_new_config` key, which can be set to a
lsp+function to use as the `on_new_config` hook.

```lua
{ 'adamcik/python-lspconfig', opts = {} }
```

You just have to make sure this always runs before the LSP initialses. I've
misconfigured this myself which meant there was a race condition. But that was
a bug in my personal config, not to plugin.

Note that this depends on [plenary](https://github.com/nvim-lua/plenary.nvim) to
make handling files and paths way nicer. If you are using lazy this handled.

If you don't want to use the auto configuration, just omit opts and do something
like (just adapted to your config flavour / helpers).

```lua
local lspconfig = require('lspconfig')

lspconfig.basedpyright.setup({
  on_new_config = function(config, root)
    local python_path = require('python-lspconfig').python_path(root)
    if python_path and python_path ~= '' then
      config.settings.python.pythonPath = python_path
    end
  end
})
```

## Supported tools

- Explicitly set `VIRTUAL_ENV` or `CONDA_PREFIX`
- `uv`, just searching for `.venv` in nearest parent.
- `poetry` asking for the python executable.
- `pipenv` asking for the python executable.
- `pdm` asking for the python executable.
- Fallback, just looking for a venv in the directory.

I've only really tested `poetry` and the `uv` search variant. Hopefully the rest
work as expected.

## Inspiration

The following config/plugins helped with showing how to determine how to make
all this work:

- [github.com/jglasovic/venv-lsp.nvim](https://github.com/jglasovic/venv-lsp.nvim)
- [github.com/younger-1/nvim](https://github.com/younger-1/nvim/blob/6088053681928c1ab342f857622039f5d1db9498/lua/young/lang/python.lua)
