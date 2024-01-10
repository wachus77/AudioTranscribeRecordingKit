//
//  AudioMeterValue.swift
//
//
//  Created by Tomasz Iwaszek on 18/12/2023.
//

import Foundation

public struct AudioMeterValue: Identifiable, Hashable {
    public let id = UUID()
    public let value: Float
    
    public init(value: Float) {
        self.value = value
    }
}
