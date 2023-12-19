//
//  SoundBarView.swift
//  
//
//  Created by Tomasz Iwaszek on 19/12/2023.
//

import SwiftUI

public struct SoundBarView<Content: ShapeStyle>: View {
    private let minSize: CGFloat
    private let maxSize: CGFloat
    
    private let value: CGFloat
    
    private let shapeStyle: Content
    
    private var interpolatedValue: CGFloat {
        value.interpolated(from: 0...1, to: minSize...maxSize)
    }
    
    public init(minSize: CGFloat, maxSize: CGFloat, value: CGFloat, shapeStyle: Content) {
        self.minSize = minSize
        self.maxSize = maxSize
        self.value = value
        self.shapeStyle = shapeStyle
    }
    
    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: minSize/2)
                .fill(shapeStyle)
                .frame(width: minSize, height: interpolatedValue)
        }
    }
}
