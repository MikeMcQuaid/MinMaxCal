import Foundation
@testable import MinMaxCalFeatures
import Testing

struct LinkedTextTests {
    // MARK: Internal

    @Test
    func `plain notes keep their text and get their web links`() {
        let text = LinkedText.attributed("Agenda: https://example.com/agenda and zoommtg://zoom.us/join?confno=1")

        #expect(String(text.characters) == "Agenda: https://example.com/agenda and zoommtg://zoom.us/join?confno=1")
        #expect(links(in: text) == ["https://example.com/agenda"])
    }

    @Test
    func `html notes are reduced to text with their anchors`() {
        let html = "<p>Join <a href=\"https://example.com/room\">the room</a> or <b>call</b>.<br>"
            + "See https://example.com/docs</p>"

        let text = LinkedText.attributed(html)

        #expect(String(text.characters).contains("Join the room or call."))
        #expect(String(text.characters).hasSuffix("docs"))
        #expect(String(LinkedText.attributed("<p>One</p><p></p><br>\n").characters) == "One")
        #expect(String(text.characters).contains("<") == false)
        #expect(links(in: text) == ["https://example.com/room", "https://example.com/docs"])
    }

    @Test
    func `html never keeps unsafe links or resources`() {
        let html = "<a href=\"javascript:alert(1)\">x</a> <img src=\"https://example.com/track.gif\">"
            + " <a href=\"file:///etc/passwd\">y</a>"

        let text = LinkedText.attributed(html)

        #expect(links(in: text).isEmpty)
        #expect(String(LinkedText.attributed("<style>b{color:red}</style><script>x()</script>Hi").characters) == "Hi")
        #expect(LinkedText.looksLikeHTML(html))
        #expect(LinkedText.looksLikeHTML("a < b and c > d") == false)
    }

    // MARK: Private

    private func links(in text: AttributedString) -> [String] {
        text.runs.compactMap { $0.link?.absoluteString }
    }
}
