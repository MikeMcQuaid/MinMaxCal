import MinMaxCalDomain
import Testing

struct ListColourTests {
    @Test
    func `vivid pulls brightness into the band and keeps the hue's ordering`() {
        let paleYellow = ListColour(red: 0.98, green: 0.95, blue: 0.6)
        let dimmed = paleYellow.vivid
        #expect(max(dimmed.red, dimmed.green, dimmed.blue) < 0.9)
        #expect(dimmed.red > dimmed.blue)
        #expect(dimmed.green > dimmed.blue)

        let darkBlue = ListColour(red: 0.05, green: 0.1, blue: 0.4)
        let brightened = darkBlue.vivid
        #expect(max(brightened.red, brightened.green, brightened.blue) > 0.7)
        #expect(brightened.blue > brightened.green)
        #expect(brightened.green > brightened.red)
    }

    @Test
    func `vivid deepens the saturation without going negative`() {
        let washed = ListColour(red: 0.8, green: 0.7, blue: 0.75)
        let vivid = washed.vivid
        let chroma = max(vivid.red, vivid.green, vivid.blue) - min(vivid.red, vivid.green, vivid.blue)
        let original = 0.8 - 0.7
        #expect(chroma > original)
        #expect(min(vivid.red, vivid.green, vivid.blue) >= 0)
    }

    @Test
    func `grey stays grey`() {
        let vivid = ListColour.grey.vivid
        #expect(abs(vivid.red - vivid.green) < 0.001)
        #expect(abs(vivid.green - vivid.blue) < 0.001)
    }
}
