import Testing
@testable import OTTOSSOM

struct CompanionTests {
    @Test func shadowIdentityFollowsEvidenceRatherThanCollectionSize() {
        let start = DigStory.companions(memories: [], reunited: false)
        #expect(start.map(\.id) == ["m", "o"])
        let unrelated = DigStory.companions(memories: [1, 3, 4, 5, 7], reunited: false)
        #expect(unrelated.map(\.id) == ["m", "o"])
        let friend = DigStory.companions(memories: [2], reunited: false)
        #expect(friend.last?.name == "墙上的朋友")
        let thief = DigStory.companions(memories: [6], reunited: false)
        #expect(thief.last?.name == "戴王冠的影子")
        #expect(thief.last?.text.contains("借你一半") == false)
        let nest = DigStory.companions(memories: [8], reunited: false)
        #expect(nest.last?.name == "井底的小魔王")
    }

    @Test func endingUpdatesAllThreeCompanionsEvenOnAnOlderSave() {
        let cast = DigStory.companions(memories: [], reunited: true)
        #expect(cast.map(\.id) == ["m", "o", "x"])
        #expect(cast.last?.name == "莫斯托 · Mosto")
        #expect(cast.first?.text.contains("放下背包") == true)
        #expect(cast[1].text.contains("两个都回来") == true)
    }
}
