import SwiftUI
import UIKit

struct OpenSystemSettingsLink: View {
    var body: some View {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            Link("Open System Settings", destination: url)
        }
    }
}
