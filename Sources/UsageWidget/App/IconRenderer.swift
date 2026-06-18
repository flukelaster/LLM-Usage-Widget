#if DEBUG
import SwiftUI
import AppKit

/// DEBUG-only: render the app icon (SwiftUI) to a 1024×1024 PNG via `UsageWidget --icon <path>`.
/// `Scripts/make_icon.sh` turns that PNG into AppIcon.icns.
@MainActor
enum IconRenderer {
    static func renderSync(outputPath: String) {
        let renderer = ImageRenderer(content: AppIconView().frame(width: 1024, height: 1024))
        renderer.scale = 1.0
        guard let cgImage = renderer.cgImage else {
            FileHandle.standardError.write(Data("icon: render failed\n".utf8)); exit(1)
        }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("icon: encode failed\n".utf8)); exit(1)
        }
        do {
            try data.write(to: URL(fileURLWithPath: outputPath))
            print("icon: wrote \(outputPath) (\(cgImage.width)x\(cgImage.height))")
        } catch {
            FileHandle.standardError.write(Data("icon: write failed: \(error)\n".utf8)); exit(1)
        }
    }
}

/// The app icon: a dark squircle with a green→amber→red usage gauge (echoing the limit bars).
struct AppIconView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#243049"), Color(hex: "#0B1120")],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 185, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 3)
                )
                .frame(width: 824, height: 824)
                .shadow(color: .black.opacity(0.35), radius: 36, y: 18)

            gauge.frame(width: 470, height: 470)
        }
        .frame(width: 1024, height: 1024)
    }

    private var gauge: some View {
        ZStack {
            // Track (3/4 ring, gap at the bottom).
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Color.white.opacity(0.10), style: StrokeStyle(lineWidth: 96, lineCap: .round))
                .rotationEffect(.degrees(135))

            // Filled portion (~70%), green → amber → red.
            Circle()
                .trim(from: 0, to: 0.75 * 0.70)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "#32D74B"), Color(hex: "#FFD60A"),
                            Color(hex: "#FF9F0A"), Color(hex: "#FF453A")
                        ]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 96, lineCap: .round)
                )
                .rotationEffect(.degrees(135))
                .shadow(color: Color(hex: "#FF9F0A").opacity(0.35), radius: 24)
        }
    }
}
#endif
