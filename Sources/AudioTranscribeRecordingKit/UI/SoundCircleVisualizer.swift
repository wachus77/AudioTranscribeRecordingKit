//
//  SoundCircleVisualizer.swift
//  
//
//  Created by Tomasz Iwaszek on 19/12/2023.
//

import SwiftUI

public struct SoundCircleVisualizer<Content: ShapeStyle>: View {
    @ObservedObject private var audioTranscribeRecordingKit: AudioTranscribeRecordingKit
    @Binding private var audioMeterSingleValue: AudioMeterValue?
    private let circleMinSize: CGFloat
    private let circleMaxSize: CGFloat
    private let circleShapeStyle: Content
    
    private var interpolatedValue: CGFloat {
        let audioMeterSingleValue = self.audioMeterSingleValue?.value ?? audioTranscribeRecordingKit.audioMeterSingleValue.value
        return CGFloat(audioMeterSingleValue).interpolated(from: 0...1, to: circleMinSize...circleMaxSize)
    }
    
    public init(audioTranscribeRecordingKit: AudioTranscribeRecordingKit, circleMinSize: CGFloat, circleMaxSize: CGFloat, circleShapeStyle: Content) {
        self.audioTranscribeRecordingKit = audioTranscribeRecordingKit
        self._audioMeterSingleValue = Binding.constant(nil)
        self.circleMinSize = circleMinSize
        self.circleMaxSize = circleMaxSize
        self.circleShapeStyle = circleShapeStyle
    }
    
    public init(audioMeterSingleValue: Binding<AudioMeterValue?>, circleMinSize: CGFloat, circleMaxSize: CGFloat, circleShapeStyle: Content) {
        self.audioTranscribeRecordingKit = AudioTranscribeRecordingKit()
        self._audioMeterSingleValue = audioMeterSingleValue
        self.circleMinSize = circleMinSize
        self.circleMaxSize = circleMaxSize
        self.circleShapeStyle = circleShapeStyle
    }
    
    public var body: some View {
        ZStack {
            Circle()
                .fill(circleShapeStyle)
                .frame(width: interpolatedValue, height: interpolatedValue)
        }
    }
}
