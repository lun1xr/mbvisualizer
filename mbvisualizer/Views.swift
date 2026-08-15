//
//  ContentView.swift
//  mbvisualizer
//
//  Created by Stephen Paul on 8/7/26.
//

import SwiftUI
import CoreAudio
import Accelerate
import Cocoa

public class Defaults {
    static let AUDIODATAPATH: String = ""
    static let COREAUDIOENABLED: Bool = true
    static let BARCOUNT: Int = 10
    static let DECAY: Double = 0.1
    static let ATTACK: Double = 0.9
    static let CIELING: Double = 1.0
    static let WIDTH: Int = 50
    static let SEPERATORWIDTH: Int = 1
    static let GRADIENTCOLORS: [StringColor] = [StringColor(hexstring: "#FFFFFF")]
    static let GRADSTART: String = "top"
    static let GRADEND: String = "bottom"
}

struct SettingsView: View {
    @AppStorage("AudioDataPath") var audioDataPath: String = ""
    @AppStorage("CoreAudioEnabled") var coreAudioEnabled: Bool = true
    @AppStorage("BarCount") var barCount: Int = 10
    @AppStorage("Decay") var decay: Double = 0.1
    @AppStorage("Attack") var attack: Double = 0.9
    @AppStorage("Cieling") var cieling: Double = 1.0
    @AppStorage("Width") var width: Int = 50
    @AppStorage("SeperatorWidth") var seperatorWidth: Int = 1
    @AppStorage("GradientColors") var gradientColors: String = "#FFFFFF"
    @AppStorage("GradientStart") var gradStart: String = "top"
    @AppStorage("GradientEnd") var gradEnd: String = "bottom"
    @FocusState var focusedField
    @State var gradientColorArray: [StringColor] = []
    let startEndOptions: [String] = [
        "top",
        "bottom",
        "leading",
        "trailing",
        "topLeading",
        "topTrailing",
        "bottomLeading",
        "bottomTrailing"
    ]
    var body: some View {
        VStack(alignment: .leading) {
            Text("Audio Visualizer Settings")
                .font(.title)
                .padding(.horizontal)
            Text("v0.1.0 - Nonfunctional features: socket")
                .font(.caption)
                .padding(.horizontal)
            List {
                Section("Appearance") {
                    HStack {
                        Text("Bar Count: ")
                            .frame(minWidth: 120, alignment: .leading)
                        TextField("#bars", value: $barCount, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .overlay(alignment: .trailing) {
                                if barCount != Defaults.BARCOUNT {
                                    Button("Reset", systemImage: "arrow.clockwise") {
                                        barCount = Defaults.BARCOUNT
                                    }
                                    .buttonStyle(.borderless)
                                    .labelStyle(.iconOnly)
                                    .padding(.trailing, 5)
                                }
                            }
                        Stepper("", value: $barCount, in: 1...50, step: 1)
                            .frame(width: 30)
                    }
                    HStack {
                        Text("Width: ")
                            .frame(minWidth: 120, alignment: .leading)
                        TextField("#width", value: $width, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .overlay(alignment: .trailing) {
                                if width != Defaults.WIDTH {
                                    Button("Reset", systemImage: "arrow.clockwise") {
                                        width = Defaults.WIDTH
                                    }
                                    .buttonStyle(.borderless)
                                    .labelStyle(.iconOnly)
                                    .padding(.trailing, 5)
                                }
                            }
                        Stepper("", value: $width, in: 25...100, step: 1)
                            .frame(width: 30)
                    }
                    HStack {
                        Text("Seperator Width: ")
                            .frame(minWidth: 120, alignment: .leading)
                        TextField("#height", value: $seperatorWidth, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .overlay(alignment: .trailing) {
                                if seperatorWidth != Defaults.SEPERATORWIDTH {
                                    Button("Reset", systemImage: "arrow.clockwise") {
                                        seperatorWidth = Defaults.SEPERATORWIDTH
                                    }
                                    .buttonStyle(.borderless)
                                    .labelStyle(.iconOnly)
                                    .padding(.trailing, 5)
                                }
                            }
                        Stepper("", value: $seperatorWidth, in: 0...10, step: 1)
                            .frame(width: 30)
                    }
                }
                Section("Gradient") {
                    HStack {
                        Text("Colors: ")
                        Spacer()
                        if gradientColorArray != Defaults.GRADIENTCOLORS || gradStart != Defaults.GRADSTART || gradEnd != Defaults.GRADEND {
                            Button("Reset", systemImage: "arrow.clockwise") {
                                gradientColorArray = Defaults.GRADIENTCOLORS
                                gradStart = Defaults.GRADSTART
                                gradEnd = Defaults.GRADEND
                            }
                            .labelStyle(.iconOnly)
                        }
                        Button("", systemImage: "rectangle.stack.badge.plus") {
                            gradientColorArray.append(StringColor(hexstring: "#FFFFFF"))
                        }
                        .labelStyle(.iconOnly)
                        Button("", systemImage: "rectangle.stack.badge.minus") {
                            gradientColorArray.removeLast()
                        }
                        .labelStyle(.iconOnly)
                        .disabled(gradientColorArray.count <= 1)
                    }
                    if gradientColorArray.count > 1 {
                        HStack {
                            Text("Gradient Start: ")
                                .frame(minWidth: 120, alignment: .leading)
                            Picker("", selection: $gradStart) {
                                ForEach(startEndOptions, id: \.self) { option in
                                    Text(option)
                                }
                            }
                            .pickerStyle(.automatic)
                        }
                        HStack {
                            Text("Gradient End: ")
                                .frame(minWidth: 120, alignment: .leading)
                            Picker("", selection: $gradEnd) {
                                ForEach(startEndOptions, id: \.self) { option in
                                    Text(option)
                                }
                            }
                            .pickerStyle(.automatic)
                        }
                    }
                    ForEach(gradientColorArray.indices, id: \.self) { offset in
                        HStack {
                            Text("Color \(offset + 1): ")
                                .frame(minWidth: 120, alignment: .leading)
                            TextField("#FFFFFF", text: $gradientColorArray[offset].hexstring)
                                .textFieldStyle(.roundedBorder)
                            Spacer()
                                .frame(width: 13)
                            ColorPicker("", selection: $gradientColorArray[offset].hexcolor, supportsOpacity: true)
                        }
                    }
                }
                Section("Audio Response") {
                    HStack {
                        Text("Attack: ")
                            .frame(minWidth: 120, alignment: .leading)
                        TextField("#attack", value: $attack, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .overlay(alignment: .trailing) {
                                if attack != Defaults.ATTACK {
                                    Button("Reset", systemImage: "arrow.clockwise") {
                                        attack = Defaults.ATTACK
                                    }
                                    .buttonStyle(.borderless)
                                    .labelStyle(.iconOnly)
                                    .padding(.trailing, 5)
                                }
                            }
                        Stepper("", value: $attack , in: 0.0...1.0, step: 0.01)
                            .frame(width: 30)
                    }
                    HStack {
                        Text("Decay: ")
                            .frame(minWidth: 120, alignment: .leading)
                        TextField("#decay", value: $decay, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .overlay(alignment: .trailing) {
                                if decay != Defaults.DECAY {
                                    Button("Reset", systemImage: "arrow.clockwise") {
                                        decay = Defaults.DECAY
                                    }
                                    .buttonStyle(.borderless)
                                    .labelStyle(.iconOnly)
                                    .padding(.trailing, 5)
                                }
                            }
                        Stepper("", value: $decay , in: 0.0...1.0, step: 0.01)
                            .frame(width: 30)
                    }
                    HStack {
                        Text("Cieling Multiplier: ")
                            .frame(minWidth: 120, alignment: .leading)
                        TextField("#cieling", value: $cieling, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .overlay(alignment: .trailing) {
                                if cieling != Defaults.CIELING {
                                    Button("Reset", systemImage: "arrow.clockwise") {
                                        cieling = Defaults.CIELING
                                    }
                                    .buttonStyle(.borderless)
                                    .labelStyle(.iconOnly)
                                    .padding(.trailing, 5)
                                }
                            }
                        Stepper("", value: $cieling, in: 0.0...2.0, step: 0.01)
                            .frame(width: 30)
                    }
                }
                Section("Audio Path (Pick One)") {
                    Toggle("Use CoreAudio", isOn: $coreAudioEnabled)
                    HStack {
                        Text("Audio Data Path (ex. Cava):")
                        TextField("/Path/To/Audio/Data/Socket", text: $audioDataPath)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField)
                            .disabled(coreAudioEnabled)
                            .foregroundStyle(coreAudioEnabled ? .secondary : .primary)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                coreAudioEnabled = false
                                focusedField = true
                            }
                    }
                }
                Section("Reset") {
                    Button("Load Defaults") {
                        audioDataPath = Defaults.AUDIODATAPATH
                        coreAudioEnabled = Defaults.COREAUDIOENABLED
                        attack = Defaults.ATTACK
                        decay = Defaults.DECAY
                        barCount = Defaults.BARCOUNT
                        cieling = Defaults.CIELING
                        gradientColorArray = Defaults.GRADIENTCOLORS
                        gradStart = Defaults.GRADSTART
                        gradEnd = Defaults.GRADEND
                        seperatorWidth = Defaults.SEPERATORWIDTH
                        width = Defaults.WIDTH
                    }
                }
            }
            .listStyle(.automatic)
            .listSectionSeparatorTint(.clear)
            .scrollIndicators(.never)
            Spacer()
            Text("No Copyright © 2026 Lun1xr")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .padding(.vertical)
        .onChange(of: gradientColorArray) {
            let gcar = gradientColorArray.map(\.hexstring)
            if gcar.allSatisfy({($0.count == 7 || $0.count == 9 || $0.count == 4) && $0.starts(with: "#")}) {
                gradientColors = gcar.joined(separator: "-")
                print("Changed: \(gradientColors)")
            }
        }
        .onAppear {
            print("On Start: \(gradientColors)")
            gradientColorArray = gradientColors.split(separator: "-").map { StringColor(hexstring: String($0)) }
        }
    }
}

struct VisualizerView: View {
    @AppStorage("AudioDataPath") private var audioDataPath: String = ""
    @AppStorage("CoreAudioEnabled") private var coreAudioEnabled: Bool = true
    @AppStorage("Decay") private var decay: Double = 0.2
    @AppStorage("Width") private var width: Int = 50
    @AppStorage("SeperatorWidth") private var seperatorWidth: Int = 1
    @AppStorage("GradientColors") private var gradientColors: String = "#FFFFFF"
    @AppStorage("GradientStart") private var gradStart: String = "top"
    @AppStorage("GradientEnd") private var gradEnd: String = "bottom"
    @State private var gradient: LinearGradient = LinearGradient(colors: [.white], startPoint: .top, endPoint: .bottom)
    @StateObject private var audioManager = AudioManager.init()
    static let CIELING: CGFloat = 1.0
    var body: some View {
        let calculatedWidth = CGFloat(width - seperatorWidth * (audioManager.data.count - 1)) / CGFloat(audioManager.data.count)
        gradient
            .mask(
                HStack(alignment: .bottom, spacing: CGFloat(seperatorWidth)) {
                    ForEach(Array(audioManager.data.enumerated()), id: \.offset) { _, datum in
                        RoundedRectangle(cornerRadius: 1)
                            .frame(width: calculatedWidth, height: CGFloat(min(datum*13, 13))+1)
                    }
                }
                .frame(minWidth: CGFloat(width), idealWidth: CGFloat(width), maxWidth: CGFloat(width), minHeight: 16, idealHeight: 16, maxHeight: 16, alignment: .bottom)
                .padding(.bottom, 4)
            )
        .drawingGroup()
        .onAppear {
            gradient = VisualizerView.createGradient(colorString: gradientColors, gradientStart: gradStart, gradientEnd: gradEnd)
        }
        .onChange(of: gradientColors) {
            gradient = VisualizerView.createGradient(colorString: gradientColors, gradientStart: gradStart, gradientEnd: gradEnd)
        }
        .onChange(of: [gradStart, gradEnd]) {
            gradient = VisualizerView.createGradient(colorString: gradientColors, gradientStart: gradStart, gradientEnd: gradEnd)
        }
    }
    static func createGradient(colorString: String, gradientStart: String, gradientEnd: String) -> LinearGradient {
        let startPoint = resolveUnitPoints(point: gradientStart)
        let endPoint = resolveUnitPoints(point: gradientEnd)
        let colors: [Color] = colorString.split(separator: "-").map { Color(hex: String($0)) }
        return LinearGradient(colors: colors, startPoint: startPoint, endPoint: endPoint)
    }
    static func resolveUnitPoints(point: String) -> UnitPoint {
        switch (point) {
            case "top": UnitPoint.top
            case "leading": UnitPoint.leading
            case "trailing": UnitPoint.trailing
            case "bottom": UnitPoint.bottom
            case "topLeading": UnitPoint.topLeading
            case "topTrailing": UnitPoint.topTrailing
            case "bottomLeading": UnitPoint.bottomLeading
            case "bottomTrailing": UnitPoint.bottomTrailing
            default: UnitPoint.top
        }
    }
}

struct StringColor: Equatable {
    static func == (lhs: borrowing StringColor, rhs: borrowing StringColor) -> Bool {
        return lhs.hexcolor == rhs.hexcolor
    }
        
    var hexstring: String
    var hexcolor: Color {
        get {
            Color(hex: hexstring)
        }
        set {
            hexstring = String(hex: newValue)
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 1)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension String {
    init(hex: Color) {
        let color = NSColor(hex).usingColorSpace(.sRGB)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color?.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let r = red > 1.0 ? 255 : Int(red * 255)
        let g = green > 1.0 ? 255 : Int(green * 255)
        let b = blue > 1.0 ? 255 : Int(blue * 255)
        let a = alpha > 1.0 ? 255 : Int(alpha * 255)
        self = ""
        self.append("#")
        self.append(String(format: "%02x%02x%02x%02x", a, r, g, b))
    }
}

#Preview {
    SettingsView()
}
