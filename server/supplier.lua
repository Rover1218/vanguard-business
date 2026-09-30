-- Vanguard Business - supplier orders: paid from the business account, delivered to the fridge.

Router.on('order', function(src, data)
    local ctx, err = Access.atStation(src, data.stationId, { kind = 'boss', permission = 'supplier' })
    if not ctx then return Router.fail(err) end
    local business = ctx.business

    local total, lines = Rules.cartTotal(Types.catalog(business.type), data.cart, Config.MaxPacksPerLine)
    if not total then return Router.fail(lines) end
    if not Businesses.adjust(business.id, -total) then
        return Router.fail(('The business can\'t afford this order ($%d)'):format(total))
    end

    local stashId = Businesses.stashId(business.id)
    local refund, failed, summary = 0, {}, {}
    for _, line in ipairs(lines) do
        if Bridge.addItem(stashId, line.item, line.amount) then
            summary[#summary + 1] = ('%dx %s'):format(line.amount, Types.itemLabel(line.item))
        else
            refund = refund + line.cost
            failed[#failed + 1] = Types.itemLabel(line.item)
        end
    end
    if refund > 0 then Businesses.adjust(business.id, refund) end

    local spent = total - refund
    if spent > 0 then
        Businesses.log(business.id, 'order', -spent, Bridge.characterName(src), table.concat(summary, ', '):sub(1, 160))
    end
    if #failed == #lines then return Router.fail('Nothing fitted in the fridge - the order was refunded') end
    if #failed > 0 then
        return Router.ok(('Delivered to the fridge. Refunded (no room or unknown item): %s'):format(table.concat(failed, ', ')))
    end
    return Router.ok(('Order delivered to the fridge ($%d)'):format(spent))
end)
