-- Classic clothing (Shirt / Pants) for player outfits. Values are the asset
-- ids of the uploaded images (assets/clothing/*.png, uploaded with
-- tools/upload_clothing.py, which rewrites this file). 0 = not uploaded yet:
-- the outfit then falls back to the simple overlay parts.

local Clothing = {
	karate_gi_white_belt_shirt = 79846280210665,
	karate_gi_black_belt_shirt = 91721752139025,
	karate_gi_red_belt_shirt = 135937316267945,
	karate_gi_pants = 93505456550867,
	judogi_black_belt_shirt = 101817452756573,
	bjj_gi_black_belt_shirt = 109599752837309,
	dobok_black_belt_shirt = 120618499487154,
	kungfu_shirt = 82570870024283,
	kungfu_pants = 107554647842253,
	boxing_shorts_red = 77828958336417,
	boxing_shorts_gold = 114818626381168,
	muaythai_shorts_red = 85557580921197,
	muaythai_shorts_gold = 120995452338000,
	mma_rashguard = 126582522043759,
	mma_shorts = 98761211223232,
	mawashi_navy = 107164289576239,
	mawashi_gold = 134984380261855,
	owner_suit_shirt = 129595799290395,
	owner_suit_pants = 86391144592379,
}

return Clothing
