-- Receipt idempotency for Developer Products. A PurchaseId is granted at most
-- once. Three layers: this server's memory, the player's save (recent ids),
-- and the permanent receipt DataStore (checked by MonetizationService before
-- calling process).

local ReceiptLedger = {}

function ReceiptLedger.new()
	return { granted = {} }
end

function ReceiptLedger.seen(ledger, d, receiptId)
	if ledger.granted[receiptId] then
		return true
	end
	for _, id in ipairs(d.purchases.receipts) do
		if id == receiptId then
			return true
		end
	end
	return false
end

-- grantFn() must return ok. Returns "granted", "duplicate" or "failed".
function ReceiptLedger.process(ledger, d, receiptId, grantFn)
	if type(receiptId) ~= "string" or receiptId == "" then
		return "failed"
	end
	if ReceiptLedger.seen(ledger, d, receiptId) then
		return "duplicate"
	end
	local ok = grantFn()
	if not ok then
		return "failed"
	end
	ledger.granted[receiptId] = true
	table.insert(d.purchases.receipts, receiptId)
	while #d.purchases.receipts > 50 do
		table.remove(d.purchases.receipts, 1)
	end
	return "granted"
end

return ReceiptLedger
