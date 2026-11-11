-- Business statistics: balance, hourly and daily earnings, expenses, net
-- profit, members, reputation, satisfaction, plus lifetime statistics.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Modules.Format)
local Progression = require(Shared.Config.Progression)
local Cities = require(Shared.Config.Cities)

local Kit = require(script.Parent.Parent.Kit)
local State = require(script.Parent.Parent.Parent.Controllers.State)

local C = Kit.colors

local function tile(parent, order, title, value, color, sub)
	local f = Kit.frame(parent, { BackgroundColor3 = C.panel2, LayoutOrder = order })
	Kit.corner(f, 10)
	Kit.label(f, title, { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 16), TextSize = 12, TextColor3 = C.muted })
	Kit.label(f, value, { Position = UDim2.fromOffset(12, 26), Size = UDim2.new(1, -24, 0, 32), TextSize = 26, Font = Kit.fontBlack, TextColor3 = color or C.text })
	if sub then
		Kit.label(f, sub, { Position = UDim2.fromOffset(12, 60), Size = UDim2.new(1, -24, 0, 16), TextSize = 11, TextColor3 = C.muted })
	end
end

return {
	title = "Statistics",
	width = 880,
	height = 600,
	build = function(body)
		local scroll = Kit.scroll(body, { Size = UDim2.fromScale(1, 1) })
		Kit.grid(scroll, UDim2.fromOffset(200, 86), 10)
		local function render()
			Kit.clear(scroll)
			local d, x = State.data, State.derived
			local dayFactor = 3600 / Progression.DAY_SECONDS
			local expHour = x.expenses.total * dayFactor
			local s = d.stats
			tile(scroll, 1, "BALANCE", Format.cash(d.cash), C.cash)
			tile(scroll, 2, "EARNINGS / HOUR (last 5 min)", Format.cash(x.hourly), C.cash)
			tile(scroll, 3, "ESTIMATED / HOUR (all academies)", Format.cash(x.hourlyEstimate), C.cash, "used for offline earnings")
			tile(scroll, 4, "EARNED TODAY (UTC)", Format.cash(x.today), C.cash)
			tile(scroll, 5, "EXPENSES / HOUR", Format.cash(expHour), C.bad, "rent + salaries + maintenance")
			tile(scroll, 6, "NET PROFIT / HOUR", Format.cash(x.hourly - expHour), (x.hourly - expHour) >= 0 and C.good or C.bad)
			tile(scroll, 7, "ACTIVE MEMBERS", Format.commas(x.members), C.text, "pay dues every business day")
			tile(scroll, 8, "REPUTATION", Format.short(d.reputation), C.rep)
			tile(scroll, 9, "AVG SATISFACTION", x.avgSatisfaction and (math.floor(x.avgSatisfaction) .. "%") or "—", (x.avgSatisfaction or 70) >= 70 and C.good or C.bad)
			tile(scroll, 10, "CLASS CAPACITY", tostring(x.capacity), C.text, Cities.byId[d.activeCity].name)
			tile(scroll, 11, "VISITORS LOST", Format.commas(x.lostTotal), C.bad, "see Academy > Business")
			tile(scroll, 12, "REGISTER", Format.cash(d.register) .. " / " .. Format.cash(x.registerCap), C.cash)
			tile(scroll, 13, "STUDENTS SERVED", Format.commas(s.studentsServed))
			tile(scroll, 14, "CLASSES COMPLETED", Format.commas(s.classesCompleted))
			tile(scroll, 15, "LIFETIME EARNINGS", Format.cash(s.totalEarned), C.cash)
			tile(scroll, 16, "ROOMS BUILT / UPGRADED", s.roomsBuilt .. " / " .. s.roomsUpgraded)
			tile(scroll, 17, "TRAINERS HIRED", Format.commas(s.trainersHired))
			tile(scroll, 18, "CHAMPIONSHIPS", Format.commas(s.championships))
			tile(scroll, 19, "DISCIPLINES MASTERED", tostring(x.masteredCount))
			tile(scroll, 20, "REBIRTHS", tostring(d.rebirths), C.gold, d.flags.prestigeTitle)
			tile(scroll, 21, "PLAY TIME", Format.time(s.playSeconds))
			tile(scroll, 22, "ACADEMY RATING", d.ratings.count > 0 and string.format("%.1f ★ (%d)", d.ratings.sum / d.ratings.count, d.ratings.count) or "—", C.gold)
			if x.memoryMode then
				tile(scroll, 0, "⚠ STUDIO MODE", "Not saving", C.bad, "Enable API access to test saving")
			end
		end
		render()
		return render
	end,
}
