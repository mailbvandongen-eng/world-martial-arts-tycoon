-- Server entry point: creates remotes and starts the services in order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)

Remotes.setup()

local Services = script.Parent.Services
local DataService = require(Services.DataService)
local PlotService = require(Services.PlotService)
local PlayerService = require(Services.PlayerService)
local MonetizationService = require(Services.MonetizationService)
local LeaderboardService = require(Services.LeaderboardService)
local CosmeticService = require(Services.CosmeticService)
local ActionService = require(Services.ActionService)
local TournamentService = require(Services.TournamentService)

Players.CharacterAutoLoads = true

DataService.init()
PlotService.init()
MonetizationService.init()
CosmeticService.init()
LeaderboardService.init()
ActionService.init()
PlayerService.init() -- last: starts loading players and the game loop
TournamentService.init()

print("[WMAT] World Martial Arts Tycoon server started")
