local Path = require("plenary.path")
local scan = require("plenary.scandir")

local python_path_mem = {}

local function exec(opts)
    local result = vim.system(opts.cmd, { text = true, cwd = opts.cwd }):wait()
    return result.code == 0 and vim.fn.trim(result.stdout) or nil
end

local function path_to_python_path(path)
    return (path / "bin" / "python").filename
end

local function determine_python(root)
    if vim.env.VIRTUAL_ENV and vim.env.VIRTUAL_ENV ~= "" then
        return path_to_python_path(Path:new(vim.env.VIRTUAL_ENV))
    end

    if vim.env.CONDA_PREFIX and vim.env.CONDA_PREFIX ~= "" then
        return path_to_python_path(Path:new(vim.env.CONDA_PREFIX))
    end

    if (root / "uv.lock"):exists() then
        -- uv just searches for nearest .venv
        local venv = root:find_upwards(".venv")
        if venv then
            return path_to_python_path(venv)
        end
    end

    if (root / "poetry.lock"):exists() then
        local result = exec({ cmd = { "poetry", "env", "info", "--executable" }, cwd = root.filename })
        if result then
            return result
        end
    end

    if (root / "Pipfile"):exists() then
        local result = exec({ cmd = { "pipenv", "--py" }, cwd = root.filename })
        if result then
            return result
        end
    end

    if (root / "pdm.lock"):exists() then
        local result = exec({ cmd = { "pdm", "info", "--python" }, cwd = root.filename })
        if result then
            return result
        end
    end

    -- Fallback to any venv we can directly under root
    local opts = { hidden = true, depth = 2, search_pattern = "pyvenv.cfg" }
    for _, path in pairs(scan.scan_dir(root.filename, opts)) do
        return path_to_python_path(Path:new(path):parent())
    end
    return nil
end

local M = {}

M.python_path = function(dir)
    if not python_path_mem[dir] then
        local python = determine_python(Path:new(dir))
        if python and python ~= "" then
            python_path_mem[dir] = python
        end
    end
    return python_path_mem[dir]
end

local function determine_and_set_python_path(config, root)
    root = Path:new(root)

    local python = M.python_path(root)
    if python and python ~= "" then
        -- TODO: See if we need pep582 support with uv?
        -- config.settings.python.analysis.extraPaths = ...
        config.settings.python.pythonPath = python
    end

    local jj = root:find_upwards(".jj")
    if jj then
        --   config.settings.root_dir = jj:parent()
    end
end

-- Default on config mapping for (based)pyright
M.on_new_config = {
    pyright = determine_and_set_python_path,
    basedpyright = determine_and_set_python_path,
}

M.setup = function(opts)
    -- Load this locally to avoid import loops.
    local lspconfig = require("lspconfig")

    -- Merge whatever config user has provivded for `on_new_config`
    local on_new_config = vim.tbl_extend("force", M.on_new_config, opts.on_new_config or {})

    local original_on_setup = lspconfig.util.on_setup

    -- Instal setup and config hooks for the configured tools:
    lspconfig.util.on_setup = function(config, ...)
        if original_on_setup then
            original_on_setup(config, ...)
        end

        if on_new_config[config.name] then
            local original_on_new_config = config.on_new_config

            config.on_new_config = function(...)
                if original_on_new_config then
                    original_on_new_config(...)
                end
                on_new_config[config.name](...)
            end
        end
    end
end

return M
