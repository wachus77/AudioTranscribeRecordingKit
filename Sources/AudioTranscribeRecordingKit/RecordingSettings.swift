//
//  RecordingSettings.swift
//
//
//  Created by Tomasz Iwaszek on 18/12/2023.
//

import Foundation

public struct RecordingSettings {
    public let filename: String
    public let shouldStopRecordingIfSpeechIsNotDetected: Bool
    public let speechIsNotDetectedTimeoutInterval: TimeInterval
    
    public init(filename: String, shouldStopRecordingIfSpeechIsNotDetected: Bool, speechIsNotDetectedTimeoutInterval: TimeInterval) {
        self.filename = filename
        self.shouldStopRecordingIfSpeechIsNotDetected = shouldStopRecordingIfSpeechIsNotDetected
        self.speechIsNotDetectedTimeoutInterval = speechIsNotDetectedTimeoutInterval
    }
}
