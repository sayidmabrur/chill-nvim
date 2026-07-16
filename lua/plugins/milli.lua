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
		--   IDLE_MS    = idle time (ms) before the saver appears
		--   SPLASH     = any name from `:MilliPreview` / require("milli").list()
		--                (bundled: fire, blackhole, finger, dancerramp, skeleton, vibecat)
		--   SHOW_CLOCK = draw the big clock above the cat
		--   CLOCK_FMT  = os.date format; only digits and ":" render as big glyphs
		--   WINBLEND   = float transparency: 0 = opaque, 100 = fully see-through.
		--                Higher = your editor shows through more (art fades too).
		local IDLE_MS = 30000
		local SPLASH = "vibecat"
		local SHOW_CLOCK = true
		local CLOCK_FMT = "%H:%M"
		local WINBLEND = 30

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

		-- Don't cover an active terminal (e.g. the Claude chat) or the cmdline.
		local function skip()
			local mode = vim.api.nvim_get_mode().mode
			return mode:find("^[tc]") ~= nil or vim.bo.buftype == "terminal"
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

				local data = milli.load({ splash = SPLASH })
				seed_frame0(data, vim.api.nvim_win_get_width(win), vim.api.nvim_win_get_height(win))
				milli.play(buf, { splash = SPLASH, loop = true })
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

		start_idle()
	end,
}
