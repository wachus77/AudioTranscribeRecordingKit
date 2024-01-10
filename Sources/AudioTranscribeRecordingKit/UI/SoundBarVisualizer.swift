//
//  SoundVisualizer.swift
//
//
//  Created by Tomasz Iwaszek on 19/12/2023.
//

import SwiftUI

public struct SoundBarVisualizer<Content: ShapeStyle>: View {
    @ObservedObject private var audioTranscribeRecordingKit: AudioTranscribeRecordingKit
    @Binding private var audioMeterValues: [AudioMeterValue]?
    
    private let barSpacing: CGFloat
    private let barMinSize: CGFloat
    private let barMaxSize: CGFloat
    private let barShapeStyle: Content
    
    public init(audioTranscribeRecordingKit: AudioTranscribeRecordingKit, barSpacing: CGFloat, barMinSize: CGFloat, barMaxSize: CGFloat, barShapeStyle: Content) {
        self.audioTranscribeRecordingKit = audioTranscribeRecordingKit
        self._audioMeterValues = Binding.constant(nil)
        self.barSpacing = barSpacing
        self.barMinSize = barMinSize
        self.barMaxSize = barMaxSize
        self.barShapeStyle = barShapeStyle
    }
    
    public init(audioMeterValues: Binding<[AudioMeterValue]?>, barSpacing: CGFloat, barMinSize: CGFloat, barMaxSize: CGFloat, barShapeStyle: Content) {
        self.audioTranscribeRecordingKit = AudioTranscribeRecordingKit()
        self._audioMeterValues = audioMeterValues
        self.barSpacing = barSpacing
        self.barMinSize = barMinSize
        self.barMaxSize = barMaxSize
        self.barShapeStyle = barShapeStyle
    }
    
    public var body: some View {
        HStack(spacing: barSpacing) {
            let audioMeterValues: [AudioMeterValue] = self.audioMeterValues ?? audioTranscribeRecordingKit.audioMeterValues
            ForEach(audioMeterValues, id: \.self) { level in
                SoundBarView(minSize: barMinSize, maxSize: barMaxSize, value: CGFloat(level.value), shapeStyle: barShapeStyle)
            }
        }
    }
}
