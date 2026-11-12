-- Classic clothing (Shirt / Pants) for player outfits. Values are the asset
-- ids of the uploaded images (assets/clothing/*.png, uploaded with
-- tools/upload_clothing.py, which rewrites this file). 0 = not uploaded yet:
-- the outfit then falls back to the simple overlay parts.

local Clothing = {
	karate_gi_white_belt_shirt = 0,
	karate_gi_black_belt_shirt = 0,
	karate_gi_red_belt_shirt = 0,
	karate_gi_pants = 0,
	judogi_black_belt_shirt = 0,
	bjj_gi_black_belt_shirt = 0,
	dobok_black_belt_shirt = 0,
	kungfu_shirt = 0,
	kungfu_pants = 0,
	boxing_shorts_red = 0,
	boxing_shorts_gold = 0,
	muaythai_shorts_red = 0,
	muaythai_shorts_gold = 0,
	mma_rashguard = 0,
	mma_shorts = 0,
	mawashi_navy = 0,
	mawashi_gold = 0,
	owner_suit_shirt = 0,
	owner_suit_pants = 0,
}

return Clothing
