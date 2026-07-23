local utils = require("heirline.utils")

-- Wrap one or more child components in a "floating" rounded pill:
--   left cap ()  ▐ children ▌  right cap ()
-- both caps are drawn in the pill's own colour over the (transparent) statusline
-- background, so the pill reads as a solid rounded chip regardless of the theme.
--
-- `bg` may be a colour name/hex OR a function(self) -> colour, so a pill can
-- follow the current vim mode (via the shared `mode_color` helper on the
-- statusline). Everything after `bg` is treated as a child component.
return function(bg, ...)
	return utils.surround({ "", "" }, bg, { ... })
end
