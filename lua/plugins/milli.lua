-- milli.nvim — animated ASCII splash art. milli is a STARTUP-splash tool with no
-- idle mode, so here it's repurposed as a SCREENSAVER: after IDLE_MS of no input
-- we paint an animation into a floating scratch buffer; any key dismisses it.
-- milli.play() takes (buf, opts), returns nothing, and self-stops when its buffer
-- is deleted (it guards every frame with nvim_buf_is_valid and reschedules via
-- vim.defer_fn) — so "dismiss" == wipe the buffer, no leaked timer.
--
-- On top of milli we add: a big ASCII clock drawn straight into the buffer (no
-- extra plugin, so it stays transparent and part of the same float), a cozy
-- message under the cat, and a transparent background (float Normal bg = NONE, so
-- your terminal/desktop shows through instead of an opaque block).
return {
	"Amansingh-afk/milli.nvim",
	event = "VeryLazy",
	config = function()
		local milli = require("milli")
		local uv = vim.uv or vim.loop

		-- Tweak to taste:
		--   IDLE_MS         = idle time (ms) before the saver appears
		--   FALLBACK_SPLASH = built-in used when no splash_hero.gif is baked yet
		--                     (bundled: fire, blackhole, finger, dancerramp, skeleton, vibecat)
		--   SHOW_CLOCK      = draw the big clock above the art
		--   CLOCK_FMT       = os.date format; only digits and ":" render as big glyphs
		--   WINBLEND        = float transparency: 0 = opaque, 100 = fully see-through.
		--                     Higher = your editor shows through more (art fades too).
		--   WIDTH           = ASCII columns when baking splash_hero.gif
		--   MAX_FRAMES      = cap baked frames; long GIFs are down-sampled (ffmpeg)
		--                     so the baked Lua stays small. 0 = keep every frame.
		--   NO_BG           = cut the dark background out of splash_hero so only the
		--                     subject shows over the transparent float
		--   BG_THRESHOLD    = how dark counts as "background" (0..1, luma-gated). Low
		--                     (~0.1) drops the black bg but keeps bright fills (e.g. a
		--                     yellow body); raise it to strip more, but too high erodes
		--                     the art's own dark parts (outlines/eyes). 1.0 = --no-bg
		--                     (strips ALL fills — usually not what you want).
		local IDLE_MS = 30000
		local FALLBACK_SPLASH = "vibecat"
		local SHOW_CLOCK = true
		local CLOCK_FMT = "%H:%M"
		local WINBLEND = 30
		local WIDTH = 80
		local MAX_FRAMES = 60
		local NO_BG = true
		local BG_THRESHOLD = 0.1
		-- KEY_EDGES: milli only luma-keys DARK backgrounds. To also cut a light/solid
		-- background, floodfill the border-connected background to black first (from the
		-- 4 corners) so the threshold can remove it. FUZZ = color tolerance (%).
		local KEY_EDGES = true
		local FUZZ = 25

		-- YOUR ANIME: drop/replace ~/.config/nvim/splash_hero.gif and it becomes the
		-- screensaver. milli can't read a GIF live, so we bake it to a Lua splash
		-- with the milli CLI whenever the GIF is newer than the last bake (async,
		-- gated on mtime — a no-op on normal startups). `:SplashRebuild` forces it.
		local cfg = vim.fn.stdpath("config")
		local HERO_GIF = cfg .. "/splash_hero.gif"
		local HERO_NAME = "splash_hero"
		local HERO_LUA = cfg .. "/lua/milli/splashes/" .. HERO_NAME .. ".lua"

		local function mtime(p)
			local st = uv.fs_stat(p)
			return st and st.mtime.sec or nil
		end

		-- Which splash the screensaver shows: an explicit :SplashUse choice wins,
		-- else the baked anime if present, else the bundled fallback. The :SplashUse
		-- choice is PERSISTED to a small state file, so it survives nvim restarts.
		local STATE = vim.fn.stdpath("data") .. "/milli_screensaver_splash"
		local function save_choice(name)
			if name then
				pcall(vim.fn.writefile, { name }, STATE)
			else
				pcall(vim.fn.delete, STATE) -- "auto" = no state file
			end
		end
		local function load_choice()
			if vim.fn.filereadable(STATE) == 1 then
				local name = (vim.fn.readfile(STATE) or {})[1]
				if name and name ~= "" and vim.tbl_contains(milli.list(), name) then
					return name -- ignore a saved name that no longer exists
				end
			end
			return nil
		end
		local splash_override = load_choice() -- restore last :SplashUse choice
		local function current_splash()
			return splash_override or (mtime(HERO_LUA) and HERO_NAME or FALLBACK_SPLASH)
		end

		-- Run an external command, calling back on the main loop.
		local function run(cmd, on_done)
			vim.system(cmd, { text = true }, vim.schedule_wrap(on_done))
		end

		-- no_bg_override: nil = use the NO_BG default, true/false = force per-rebuild.
		local function build_hero(force, no_bg_override)
			local gif_m = mtime(HERO_GIF)
			if not gif_m then
				return -- no source GIF; stay on FALLBACK_SPLASH
			end
			local lua_m = mtime(HERO_LUA)
			if not force and lua_m and lua_m >= gif_m then
				return -- bake already up to date
			end
			if vim.fn.executable("milli") == 0 then
				vim.notify(
					"splash_hero: milli CLI not found — install with `npm i -g @amansingh-afk/milli`",
					vim.log.levels.WARN
				)
				return
			end
			local out = vim.fn.stdpath("cache") .. "/milli_hero"
			vim.fn.mkdir(out, "p")
			vim.fn.mkdir(cfg .. "/lua/milli/splashes", "p")
			vim.notify(
				"splash_hero: baking splash_hero.gif… (screensaver uses the fallback until it's ready)",
				vim.log.levels.INFO
			)

			-- Background cut: an explicit :SplashRebuild arg wins over the NO_BG default.
			local cut = NO_BG
			if no_bg_override ~= nil then
				cut = no_bg_override
			end

			-- milli export <src> → out/frames.lua → copy into place. When cutting, the
			-- source is first edge-keyed (light bg → black) so the luma threshold works.
			local function export_from(src)
				local function do_export(gif)
					local args = { "milli", "export", gif, out, "-t", "lua", "-w", tostring(WIDTH) }
					if cut then
						-- luma-gated cutout: drop dark background, keep the bright subject.
						vim.list_extend(args, { "--bg-threshold", tostring(BG_THRESHOLD) })
					end
					run(args, function(res)
						if res.code ~= 0 then
							vim.notify("splash_hero build failed:\n" .. (res.stderr or res.stdout or ""), vim.log.levels.ERROR)
							return
						end
						if not uv.fs_copyfile(out .. "/frames.lua", HERO_LUA) then
							vim.notify("splash_hero: built but could not copy frames.lua", vim.log.levels.ERROR)
							return
						end
						package.loaded["milli.splashes." .. HERO_NAME] = nil -- drop stale require cache
						vim.notify("splash_hero baked from splash_hero.gif ✓ (idle to see it)", vim.log.levels.INFO)
					end)
				end

				-- Edge-key a light/solid background to black (from all 4 corners) so
				-- milli's dark-luma threshold can then remove it. Harmless on dark bgs.
				if cut and KEY_EDGES and vim.fn.executable("magick") == 1 then
					run({ "magick", "identify", "-format", "%w %h", src .. "[0]" }, function(idr)
						local ws, hs = (idr.stdout or ""):match("(%d+)%s+(%d+)")
						if not ws then
							do_export(src) -- no dimensions → skip keying, bake as-is
							return
						end
						local w, h = tonumber(ws) - 1, tonumber(hs) - 1
						local keyed = out .. "/keyed.gif"
						run({
							"magick", src, "-coalesce", "-fuzz", FUZZ .. "%", "-fill", "black",
							"-draw", "color 0,0 floodfill",
							"-draw", "color " .. w .. ",0 floodfill",
							"-draw", "color 0," .. h .. " floodfill",
							"-draw", "color " .. w .. "," .. h .. " floodfill",
							keyed,
						}, function(kr)
							do_export(kr.code == 0 and keyed or src)
						end)
					end)
				else
					do_export(src)
				end
			end

			-- Long GIFs bake into huge Lua files, so down-sample to MAX_FRAMES first
			-- (needs ffprobe+ffmpeg; without them, or MAX_FRAMES=0, bake every frame).
			local have_ffmpeg = vim.fn.executable("ffprobe") == 1 and vim.fn.executable("ffmpeg") == 1
			if not (MAX_FRAMES and MAX_FRAMES > 0 and have_ffmpeg) then
				if MAX_FRAMES and MAX_FRAMES > 0 and not have_ffmpeg then
					vim.notify("splash_hero: ffmpeg not found — baking every frame (larger file)", vim.log.levels.WARN)
				end
				export_from(HERO_GIF)
				return
			end

			run({
				"ffprobe", "-v", "error", "-select_streams", "v:0", "-count_frames",
				"-show_entries", "stream=nb_read_frames", "-of", "default=nk=1:nw=1", HERO_GIF,
			}, function(res)
				local n = tonumber((res.stdout or ""):match("%d+"))
				if not n or n <= MAX_FRAMES then
					export_from(HERO_GIF)
					return
				end
				local stride = math.ceil(n / MAX_FRAMES)
				local sampled = out .. "/sampled.gif"
				run({
					"ffmpeg", "-y", "-i", HERO_GIF,
					"-vf", "select=not(mod(n\\," .. stride .. ")),setpts=N/(15*TB)",
					"-loop", "0", sampled,
				}, function(fr)
					if fr.code ~= 0 then
						vim.notify("splash_hero: down-sample failed, baking full gif", vim.log.levels.WARN)
						export_from(HERO_GIF)
					else
						export_from(sampled)
					end
				end)
			end)
		end

		-- :SplashRebuild            → rebuild using the NO_BG default
		-- :SplashRebuild cut        → force background removal for this bake
		-- :SplashRebuild keep       → force keeping the background for this bake
		vim.api.nvim_create_user_command("SplashRebuild", function(o)
			local override = nil
			if o.args == "cut" then
				override = true
			elseif o.args == "keep" then
				override = false
			end
			build_hero(true, override)
		end, {
			nargs = "?",
			complete = function()
				return { "cut", "keep" }
			end,
			desc = "Rebuild screensaver splash from splash_hero.gif ([cut|keep] background)",
		})

		-- :SplashUse            → auto (your baked anime if present, else fallback)
		-- :SplashUse vibecat    → screensaver shows the bundled vibecat, etc.
		-- :SplashUse splash_hero→ back to your baked anime
		-- (tab-completes all bundled/baked names + "auto"; use :MilliPreview to peek)
		vim.api.nvim_create_user_command("SplashUse", function(o)
			local name = o.args
			if name == "" or name == "auto" then
				splash_override = nil
				save_choice(nil)
				vim.notify("screensaver splash: auto → " .. current_splash(), vim.log.levels.INFO)
				return
			end
			local names = milli.list()
			if not vim.tbl_contains(names, name) then
				vim.notify(
					"splash not found: " .. name .. "\navailable: " .. table.concat(names, ", "),
					vim.log.levels.WARN
				)
				return
			end
			splash_override = name
			save_choice(name)
			vim.notify("screensaver splash: " .. name .. " (saved)", vim.log.levels.INFO)
		end, {
			nargs = "?",
			complete = function()
				local names = milli.list()
				table.insert(names, 1, "auto")
				return names
			end,
			desc = "Pick which splash the screensaver shows (name, or 'auto')",
		})

		-- Cozy note shown under the cat. Edit freely; "" is a blank spacer line.
		local MESSAGE = {
			"let's chill out for a sec — step away from the code.",
			"stretch a little, unclench that jaw, take a breath. ☕",
			"your code will still be here when you're back (bugs and all).",
			"",
			"press any key when you're ready to dive back in. 🐾",
		}

		-- 5-row block glyphs for the clock. Each glyph's rows are equal width
		-- (digits = 5 cells, ":" = 3), so every assembled clock row lines up.
		local GLYPH = {
			["0"] = { "█████", "█   █", "█   █", "█   █", "█████" },
			["1"] = { "   █ ", "  ██ ", "   █ ", "   █ ", "  ███" },
			["2"] = { "█████", "    █", "█████", "█    ", "█████" },
			["3"] = { "█████", "    █", " ████", "    █", "█████" },
			["4"] = { "█   █", "█   █", "█████", "    █", "    █" },
			["5"] = { "█████", "█    ", "█████", "    █", "█████" },
			["6"] = { "█████", "█    ", "█████", "█   █", "█████" },
			["7"] = { "█████", "    █", "   █ ", "  █  ", "  █  " },
			["8"] = { "█████", "█   █", "█████", "█   █", "█████" },
			["9"] = { "█████", "█   █", "█████", "    █", "█████" },
			[":"] = { "   ", " █ ", "   ", " █ ", "   " },
		}
		local CLOCK_H = 5

		local msg_ns = vim.api.nvim_create_namespace("milli_screensaver_msg")
		local clock_ns = vim.api.nvim_create_namespace("milli_screensaver_clock")

		local timer = assert(uv.new_timer())
		local clock_timer = assert(uv.new_timer())
		local win, buf, clock_row
		local active = false
		local start_idle -- forward declaration

		local function close()
			if not active then
				return
			end
			active = false
			clock_timer:stop()
			pcall(vim.cmd, "stopinsert")
			if win and vim.api.nvim_win_is_valid(win) then
				pcall(vim.api.nvim_win_close, win, true)
			end
			if buf and vim.api.nvim_buf_is_valid(buf) then
				pcall(vim.api.nvim_buf_delete, buf, { force = true })
			end
			win, buf, clock_row = nil, nil, nil
			start_idle() -- resume watching for the next idle stretch
		end

		-- Don't cover an active terminal (e.g. the Claude chat), the cmdline, or a
		-- focus-mode break screen (see lua/core/focus.lua).
		local function skip()
			local mode = vim.api.nvim_get_mode().mode
			return mode:find("^[tc]") ~= nil or vim.bo.buftype == "terminal" or vim.g.focus_break_active == true
		end

		local function center(line, win_w)
			local w = vim.fn.strdisplaywidth(line)
			return string.rep(" ", math.max(0, math.floor((win_w - w) / 2))) .. line
		end

		-- Assemble the current time into CLOCK_H centered big-glyph rows.
		local function build_clock(win_w)
			local t = os.date(CLOCK_FMT)
			local rows = {}
			for r = 1, CLOCK_H do
				rows[r] = ""
			end
			for ci = 1, #t do
				local g = GLYPH[t:sub(ci, ci)]
				if g then
					for r = 1, CLOCK_H do
						rows[r] = rows[r] .. (rows[r] == "" and "" or " ") .. g[r]
					end
				end
			end
			local pad = string.rep(" ", math.max(0, math.floor((win_w - vim.fn.strdisplaywidth(rows[1])) / 2)))
			for r = 1, CLOCK_H do
				rows[r] = pad .. rows[r]
			end
			return rows
		end

		-- Repaint the clock into its reserved rows. Its own namespace + rows sit
		-- ABOVE the cat, so milli's per-frame repaint never touches them.
		local function paint_clock()
			if not active or not (buf and vim.api.nvim_buf_is_valid(buf)) or not clock_row then
				return
			end
			local rows = build_clock(vim.api.nvim_win_get_width(win))
			vim.bo[buf].modifiable = true
			pcall(vim.api.nvim_buf_set_lines, buf, clock_row, clock_row + CLOCK_H, false, rows)
			vim.bo[buf].modified = false
			vim.bo[buf].modifiable = false
			vim.api.nvim_buf_clear_namespace(buf, clock_ns, clock_row, clock_row + CLOCK_H)
			for r = 0, CLOCK_H - 1 do
				pcall(vim.api.nvim_buf_set_extmark, buf, clock_ns, clock_row + r, 0, {
					end_col = #rows[r + 1],
					hl_group = "MilliSaverClock",
				})
			end
		end

		-- milli.play() does NOT render the art itself — it searches the buffer for
		-- the splash's anchor (frame-0) line, then animates IN PLACE (only ever
		-- rewriting the cat's own rows). So we seed frame 0 (centered) FIRST — an
		-- empty buffer renders blank — reserve BLANK rows above for the clock (blank
		-- so milli's anchor search can't mistake them for the cat), and drop the
		-- MESSAGE below. The whole clock+cat+message stack is centered as one unit.
		local GAP = 2
		local function seed_frame0(data, win_w, win_h)
			local frame = data.frames[1]
			local cols = data.cols or 0
			if cols == 0 then
				for _, line in ipairs(frame) do
					cols = math.max(cols, vim.fn.strdisplaywidth(line))
				end
			end
			local clock_block = SHOW_CLOCK and (CLOCK_H + GAP) or 0
			local left_pad = math.max(0, math.floor((win_w - cols) / 2))
			local top_pad = math.max(0, math.floor((win_h - (clock_block + #frame + GAP + #MESSAGE)) / 2))
			local pad_str = string.rep(" ", left_pad)

			local lines = {}
			for _ = 1, top_pad do
				lines[#lines + 1] = ""
			end
			if SHOW_CLOCK then
				clock_row = #lines -- reserve CLOCK_H blank rows; paint_clock fills them
				for _ = 1, CLOCK_H + GAP do
					lines[#lines + 1] = ""
				end
			end
			for _, line in ipairs(frame) do
				lines[#lines + 1] = pad_str .. line
			end
			for _ = 1, GAP do
				lines[#lines + 1] = ""
			end
			local msg_start = #lines -- 0-indexed buffer row of the first MESSAGE line
			for _, line in ipairs(MESSAGE) do
				lines[#lines + 1] = line == "" and "" or center(line, win_w)
			end

			vim.bo[buf].modifiable = true
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
			vim.bo[buf].modified = false
			vim.bo[buf].modifiable = false

			-- Soft-highlight the message in its OWN namespace so milli's frame
			-- repaint (which only clears its ns over the cat's rows) can't touch it.
			vim.api.nvim_buf_clear_namespace(buf, msg_ns, 0, -1)
			for i, line in ipairs(MESSAGE) do
				if line ~= "" then
					local row = msg_start + i - 1
					pcall(vim.api.nvim_buf_set_extmark, buf, msg_ns, row, 0, {
						end_col = #lines[row + 1],
						hl_group = "Comment",
					})
				end
			end
		end

		local function open()
			if active or skip() then
				start_idle()
				return
			end
			active = true
			buf = vim.api.nvim_create_buf(false, true)
			vim.bo[buf].bufhidden = "wipe"
			local ui = vim.api.nvim_list_uis()[1]
			local ok, err = pcall(function()
				win = vim.api.nvim_open_win(buf, true, {
					relative = "editor",
					width = ui.width,
					height = ui.height,
					row = 0,
					col = 0,
					style = "minimal",
					focusable = true,
					zindex = 300,
				})
				-- Transparent overlay: winblend composites the float over the
				-- windows beneath, so your editor shows through instead of an
				-- opaque block; bg=NONE drops the fill so empty cells are cleanest
				-- (and go fully transparent if you also set kitty background_opacity).
				vim.api.nvim_set_hl(0, "MilliSaverBg", { bg = "none" })
				vim.api.nvim_set_hl(0, "MilliSaverClock", { link = "Special" })
				vim.wo[win].winhighlight = "Normal:MilliSaverBg,NormalFloat:MilliSaverBg,EndOfLine:MilliSaverBg"
				vim.wo[win].winblend = WINBLEND

				local splash = current_splash()
				local data = milli.load({ splash = splash })
				seed_frame0(data, vim.api.nvim_win_get_width(win), vim.api.nvim_win_get_height(win))
				milli.play(buf, { splash = splash, loop = true })
				if SHOW_CLOCK then
					clock_timer:start(0, 1000, vim.schedule_wrap(paint_clock)) -- tick every 1s
				end
			end)
			if not ok then
				vim.notify("milli screensaver: " .. tostring(err), vim.log.levels.WARN)
				close()
			end
		end

		start_idle = function()
			timer:stop()
			timer:start(IDLE_MS, 0, vim.schedule_wrap(open))
		end

		-- Any key is "activity": while the saver is up it dismisses it, otherwise
		-- it restarts the idle countdown. on_key sees EVERY keystroke, so this is a
		-- true no-input detector (CursorMoved alone would miss same-spot keys).
		vim.on_key(function()
			if active then
				vim.schedule(close)
			else
				start_idle()
			end
		end, vim.api.nvim_create_namespace("milli_screensaver"))

		-- Mouse-driven cursor moves / regaining window focus also count as activity.
		vim.api.nvim_create_autocmd({ "CursorMoved", "FocusGained" }, {
			group = vim.api.nvim_create_augroup("MilliScreensaver", { clear = true }),
			callback = function()
				if not active then
					start_idle()
				end
			end,
		})

		build_hero(false) -- bake splash_hero.gif now if it changed since last time
		start_idle()
	end,
}
