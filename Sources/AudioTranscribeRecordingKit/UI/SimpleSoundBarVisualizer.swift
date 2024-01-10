//
//  SimpleSoundBarVisualizer.swift
//  
//
//  Created by Tomasz Iwaszek on 10/01/2024.
//

import SwiftUI

public struct SimpleSoundBarVisualizer<Content: ShapeStyle>: View {
    @Binding private var audioMeterValues: [AudioMeterValue]
    
    private let barSpacing: CGFloat
    private let barMinSize: CGFloat
    private let barMaxSize: CGFloat
    private let barShapeStyle: Content
    
    public init(audioMeterValues: Binding<[AudioMeterValue]>, barSpacing: CGFloat, barMinSize: CGFloat, barMaxSize: CGFloat, barShapeStyle: Content) {
        self._audioMeterValues = audioMeterValues
        self.barSpacing = barSpacing
        self.barMinSize = barMinSize
        self.barMaxSize = barMaxSize
        self.barShapeStyle = barShapeStyle
    }
    
    public var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(self.audioMeterValues, id: \.self) { level in
                SoundBarView(minSize: barMinSize, maxSize: barMaxSize, value: CGFloat(level.value), shapeStyle: barShapeStyle)
            }
        }
    }
}
