-- milli.nvim — animated ASCII splash art. milli is a STARTUP-splash tool with no
-- idle mode, so here it's repurposed as a SCREENSAVER: after IDLE_MS of no input
-- we paint an animation into a fullscreen floating scratch buffer; any key
-- dismisses it. milli.play() takes (buf, opts), returns nothing, and self-stops
-- when its buffer is deleted (it guards every frame with nvim_buf_is_valid and
-- reschedules via vim.defer_fn) — so "dismiss" == wipe the buffer, no leaked timer.
return {
	"Amansingh-afk/milli.nvim",
	event = "VeryLazy",
	config = function()
		local milli = require("milli")
		local uv = vim.uv or vim.loop

		-- Tweak to taste:
		--   IDLE_MS = idle time (ms) before the saver appears
		--   SPLASH  = any name from `:MilliPreview` / require("milli").list()
		--             (bundled: fire, blackhole, finger, dancerramp, skeleton, vibecat)
		local IDLE_MS = 30000
		local SPLASH = "vibecat"

		-- Cozy note shown under the cat. Edit freely; "" is a blank spacer line.
		local MESSAGE = {
			"let's chill out for a sec — step away from the code.",
			"stretch a little, unclench that jaw, take a breath. ☕",
			"your code will still be here when you're back (bugs and all).",
			"",
			"press any key when you're ready to dive back in. 🐾",
		}
		local msg_ns = vim.api.nvim_create_namespace("milli_screensaver_msg")

		local timer = assert(uv.new_timer())
		local win, buf
		local active = false
		local start_idle -- forward declaration

		local function close()
			if not active then
				return
			end
			active = false
			pcall(vim.cmd, "stopinsert")
			if win and vim.api.nvim_win_is_valid(win) then
				pcall(vim.api.nvim_win_close, win, true)
			end
			if buf and vim.api.nvim_buf_is_valid(buf) then
				pcall(vim.api.nvim_buf_delete, buf, { force = true })
			end
			win, buf = nil, nil
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

		-- milli.play() does NOT render the art itself — it searches the buffer for
		-- the splash's anchor (frame-0) line, then animates IN PLACE (it only ever
		-- rewrites the cat's own rows). So we seed frame 0 (centered) into the
		-- buffer FIRST — an empty buffer renders blank — and drop the MESSAGE a
		-- couple rows BELOW the cat, where milli's per-frame repaint never reaches.
		-- The whole cat+gap+message block is centered vertically as one unit.
		local GAP = 2
		local function seed_frame0(data, win_w, win_h)
			local frame = data.frames[1]
			local cols = data.cols or 0
			if cols == 0 then
				for _, line in ipairs(frame) do
					cols = math.max(cols, vim.fn.strdisplaywidth(line))
				end
			end
			local left_pad = math.max(0, math.floor((win_w - cols) / 2))
			local top_pad = math.max(0, math.floor((win_h - (#frame + GAP + #MESSAGE)) / 2))
			local pad_str = string.rep(" ", left_pad)
			local lines = {}
			for _ = 1, top_pad do
				lines[#lines + 1] = ""
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
				local data = milli.load({ splash = SPLASH })
				seed_frame0(data, vim.api.nvim_win_get_width(win), vim.api.nvim_win_get_height(win))
				milli.play(buf, { splash = SPLASH, loop = true })
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
