import Testing
@testable import OTTOSSOM

struct MostoShareTests {
    private enum Blocker: CaseIterable {
        case notReunited, cameHome, lightOut, endingEncounter, emptyBag, oneItem, alreadySent
    }

    private func readySim() -> DigSim {
        var sim = DigSim(world: DigWorld(seed: 1), upgrades: [:], seed: 2)
        sim.nestDone = true
        sim.bag.gems = [.amber: 2]
        sim.greedTimer = 4
        return sim
    }

    @Test(arguments: Blocker.allCases)
    private func blockedSharingLeavesBothBagsAndGreedUnchanged(_ blocker: Blocker) {
        var sim = readySim()
        switch blocker {
        case .notReunited: sim.nestDone = false
        case .cameHome: sim.outcome = 1
        case .lightOut: sim.outcome = -1
        case .endingEncounter: sim.atNest = true
        case .emptyBag: sim.bag = Bag()
        case .oneItem: sim.bag.gems = [.amber: 1]
        case .alreadySent: sim.sentBag.trinkets = [.coin: 1]
        }
        let carried = sim.bag, sent = sim.sentBag
        #expect(!sim.canShareWithMosto)
        let shared = sim.shareWithMosto()
        #expect(!shared)
        #expect(sim.bag == carried)
        #expect(sim.sentBag == sent)
        #expect(sim.greedTimer == 4)
    }

    @Test func oddMixedBagSharesHalfInStableOrderAndConservesEveryItem() {
        var sim = readySim()
        sim.bag = Bag(gems: [.amber: 1, .blue: 1, .red: 1], trinkets: [.button: 2, .coin: 3, .cap: 1])
        let before = sim.bag
        #expect(sim.canShareWithMosto)
        let shared = sim.shareWithMosto()
        #expect(shared)
        #expect(sim.sentBag.count == 4)
        #expect(sim.bag.count == 5)
        #expect(sim.sentBag.gems == [.amber: 1, .blue: 1, .red: 1])
        #expect(sim.sentBag.trinkets == [.button: 1])
        for gem in Gem.allCases {
            #expect((sim.bag.gems[gem] ?? 0) + (sim.sentBag.gems[gem] ?? 0) == (before.gems[gem] ?? 0))
        }
        for trinket in Trinket.allCases {
            #expect((sim.bag.trinkets[trinket] ?? 0) + (sim.sentBag.trinkets[trinket] ?? 0) == (before.trinkets[trinket] ?? 0))
        }
    }

    @Test func sharingMakesRoomWithoutChangingCapacityOrOtherNightState() {
        var sim = readySim()
        sim.bag.gems = [.amber: sim.capacity]
        let capacity = sim.capacity, light = sim.light
        let shared = sim.shareWithMosto()
        #expect(shared)
        #expect(sim.bag.count == capacity / 2)
        #expect(sim.capacity == capacity)
        #expect(sim.light == light)
        #expect(sim.outcome == 0)
        #expect(sim.events.isEmpty)
        #expect(sim.greedTimer == 0)
    }

    @Test func sentBagPreventsASecondDeliveryEvenAfterMoreFinds() {
        var sim = readySim()
        let first = sim.shareWithMosto()
        #expect(first)
        sim.bag.gems[.blue] = 4
        sim.greedTimer = 3
        let carried = sim.bag, sent = sim.sentBag
        let second = sim.shareWithMosto()
        #expect(!second)
        #expect(!sim.canShareWithMosto)
        #expect(sim.bag == carried)
        #expect(sim.sentBag == sent)
        #expect(sim.greedTimer == 3)
    }

    @Test func sentBagSurvivesLightOutWhileMossLosesHalfHerRemainder() {
        var sim = readySim()
        sim.bag.gems = [.amber: 8]
        let shared = sim.shareWithMosto()
        #expect(shared)
        let sent = sim.sentBag
        sim.started = true
        sim.light = 0.001
        sim.shades = []
        sim.step(0.1)
        #expect(sim.outcome == -1)
        #expect(sim.bag.gems[.amber] == 2)
        #expect(sim.sentBag == sent)
        #expect(sim.sentBag.gems[.amber] == 4)
    }

    @Test func reelingInKeepsBothBags() {
        var sim = readySim()
        sim.bag.trinkets = [.coin: 2]
        let shared = sim.shareWithMosto()
        #expect(shared)
        let carried = sim.bag, sent = sim.sentBag
        sim.reelIn()
        #expect(sim.outcome == 1)
        #expect(sim.bag == carried)
        #expect(sim.sentBag == sent)
        let afterHome = sim.shareWithMosto()
        #expect(!afterHome)
    }

    @Test func halfOfSingletonKindsUsesTotalCountAndLeavesSmallBagsUntouched() {
        var mixed = Bag(gems: [.amber: 1, .blue: 1], trinkets: [.coin: 1])
        let sent = mixed.takeHalf()
        #expect(sent.count == 1)
        #expect(sent.gems[.amber] == 1)
        #expect(mixed.count == 2)
        var one = Bag(trinkets: [.cap: 1])
        let original = one
        let none = one.takeHalf()
        #expect(none.count == 0)
        #expect(one == original)
    }
}
