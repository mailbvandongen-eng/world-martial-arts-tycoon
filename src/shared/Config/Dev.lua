-- Developer access. Only these Roblox user ids (plus the experience owner and
-- anyone in Roblox Studio) get the developer menu. The server checks this for
-- every developer action; the client only uses it to show the button.

local Dev = {}

Dev.USER_IDS = {
	[11982556231] = true, -- Visunit66 (owner)
}

-- Ready-made test scenarios (applied to a sandboxed copy of your academy).
Dev.scenarios = {
	{ id = "new", name = "New player", text = "Fresh save: karate dojo, $300." },
	{ id = "early", name = "Early game", text = "Level 6, karate + boxing + judo, 4 rooms (Lv 2), lockers." },
	{ id = "mid", name = "Mid game", text = "Level 18, 4 cities, 10 rooms (Lv 3), rare trainers, mastery rank 4." },
	{ id = "late", name = "Late game", text = "Level 45, all cities, every room type (Lv 5), legendary trainers, max mastery." },
	{ id = "karate_full", name = "Full karate dojo", text = "Two Lv 5 karate dojos with legendary senseis, packed with students." },
	{ id = "tournament", name = "Tournament ready", text = "All disciplines unlocked with strong trainers, lots of cash." },
}

return Dev
