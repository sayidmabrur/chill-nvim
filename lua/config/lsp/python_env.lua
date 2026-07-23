-- Python interpreter / environment picker for the LSP (pyright).
-- Detects conda envs, virtualenvs and system pythons, lets you choose one, and
-- repoints pyright at it live (no restart) via workspace/didChangeConfiguration.
local M = {}

-- Return the python executable inside an env prefix, or nil if none.
local function py_of(prefix)
	for _, exe in ipairs({ "/bin/python", "/bin/python3" }) do
		local p = prefix .. exe
		if vim.fn.executable(p) == 1 then
			return p
		end
	end
	return nil
end

local function add(list, seen, name, python)
	if python and not seen[python] then
		seen[python] = true
		table.insert(list, { name = name, python = python })
	end
end

-- Gather candidate environments from every source we know about.
local function detect()
	local envs, seen = {}, {}

	-- conda via the CLI (authoritative: honours ~/.condarc, custom env dirs).
	if vim.fn.executable("conda") == 1 then
		local raw = table.concat(vim.fn.systemlist({ "conda", "env", "list", "--json" }), "\n")
		local ok, data = pcall(vim.json.decode, raw)
		if ok and type(data) == "table" and type(data.envs) == "table" then
			for _, prefix in ipairs(data.envs) do
				add(envs, seen, "conda: " .. vim.fn.fnamemodify(prefix, ":t"), py_of(prefix))
			end
		end
	end

	-- conda directory scan (fallback for when conda isn't on nvim's PATH).
	local home = vim.env.HOME or vim.fn.expand("~")
	for _, base in ipairs({
		home .. "/miniconda3/envs",
		home .. "/anaconda3/envs",
		home .. "/miniforge3/envs",
		home .. "/.conda/envs",
		vim.env.CONDA_ENVS_PATH,
	}) do
		if base and vim.fn.isdirectory(base) == 1 then
			for name, t in vim.fs.dir(base) do
				if t == "directory" then
					add(envs, seen, "conda: " .. name, py_of(base .. "/" .. name))
				end
			end
		end
	end

	-- active virtualenv + project-local venvs.
	if vim.env.VIRTUAL_ENV then
		add(envs, seen, "venv: " .. vim.fn.fnamemodify(vim.env.VIRTUAL_ENV, ":t"), py_of(vim.env.VIRTUAL_ENV))
	end
	local cwd = vim.fn.getcwd()
	for _, d in ipairs({ ".venv", "venv" }) do
		add(envs, seen, d, py_of(cwd .. "/" .. d))
	end

	-- system interpreters last.
	for _, exe in ipairs({ "python3", "python" }) do
		if vim.fn.executable(exe) == 1 then
			add(envs, seen, "system: " .. exe, vim.fn.exepath(exe))
		end
	end

	return envs
end

-- Point pyright at `python`: persist for future clients and push to running ones.
local function apply(python)
	local patch = { python = { pythonPath = python, defaultInterpreterPath = python } }

	-- future pyright clients (new buffers / restarts) pick this up.
	pcall(vim.lsp.config, "pyright", { settings = patch })

	local clients = vim.lsp.get_clients({ name = "pyright" })
	if #clients == 0 then
		vim.notify("pyright isn't attached yet — it will use\n" .. python .. "\nwhen it next starts.", vim.log.levels.WARN)
		return
	end
	for _, client in ipairs(clients) do
		client.settings = vim.tbl_deep_extend("force", client.settings or {}, patch)
		client:notify("workspace/didChangeConfiguration", { settings = client.settings })
	end
	vim.notify("Python LSP interpreter → " .. python, vim.log.levels.INFO)
end

function M.choose()
	local envs = detect()
	if #envs == 0 then
		vim.notify("No Python environments found (conda / venv / system).", vim.log.levels.WARN)
		return
	end
	vim.ui.select(envs, {
		prompt = "Python environment for pyright:",
		format_item = function(e)
			return e.name .. "  →  " .. e.python
		end,
	}, function(choice)
		if choice then
			apply(choice.python)
		end
	end)
end

return M
