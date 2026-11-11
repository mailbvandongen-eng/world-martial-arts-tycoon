-- Missions (daily, weekly), the seasonal event and the objective guide.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Modules.Format)
local Formulas = require(Shared.Modules.Formulas)
local Quests = require(Shared.Config.Quests)
local Events = require(Shared.Config.Events)
local Cosmetics = require(Shared.Config.Cosmetics)

local Kit = require(script.Parent.Parent.Kit)
local State = require(script.Parent.Parent.Parent.Controllers.State)

local C = Kit.colors

local function questText(def, target, level)
	if def.scaleMoney then
		return string.format(def.text, Format.cash(target))
	end
	if string.find(def.text, "%%d") then
		return string.format(def.text, target)
	end
	return def.text
end

return {
	title = "Missions & Events",
	width = 820,
	height = 600,
	build = function(body, args, ui)
		local tab = args.tab or "daily"
		local scroll = Kit.scroll(body, { Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 1, -44) })
		Kit.list(scroll, 8)
		local function render()
			Kit.clear(scroll)
			local d, x = State.data, State.derived
			if tab == "daily" or tab == "weekly" then
				local list = tab == "daily" and d.quests.daily or d.quests.weekly
				Kit.label(scroll, tab == "daily" and "New daily missions every day at 00:00 UTC." or "Weekly missions reset every Monday 00:00 UTC.", { Size = UDim2.new(1, -8, 0, 24), TextColor3 = C.muted, TextSize = 14, LayoutOrder = 0 })
				for i, q in ipairs(list) do
					local def = Quests.byId[q.id]
					if def then
						local card = Kit.card(scroll, 78, i)
						Kit.label(card, questText(def, q.target, d.level), { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -240, 0, 24), TextSize = 17, Font = Kit.fontBlack })
						Kit.progress(card, q.progress / q.target, C.gold, { Position = UDim2.fromOffset(14, 40), Size = UDim2.new(1, -240, 0, 10) })
						local cash = math.floor(def.reward.cash * Formulas.rewardCashUnit(d.level))
						Kit.label(card, Format.short(q.progress) .. " / " .. Format.short(q.target) .. "   •   Reward " .. Format.cash(cash) .. " + ◆" .. (def.reward.gems or 0), { Position = UDim2.fromOffset(14, 52), Size = UDim2.new(1, -240, 0, 20), TextSize = 12, TextColor3 = C.muted })
						local done = q.progress >= q.target
						local b = Kit.button(card, q.claimed and "Claimed" or (done and "Claim" or "In progress"), function()
							local ok, res = ui.act("claimQuest", { period = tab, index = i })
							if ok then
								ui.cashPop("+" .. Format.cash(res.cash))
								ui.toast("Mission complete! +◆" .. res.gems)
							end
						end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(180, 44) }, done and not q.claimed and "good" or "dark")
						Kit.setEnabled(b, done and not q.claimed)
					end
				end
			elseif tab == "event" then
				local event = x.eventId and Events.byId[x.eventId]
				if not event then
					Kit.label(scroll, "No event right now.", { Size = UDim2.new(1, 0, 0, 30) })
					return
				end
				local points = (d.event.key == x.eventKey) and d.event.points or 0
				local head = Kit.card(scroll, 100, 0)
				Kit.stroke(head, Kit.c3(event.color), 2)
				Kit.label(head, event.name, { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 28), TextSize = 22, Font = Kit.fontBlack, TextColor3 = Kit.c3(event.color) })
				Kit.label(head, event.description .. "\nEvery class earns " .. Events.POINTS_PER_CLASS .. " event points. You have " .. Format.commas(points) .. " points.", { Position = UDim2.fromOffset(14, 40), Size = UDim2.new(1, -28, 0, 50), TextSize = 14, TextYAlignment = Enum.TextYAlignment.Top })
				for i, r in ipairs(event.rewards) do
					local card = Kit.card(scroll, 64, i)
					local name = r.cosmetic and (Cosmetics.byId[r.cosmetic] and Cosmetics.byId[r.cosmetic].name or r.cosmetic) or ("◆ " .. r.gems .. " gems")
					Kit.label(card, name .. "  (exclusive)", { Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -240, 0, 24), TextSize = 16, Font = Kit.fontBlack })
					Kit.progress(card, points / r.points, Kit.c3(event.color), { Position = UDim2.fromOffset(14, 38), Size = UDim2.new(1, -240, 0, 10) })
					local claimed = d.event.key == x.eventKey and d.event.claimed[tostring(i)]
					local b = Kit.button(card, claimed and "Claimed" or (Format.commas(r.points) .. " pts"), function()
						ui.act("claimEvent", { index = i }, "Event reward claimed!")
					end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(160, 40) }, "gold")
					Kit.setEnabled(b, not claimed and points >= r.points)
				end
			elseif tab == "guide" then
				for i, o in ipairs(Quests.objectives) do
					local current = x.objective and x.objective.index or (#Quests.objectives + 1)
					local done = i < current
					local card = Kit.card(scroll, 40, i)
					Kit.label(card, (done and "✔  " or (i == current and "➜  " or "•  ")) .. o.text, { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 1, 0), TextSize = 15, TextColor3 = done and C.good or (i == current and C.gold or C.muted) })
				end
			end
		end
		local _, select = Kit.tabs(body, {
			{ id = "daily", name = "Daily", width = 100 },
			{ id = "weekly", name = "Weekly", width = 100 },
			{ id = "event", name = "Event", width = 100 },
			{ id = "guide", name = "Guide", width = 100 },
		}, function(id)
			tab = id
			render()
		end)
		select(tab)
		return render
	end,
}
