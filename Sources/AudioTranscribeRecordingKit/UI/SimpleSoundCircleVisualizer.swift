//
//  SimpleSoundCircleVisualizer.swift
//  
//
//  Created by Tomasz Iwaszek on 10/01/2024.
//

import SwiftUI

public struct SimpleSoundCircleVisualizer<Content: ShapeStyle>: View {
    @Binding private var audioMeterSingleValue: AudioMeterValue
    private let circleMinSize: CGFloat
    private let circleMaxSize: CGFloat
    private let circleShapeStyle: Content
    
    private var interpolatedValue: CGFloat {
        return CGFloat(audioMeterSingleValue.value).interpolated(from: 0...1, to: circleMinSize...circleMaxSize)
    }
    
    public init(audioMeterSingleValue: Binding<AudioMeterValue>, circleMinSize: CGFloat, circleMaxSize: CGFloat, circleShapeStyle: Content) {
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
