//
//  SoundCircleVisualizer.swift
//  
//
//  Created by Tomasz Iwaszek on 19/12/2023.
//

import SwiftUI

public struct SoundCircleVisualizer<Content: ShapeStyle>: View {
    @ObservedObject private var audioTranscribeRecordingKit: AudioTranscribeRecordingKit
    private let circleMinSize: CGFloat
    private let circleMaxSize: CGFloat
    private let circleShapeStyle: Content
    
    private var interpolatedValue: CGFloat {
        CGFloat(audioTranscribeRecordingKit.audioMeterSingleValue.value).interpolated(from: 0...1, to: circleMinSize...circleMaxSize)
    }
    
    public init(audioTranscribeRecordingKit: AudioTranscribeRecordingKit, circleMinSize: CGFloat, circleMaxSize: CGFloat, circleShapeStyle: Content) {
        self.audioTranscribeRecordingKit = audioTranscribeRecordingKit
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
