import Foundation
import MinMaxCalDomain
import Testing

struct JoinLinkDetectorTests {
    // MARK: Internal

    @Test
    func `builds A zoom app link with the passcode`() {
        let link = detect(url: "https://company.zoom.us/j/12345678901?pwd=abc.DEF_1-2")
        #expect(link?.service == .zoom)
        #expect(link?.app == .zoom)
        #expect(link?.url.absoluteString == "zoommtg://zoom.us/join?confno=12345678901&pwd=abc.DEF_1-2")
    }

    @Test
    func `drops an unsafe passcode`() {
        let link = detect(url: "https://zoom.us/j/123?pwd=a%20b%3Cscript%3E")
        #expect(link?.url.absoluteString == "zoommtg://zoom.us/join?confno=123")
    }

    @Test
    func `canonicalises zoommtg links`() {
        let link = detect(notes: "Join: zoommtg://zoom.us/join?confno=987&pwd=x1 (from the app)")
        #expect(link?.url.absoluteString == "zoommtg://zoom.us/join?confno=987&pwd=x1")
    }

    @Test
    func `ignores zoom links without A numeric meeting`() {
        #expect(detect(url: "https://zoom.us/j/not-a-meeting")?.service == .other)
    }

    @Test
    func `routes meet and jitsi to edge`() {
        let meet = detect(location: "http://meet.google.com/abc-defg-hij")
        #expect(meet?.service == .meet)
        #expect(meet?.app == .edge)
        #expect(meet?.url.absoluteString == "https://meet.google.com/abc-defg-hij")

        #expect(detect(notes: "https://meet.jit.si/Room")?.service == .jitsi)
        #expect(detect(notes: "https://jitsi.example.org/Room")?.service == .jitsi)
        #expect(detect(notes: "https://jitsi.elsewhere.org/Room")?.service == .other)
    }

    @Test
    func `prefers A call link over another link in an earlier field`() {
        let link = detect(url: "https://example.com/agenda", notes: "Dial in at https://meet.google.com/abc")
        #expect(link?.service == .meet)
    }

    @Test
    func `falls back to the first web link in order`() {
        let link = detect(location: "See https://example.com/room", notes: "https://example.com/other")
        #expect(link?.url.absoluteString == "https://example.com/room")
        #expect(link?.app == .browser)
    }

    @Test
    func `never opens other schemes`() {
        #expect(detect(url: "file:///etc/passwd") == nil)
        #expect(detect(notes: "open mailto:someone@example.com or ftp://example.com/x") == nil)
    }

    @Test
    func `finds link ranges in text`() {
        let text = "Call https://example.com/a then zoommtg://zoom.us/join?confno=1"
        let links = JoinLinkDetector.links(in: text)
        #expect(links.map(\.url.absoluteString) == ["https://example.com/a", "zoommtg://zoom.us/join?confno=1"])
        #expect(links.map { String(text[$0.range]) } == ["https://example.com/a", "zoommtg://zoom.us/join?confno=1"])
    }

    // MARK: Private

    private let rules: MatchingRules = .init(genericTitles: [], jitsiHosts: ["jitsi.example.org"])

    private func detect(url: String? = nil, location: String? = nil, notes: String? = nil) -> JoinLink? {
        JoinLinkDetector.detect(url: url.flatMap(URL.init(string:)), location: location, notes: notes, rules: rules)
    }
}
