import Foundation
@testable import MinMaxCalDomain
import Testing

@Test(arguments: [
    "https://zoom.us/my/planning", "https://example.zoomgov.com/j/123",
    "https://example.webex.com/meet/planning", "https://example.webex.com/join/planning",
    "https://example.webex.com/example/j.php?MTID=meeting", "https://whereby.com/planning",
])
func `conference links in notes reuse the shared detector`(address: String) throws {
    let url = try #require(URL(string: address))
    let link = try #require(JoinLinkDetector.detect(
        url: URL(string: "https://example.com/notes"),
        location: nil,
        notes: address,
    ))
    #expect(link.url == url)
    #expect(link.isConference)
}

@Test(arguments: [
    "https://example.com",
    "https://meet.google.com/",
    "https://whereby.com/",
    "https://example.webex.com/about",
    "https://zoom.us.example.com/j/123",
])
func `generic pages are not inferred conferences`(address: String) throws {
    let url = try #require(URL(string: address))
    #expect(JoinLinkDetector.classify(url)?.isConference == false)
}
