import Foundation
import MinMaxCalDomain
import Testing

struct JoinLinkDetectorTests {
    // MARK: Internal

    @Test
    func `builds a zoom web and app link with the passcode`() {
        let link = detect(url: "http://company.zoom.us/j/12345678901?pwd=abc.DEF_1-2&uname=x")
        #expect(link?.service == .zoom)
        #expect(link?.url.absoluteString == "https://company.zoom.us/j/12345678901?pwd=abc.DEF_1-2")
        #expect(link?.appURL?.absoluteString == "zoommtg://zoom.us/join?confno=12345678901&pwd=abc.DEF_1-2")
    }

    @Test
    func `drops an unsafe passcode`() {
        let link = detect(url: "https://zoom.us/j/123?pwd=a%20b%3Cscript%3E")
        #expect(link?.url.absoluteString == "https://zoom.us/j/123")
        #expect(link?.appURL?.absoluteString == "zoommtg://zoom.us/join?confno=123")
    }

    @Test
    func `canonicalises zoommtg links`() {
        let link = detect(notes: "Join: zoommtg://zoom.us/join?confno=987&pwd=x1 (from the app)")
        #expect(link?.url.absoluteString == "https://zoom.us/j/987?pwd=x1")
        #expect(link?.appURL?.absoluteString == "zoommtg://zoom.us/join?confno=987&pwd=x1")
    }

    @Test
    func `ignores zoom links without a numeric meeting`() {
        #expect(detect(url: "https://zoom.us/j/not-a-meeting")?.service == .other)
    }

    @Test
    func `recognises meet and jitsi`() {
        let meet = detect(location: "http://meet.google.com/abc-defg-hij")
        #expect(meet?.service == .meet)
        #expect(meet?.appURL == nil)
        #expect(meet?.url.absoluteString == "https://meet.google.com/abc-defg-hij")

        #expect(detect(notes: "https://meet.jit.si/Room")?.service == .jitsi)
        #expect(detect(notes: "https://jitsi.example.org/Room") == nil)
    }

    @Test
    func `builds teams web and app links from a classic link with its context`() {
        let context = "%7B%22Tid%22%3A%22t-1%22%2C%22Oid%22%3A%22o-1%22%7D"
        let sent = "http://teams.microsoft.com/l/meetup-join/19%3Ameeting_YWJj@thread.v2/0?context=\(context)&anon=true"
        let link = detect(notes: "Join: \(sent)")
        let rebuilt = "teams.microsoft.com/l/meetup-join/19:meeting_YWJj@thread.v2/0"
            + "?context=%7B%22Tid%22:%22t-1%22,%22Oid%22:%22o-1%22%7D"
        #expect(link?.service == .teams)
        #expect(link?.url.absoluteString == "https://\(rebuilt)")
        #expect(link?.appURL?.absoluteString == "msteams://\(rebuilt)")
    }

    @Test
    func `builds teams links from short and personal links with the passcode`() {
        let short = detect(url: "https://teams.microsoft.com/meet/9876543210?p=AbC1")
        #expect(short?.url.absoluteString == "https://teams.microsoft.com/meet/9876543210?p=AbC1")
        #expect(short?.appURL?.absoluteString == "msteams://teams.microsoft.com/meet/9876543210?p=AbC1")
        let personal = detect(url: "https://teams.live.com/meet/9876543210?p=a%20b")
        #expect(personal?.url.absoluteString == "https://teams.live.com/meet/9876543210")
        #expect(detect(url: "https://gov.teams.microsoft.us/meet/12")?.service == .teams)
    }

    @Test
    func `a teams link that is not a meeting or carries a bad context is not a call`() {
        #expect(detect(url: "https://teams.microsoft.com/l/channel/19%3Aabc@thread.tacv2/General")?.service == .other)
        #expect(detect(url: "https://teams.microsoft.com/l/meetup-join/19%3Aabc@thread.v2/x")?.service == .other)
        let link = detect(url: "https://teams.microsoft.com/l/meetup-join/19%3Aabc@thread.v2/0?context=%3Cscript%3E")
        #expect(link?.url.absoluteString == "https://teams.microsoft.com/l/meetup-join/19:abc@thread.v2/0")
    }

    @Test
    func `recognises facetime join links and keeps their fragment`() {
        let link = detect(location: "https://facetime.apple.com/join#v=1&p=abc&k=def")
        #expect(link?.service == .facetime)
        #expect(link?.appURL == nil)
        #expect(link?.url.absoluteString == "https://facetime.apple.com/join#v=1&p=abc&k=def")
        #expect(detect(url: "https://facetime.apple.com/")?.service == .other)
    }

    @Test
    func `prefers a call link over another link in an earlier field`() {
        let link = detect(url: "https://example.com/agenda", notes: "Dial in at https://meet.google.com/abc")
        #expect(link?.service == .meet)
    }

    @Test
    func `falls back to the event's own web address but never to a link in the text`() {
        let own = detect(url: "https://example.com/room", notes: "https://app.reclaim.ai/planner")
        #expect(own?.url.absoluteString == "https://example.com/room")
        #expect(own?.service == .other)
        #expect(detect(location: "See https://example.com/room", notes: "https://app.reclaim.ai/planner") == nil)
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

    private func detect(url: String? = nil, location: String? = nil, notes: String? = nil) -> JoinLink? {
        JoinLinkDetector.detect(url: url.flatMap(URL.init(string:)), location: location, notes: notes)
    }
}
