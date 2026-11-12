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
    "https://luma.com/join/g-testMeeting123",
    "https://zoom-lfx.platform.linuxfoundation.org/meeting/12345678901"
        + "?password=00000000-0000-0000-0000-000000000001",
], ["url", "location", "notes"])
func `redirected conference links preserve their web URL`(address: String, field: String) throws {
    let url = try #require(URL(string: address))
    let link = try #require(JoinLinkDetector.detect(
        url: field == "url" ? url : URL(string: "https://example.com/notes"),
        location: field == "location" ? "Join: \(address)" : nil,
        notes: field == "notes" ? "Join: \(address)" : nil,
    ))
    #expect(link.url == url)
    #expect(link.service == .other)
    #expect(link.appURL == nil)
    #expect(link.isConference)
}

@Test(arguments: [
    "https://example.com",
    "https://meet.google.com/",
    "https://whereby.com/",
    "https://example.webex.com/about",
    "https://zoom.us.example.com/j/123",
    "https://luma.com/",
    "https://luma.com/join/",
    "https://luma.com/join/g-",
    "https://luma.com/join/g-testMeeting123/other",
    "https://luma.com.example.com/join/g-testMeeting123",
    "https://user@luma.com/join/g-testMeeting123",
    "https://zoom-lfx.platform.linuxfoundation.org/",
    "https://zoom-lfx.platform.linuxfoundation.org/meeting/",
    "https://zoom-lfx.platform.linuxfoundation.org/meeting/not-a-meeting",
    "https://zoom-lfx.platform.linuxfoundation.org/meeting/123/other",
    "https://zoom-lfx.platform.linuxfoundation.org.example.com/meeting/123",
    "https://user@zoom-lfx.platform.linuxfoundation.org/meeting/123",
])
func `generic pages are not inferred conferences`(address: String) throws {
    let url = try #require(URL(string: address))
    #expect(JoinLinkDetector.classify(url)?.isConference == false)
}
