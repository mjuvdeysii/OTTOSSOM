import Foundation
import Testing
@testable import OTTOSSOM

struct TownLampTests {
    private struct Exchange: Equatable {
        let coins: Int
        let gems: [Gem: Int]
        let orders: [Order]
        let lit: [String]?
        let town: [String: TownLamp]?

        init(_ save: DigSave) {
            coins = save.coins; gems = save.gems; orders = save.orders
            lit = save.lit; town = save.townLamps
        }
    }

    @Test func deliveriesKeepTheLatestLampAndCountWithoutRemovingShelfColors() throws {
        var save = DigSave()
        save.gems = [.amber: 2, .blue: 1]
        save.openShop()
        let first = try #require(save.orders.first { $0.who == "h" })
        let firstDelivered = save.light(first, with: [.amber])
        #expect(firstDelivered)
        #expect(save.townLamps?["h"] == TownLamp(color: .amber, deliveries: 1, day: 1))

        save.day = 2
        let second = Order(id: save.nextOrder, who: "h", color: .green, since: 2)
        save.nextOrder += 1
        save.orders.append(second)
        let secondDelivered = save.light(second, with: [.blue, .amber])
        #expect(secondDelivered)
        #expect(save.townLamps?["h"] == TownLamp(color: .green, deliveries: 2, day: 2))
        #expect(save.coins == first.pay + second.pay)
        #expect(save.gems[.amber] == 0)
        #expect(save.gems[.blue] == 0)
        #expect(Set(save.lit ?? []) == Set(["amber", "green"]))

        save.day = 6
        save.openShop()
        #expect(save.townLamps?["h"] == TownLamp(color: .green, deliveries: 2, day: 2))
    }

    @Test func rejectedOrdersHaveNoSideEffects() throws {
        var save = DigSave()
        save.gems = [.amber: 1, .blue: 1]
        save.openShop()
        let live = try #require(save.orders.first)
        let before = Exchange(save)
        let wrongColorDelivered = save.light(live, with: [.blue])
        #expect(!wrongColorDelivered)
        #expect(Exchange(save) == before)

        var forged = live
        forged.who = "t3"
        let wrongCustomerDelivered = save.light(forged, with: [.amber])
        #expect(!wrongCustomerDelivered)
        #expect(Exchange(save) == before)
        forged = live
        forged.color = .blue
        let forgedColorDelivered = save.light(forged, with: [.blue])
        #expect(!forgedColorDelivered)
        #expect(Exchange(save) == before)
        forged = live
        forged.since = 0
        let forgedDateDelivered = save.light(forged, with: [.amber])
        #expect(!forgedDateDelivered)
        #expect(Exchange(save) == before)

        save.day = 4
        let expiredDelivered = save.light(live, with: [.amber])
        #expect(!expiredDelivered)
        #expect(Exchange(save) == before)
    }

    @Test func insufficientCrystalsCannotPartiallyConsumeARecipe() {
        var save = DigSave()
        let order = Order(id: 0, who: "n", color: .green, since: 1)
        save.orders = [order]
        save.gems = [.amber: 1]
        let before = Exchange(save)
        let insufficientDelivered = save.light(order, with: [.amber, .blue])
        #expect(!insufficientDelivered)
        #expect(Exchange(save) == before)
    }

    @Test func fulfilledOrUnknownOrdersCannotBePaidAgain() throws {
        var save = DigSave()
        save.gems = [.amber: 3]
        save.openShop()
        let order = try #require(save.orders.first)
        let delivered = save.light(order, with: [.amber])
        #expect(delivered)
        let paid = Exchange(save)
        let deliveredAgain = save.light(order, with: [.amber])
        #expect(!deliveredAgain)
        #expect(Exchange(save) == paid)
        let unknown = Order(id: 100, who: "h", color: .amber, since: 1)
        let unknownDelivered = save.light(unknown, with: [.amber])
        #expect(!unknownDelivered)
        #expect(Exchange(save) == paid)
    }

    @Test func townLampsRoundTripAndOlderSavesDecodeWithoutThem() throws {
        var save = DigSave()
        save.coins = 23
        save.townLamps = ["d": TownLamp(color: .purple, deliveries: 2, day: 3)]
        let data = try JSONEncoder().encode(save)
        let restored = try JSONDecoder().decode(DigSave.self, from: data)
        #expect(restored.townLamps == save.townLamps)
        #expect(restored.coins == 23)

        var oldJSON = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        oldJSON.removeValue(forKey: "townLamps")
        let oldData = try JSONSerialization.data(withJSONObject: oldJSON)
        let oldSave = try JSONDecoder().decode(DigSave.self, from: oldData)
        #expect(oldSave.townLamps == nil)
        #expect(oldSave.coins == 23)
    }
}
