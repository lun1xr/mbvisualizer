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
import SwiftData
import Charts

public class Defaults {
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

@Model
final public class ControlPoint {
    var order: Int
    var frequency: Float
    var gain: Float
    var q: qVal
    init(order: Int, frequency: Float, gain: Float, q: qVal) {
        self.order = order
        self.frequency = frequency
        self.gain = gain
        self.q = q
    }
    func getGraphingValues() -> (frequency: Float, gain: Float, band: Float) {
        return (self.frequency, self.gain, self.q.band)
    }
}

public enum qVal: Float, Codable {
    case gen = 0.7
    case spec = 1.4
    case vspec = 3.5
    case spike = 6.0
    var band: Float {
        switch self {
            case .gen: return 1.917
            case .spec: return 1.00976
            case .vspec: return 0.411
            case .spike: return 0.24
        }
    }
    var next: qVal {
        switch self {
        case .gen: return .spec
        case .spec: return .vspec
        case .vspec: return .spike
        case .spike: return .gen
        }
    }
}

struct SettingsView: View {
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
            Text("v0.2.0")
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
                    VStack(alignment: .leading) {
                        Text("Parametric EQ: ")
                            .listRowSeparator(.hidden, edges: .bottom)
                        ParametricView()
                            .padding()
                    }
                }
                Section("Reset") {
                    Button("Load All Defaults") {
                        loadGradientDefaults()
                        loadAppearanceDefaults()
                        loadAudioResponseDefaults()
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
    func loadAppearanceDefaults() {
        barCount = Defaults.BARCOUNT
        seperatorWidth = Defaults.SEPERATORWIDTH
        width = Defaults.WIDTH
    }
    func loadGradientDefaults() {
        gradientColorArray = Defaults.GRADIENTCOLORS
        gradStart = Defaults.GRADSTART
        gradEnd = Defaults.GRADEND
    }
    func loadAudioResponseDefaults() {
        attack = Defaults.ATTACK
        decay = Defaults.DECAY
        cieling = Defaults.CIELING
    }
}

struct ParametricView: View {
    @Query(sort: \ControlPoint.order) private var controlPoints: [ControlPoint]
    @Environment(\.modelContext) private var modelContext
    @AppStorage("SampleRate") var sameplerate: Float64 = 0
    
    @State private var currentHoverControlPoint: ControlPoint?
    @State private var clickMonitor: Any?
    
    @StateObject private var audioManager: AudioManager = AudioManager.shared
        
    var body: some View {
        let cPointsSampled = controlPoints.map({ $0.getGraphingValues() })
        Chart {
            AreaPlot(x: "x", yStart: "-20", yEnd: "parax") { x in
                (
                    yStart: -20,
                    yEnd: approxParametric(x: x, cPointsSampled)
                )
            }
            .foregroundStyle(Color.blue.opacity(0.5))
            LinePlot(x: "x", y: "y") { x in
                approxParametric(x: x, cPointsSampled)
            }
            .foregroundStyle(Color.blue)
        }
        .chartXScale(domain: 20...sameplerate/2, type: .log)
        .chartYScale(domain: -20...20, type: .linear)
        .chartOverlay { proxy in
            GeometryReader { geometry in 
                if let proxyFrame = proxy.plotFrame {
                    let frameRect = geometry[proxyFrame]
                    let origin = frameRect.origin
                    ZStack {
                        Rectangle()
                            .frame(width: frameRect.width, height: frameRect.height)
                            .position(x: frameRect.midX, y: frameRect.midY)
                            .foregroundStyle(.clear)
                            .allowsHitTesting(true)
                            .contentShape(Rectangle())
                            .onTapGesture(coordinateSpace: .local) { gesture in
                                print("Tap registered")
                                let controlFreq = (proxy.value(atX: gesture.x-origin.x, as: Float.self) ?? 20).clamped(20...Float(self.sameplerate)/2)
                                let controlGain = (proxy.value(atY: gesture.y-origin.y, as: Float.self) ?? 0).clamped(-20...20)
                                let controlPoint = ControlPoint(order: controlPoints.count,frequency: controlFreq, gain: controlGain, q: .gen)
                                modelContext.insert(controlPoint)
                                audioManager.setBiquadDirty()
                            }
                        ForEach(controlPoints) { controlPoint in
                            ControlPointHandle()
                                .allowsHitTesting(true)
                                .onTapGesture(count: 2) {
                                    let current = controlPoint.q
                                    controlPoint.q = current.next
                                    audioManager.setBiquadDirty()
                                }
                                .onHover { didEnter in
                                    if didEnter {
                                        currentHoverControlPoint = controlPoint
                                    } else {
                                        currentHoverControlPoint = nil
                                    }
                                }
                                .gesture(
                                    DragGesture(minimumDistance: 0, coordinateSpace: .named("parametric"))
                                        .onChanged { value in
                                            controlPoint.frequency = (proxy.value(atX: value.location.x-origin.x, as: Float.self) ?? 0).clamped(20...Float(self.sameplerate)/2)
                                            controlPoint.gain = (proxy.value(atY: value.location.y-origin.y, as: Float.self) ?? 0).clamped(-20...20)
                                            audioManager.setBiquadDirty()
                                        }
                                )
                                .position(
                                    x: origin.x + (proxy.position(forX: controlPoint.frequency) ?? 0),
                                    y: origin.y + (proxy.position(forY: controlPoint.gain) ?? 0)
                                )
                        }
                    }
                    .onAppear {
                        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseUp, handler: { event in
                            if let hoverPoint = currentHoverControlPoint {
                                modelContext.delete(hoverPoint)
                                currentHoverControlPoint = nil
                                audioManager.setBiquadDirty()
                            }
                            return event
                        })
                    }
                    .onDisappear {
                        if let clickMonitor = clickMonitor {
                            NSEvent.removeMonitor(clickMonitor)
                        }
                    }
                    .coordinateSpace(name: "parametric")
                }
            }
        }
    }
    nonisolated func approxParametric(x: Double, _ sampled: [(frequency: Float, gain: Float, band: Float)]) -> Double {
        var result: Double = 0.0
        for controlPoint in sampled {
            let inexpnum = log2(x/Double(controlPoint.frequency))
            let inexpdenom = controlPoint.band
            let indexp = -0.5 * pow(inexpnum/Double(inexpdenom), 2)
            let fullexp = Double(controlPoint.gain)*exp(indexp)
            result += fullexp
        }
        return result
    }
}

struct ControlPointHandle: View {
    var body: some View {
        ZStack {
            Circle()
                .frame(width: 20, height: 20)
                .foregroundStyle(.ultraThinMaterial)
            Circle()
                .frame(width: 15, height: 15)
                .foregroundColor(.blue)
        }
    }
}

struct VisualizerView: View {
    @AppStorage("Decay") private var decay: Double = 0.2
    @AppStorage("Width") private var width: Int = 50
    @AppStorage("SeperatorWidth") private var seperatorWidth: Int = 1
    @AppStorage("GradientColors") private var gradientColors: String = "#FFFFFF"
    @AppStorage("GradientStart") private var gradStart: String = "top"
    @AppStorage("GradientEnd") private var gradEnd: String = "bottom"
    @State private var gradient: LinearGradient = LinearGradient(colors: [.white], startPoint: .top, endPoint: .bottom)
    @Environment(\.modelContext) private var modelContext
    @StateObject private var audioManager = AudioManager.shared
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
            audioManager.setModelContext(modelContext: modelContext)
            gradient = VisualizerView.createGradient(colorString: gradientColors, gradientStart: gradStart, gradientEnd: gradEnd)
        }
        .onChange(of: gradientColors) {
            gradient = VisualizerView.createGradient(colorString: gradientColors, gradientStart: gradStart, gradientEnd: gradEnd)
        }
        .onChange(of: [gradStart, gradEnd]) {
            gradient = VisualizerView.createGradient(colorString: gradientColors, gradientStart: gradStart, gradientEnd: gradEnd)
        }
        .onReceive(NotificationCenter.default.publisher(for: .restartSinkRequested)) { _ in
            audioManager.reInit()
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

extension Comparable {
    func clamped(_ limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
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
