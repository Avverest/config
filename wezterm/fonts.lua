local MONITOR_DISPLAY_SIZE = "monitor"
local STANDARD_DISPLAY_SIZE = "standard"
local IPAD_DISPLAY_SIZE = "ipad"

Fonts = {}
Fonts.iosevka = "Iosevka Term"
Fonts.lilex = "Lilex"
Fonts.jb = "JetBrainsMono Nerd Font Mono"
Fonts.ibm = "IBM Plex Sans"

local variants = function(s, m, i)
	return {
		[STANDARD_DISPLAY_SIZE] = s,
		[MONITOR_DISPLAY_SIZE] = m,
		[IPAD_DISPLAY_SIZE] = i,
	}
end

local height = {
	[Fonts.iosevka] = variants(1.0, 1.1, 1.0),
	[Fonts.lilex] = variants(1.0, 1.1, 1.2),
	[Fonts.jb] = variants(1.3, 1.1, 1.0),
}
local size = {
	[Fonts.iosevka] = variants(22, 23, 22),
	[Fonts.lilex] = variants(19, 22, 20),
	[Fonts.jb] = variants(21, 20, 18),
}

local font = function(fontName, weight, variant)
	local h = height[fontName][variant]
	local s = size[fontName][variant]
	return { family = fontName, height = h, weight = weight, size = s }
end

Fonts.monitor = function(name, weight)
	return font(name, weight, MONITOR_DISPLAY_SIZE)
end

Fonts.standard = function(name, weight)
	return font(name, weight, STANDARD_DISPLAY_SIZE)
end

Fonts.ipad = function(name, weight)
	return font(name, weight, IPAD_DISPLAY_SIZE)
end

return Fonts
