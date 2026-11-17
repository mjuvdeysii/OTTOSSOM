import Foundation
import Testing
@testable import OTTOSSOM

struct MostoPersistenceTests {
    private func makeSim() -> DigSim {
        var sim = DigSim(world: DigWorld(seed: 3), upgrades: [:], seed: 7)
        sim.nestDone = true
        return sim
    }

    private func encoded(_ save: DigSave) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(save)
    }

    @Test func interruptedSharingRestoresBothBagsAndTheUsedTrip() throws {
        var sim = makeSim()
        sim.bag = Bag(gems: [.amber: 4, .blue: 2], trinkets: [.coin: 2])
        sim.p = V2(91.5, 240)
        sim.light = 37
        sim.deepest = 23
        sim.world.set(4, 12, .air)
        let shared = sim.shareWithMosto()
        #expect(shared)

        var save = DigSave()
        save.seen.insert("ending")
        save.progress = DigProgress(sim)
        let data = try encoded(save)
        let loaded = try JSONDecoder().decode(DigSave.self, from: data)
        let progress = try #require(loaded.progress)
        var restored = DigSim(world: loaded.world, upgrades: loaded.upgrades, seed: 7)
        restored.nestDone = loaded.seen.contains("ending")
        progress.restore(into: &restored)

        #expect(restored.nestDone)
        #expect(restored.bag == sim.bag)
        #expect(restored.sentBag == sim.sentBag)
        #expect(restored.p.x == sim.p.x)
        #expect(restored.p.y == sim.p.y)
        #expect(restored.light == sim.light)
        #expect(restored.deepest == sim.deepest)
        #expect(restored.world.cells == sim.world.cells)
        #expect(!restored.canShareWithMosto)
        let repeatShare = restored.shareWithMosto()
        #expect(!repeatShare)
    }

    @Test func legacyProgressWithoutSentBagRestoresAnUnusedTripAfterTheEnding() throws {
        var sim = makeSim()
        sim.bag = Bag(gems: [.amber: 4])
        var oldJSON = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(DigProgress(sim))) as? [String: Any])
        oldJSON.removeValue(forKey: "sentBag")
        oldJSON.removeValue(forKey: "atNest")
        let data = try JSONSerialization.data(withJSONObject: oldJSON)
        let progress = try JSONDecoder().decode(DigProgress.self, from: data)
        #expect(progress.sentBag == nil)
        #expect(progress.atNest == nil)

        var restored = makeSim()
        restored.sentBag = Bag(trinkets: [.coin: 1])
        restored.atNest = true
        progress.restore(into: &restored)
        #expect(restored.sentBag.count == 0)
        #expect(!restored.atNest)
        #expect(restored.canShareWithMosto)
        let shared = restored.shareWithMosto()
        #expect(shared)
        #expect(restored.sentBag.gems[.amber] == 2)
    }

    @Test func endingEncounterRoundTripKeepsSharingBlockedAfterTheEndingFlag() throws {
        var sim = makeSim()
        sim.atNest = true
        sim.bag = Bag(gems: [.amber: 4])
        var save = DigSave()
        save.seen.insert("ending")
        save.progress = DigProgress(sim)
        let loaded = try JSONDecoder().decode(DigSave.self, from: encoded(save))
        let progress = try #require(loaded.progress)
        #expect(progress.atNest == true)

        var restored = DigSim(world: loaded.world, upgrades: loaded.upgrades, seed: 7)
        restored.nestDone = loaded.seen.contains("ending")
        progress.restore(into: &restored)
        #expect(restored.nestDone)
        #expect(restored.atNest)
        #expect(restored.sentBag.count == 0)
        #expect(!restored.canShareWithMosto)
        let shared = restored.shareWithMosto()
        #expect(!shared)
        #expect(restored.bag == sim.bag)
    }

    @Test(arguments: [1, -1])
    func finishedNightSettlesCarriedAndSentFindsOnlyOnce(_ outcome: Int) throws {
        var sim = makeSim()
        sim.bag = Bag(gems: [.amber: 2, .blue: 1], trinkets: [.button: 1, .coin: 1])
        sim.sentBag = Bag(gems: [.amber: 3, .red: 1], trinkets: [.coin: 2, .cap: 1])
        sim.deepest = 41
        sim.world.set(4, 12, .air)
        sim.outcome = outcome
        var save = DigSave()
        save.coins = 7
        save.gems = [.amber: 1]
        save.trinkets = [.cap: 1]
        save.progress = DigProgress(sim)
        save.deepest = 19

        let reward = save.settleNight(sim)
        #expect(reward == 20)
        #expect(save.coins == 27)
        #expect(save.gems[.amber] == 6)
        #expect(save.gems[.blue] == 1)
        #expect(save.gems[.red] == 1)
        #expect(save.trinkets[.button] == 1)
        #expect(save.trinkets[.coin] == 3)
        #expect(save.trinkets[.cap] == 2)
        #expect(save.world.cells == sim.world.cells)
        #expect(save.deepest == 41)
        #expect(save.progress == nil)
        #expect(save.nightDone)

        let paid = try encoded(save)
        let duplicateReward = save.settleNight(sim)
        #expect(duplicateReward == nil)
        #expect(try encoded(save) == paid)
    }

    @Test func unfinishedNightCannotSettleOrClearItsProgress() throws {
        var sim = makeSim()
        sim.bag = Bag(gems: [.amber: 4])
        sim.sentBag = Bag(trinkets: [.coin: 2])
        sim.deepest = 55
        var save = DigSave()
        save.coins = 11
        save.progress = DigProgress(sim)
        let before = try encoded(save)
        let reward = save.settleNight(sim)
        #expect(reward == nil)
        #expect(try encoded(save) == before)
    }

    @Test func previouslySettledLegacySaveRejectsAnotherSettlement() throws {
        var oldSave = DigSave()
        oldSave.nightDone = true
        oldSave.coins = 17
        oldSave.gems = [.blue: 2]
        var oldJSON = try #require(JSONSerialization.jsonObject(with: encoded(oldSave)) as? [String: Any])
        oldJSON.removeValue(forKey: "townLamps")
        let oldData = try JSONSerialization.data(withJSONObject: oldJSON)
        var loaded = try JSONDecoder().decode(DigSave.self, from: oldData)
        #expect(loaded.nightDone)
        var sim = makeSim()
        sim.bag = Bag(gems: [.amber: 4])
        sim.sentBag = Bag(trinkets: [.coin: 2])
        sim.outcome = 1
        let before = try encoded(loaded)
        let reward = loaded.settleNight(sim)
        #expect(reward == nil)
        #expect(try encoded(loaded) == before)
    }
}
