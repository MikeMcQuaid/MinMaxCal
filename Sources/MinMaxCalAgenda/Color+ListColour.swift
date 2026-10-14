import MinMaxCalDomain
import SwiftUI

extension Color {
    init(_ colour: ListColour) {
        self.init(red: colour.red, green: colour.green, blue: colour.blue, opacity: colour.alpha)
    }
}
