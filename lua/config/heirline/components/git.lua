local conditions = require("heirline.conditions")
local icons = require("config.heirline.components.icons")

-- Git branch + working-tree diff counts:   <branch>  +a ~c -r
return {
	condition = conditions.is_git_repo,

	init = function(self)
		self.status_dict = vim.b.gitsigns_status_dict
		self.has_changes = self.status_dict.added ~= 0 or self.status_dict.removed ~= 0 or self.status_dict.changed ~= 0
	end,

	hl = { fg = "springGreen" },

	{ -- branch name with the git-branch logo
		provider = function(self)
			return icons.git_branch .. " " .. self.status_dict.head
		end,
		hl = { bold = true },
	},
	{ -- gap before the diff counts
		condition = function(self)
			return self.has_changes
		end,
		provider = "  ",
	},
	{
		provider = function(self)
			local count = self.status_dict.added or 0
			return count > 0 and ("+" .. count .. " ")
		end,
		hl = { fg = "autumnGreen" },
	},
	{
		provider = function(self)
			local count = self.status_dict.changed or 0
			return count > 0 and ("~" .. count .. " ")
		end,
		hl = { fg = "autumnYellow" },
	},
	{
		provider = function(self)
			local count = self.status_dict.removed or 0
			return count > 0 and ("-" .. count)
		end,
		hl = { fg = "autumnRed" },
	},
}
