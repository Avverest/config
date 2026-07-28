local variants = function(s, m)
	return {
		standard = s,
		monitor = m,
	}
end

local sizes = {
	height = {
		iosevka = variants(1.0, 1.3),
		lilex = variants(1.3, 1.3),
	},
	size = {
		iosevka = variants(22, 22),
		lilex = variants(21, 18),
	},
}

return function(name, variant)
	local h = sizes.height[name][variant]
	local s = sizes.size[name][variant]
	local fonts = {
		iosevka = {
			family = "Iosevka Term",
			height = h,
			weight = 400,
			size = s,
		},
		lilex = {
			family = "Lilex",
			height = h,
			weight = 300,
			size = s
		},
		ibm = {
			family = "IBM Plex Sans",
			height = h,
			weight = 300,
			size = s
		},
	}
	return fonts[name]
end
