return function(w)
	return {
		{
			key = "+",
			mods = "LEADER",
			action = w.action.SplitVertical { domain = "CurrentPaneDomain" },
		},
		{
			key = "-",
			mods = "LEADER",
			action = w.action.SplitHorizontal { domain = "CurrentPaneDomain" },
		},

		{ key = 'h', mods = 'LEADER', action = w.action.ActivatePaneDirection "Left" },
    { key = 'l', mods = 'LEADER', action = w.action.ActivatePaneDirection "Right" },
    { key = 'k', mods = 'LEADER', action = w.action.ActivatePaneDirection "Up" },
    { key = 'j', mods = 'LEADER', action = w.action.ActivatePaneDirection "Down" },

    { key = 'q', mods = 'LEADER', action = w.action.CloseCurrentPane { confirm = true } },
	}
end
