//
//  RecordingSettings.swift
//
//
//  Created by Tomasz Iwaszek on 18/12/2023.
//

import Foundation

public struct RecordingSettings {
    public let filename: String
    public let shouldNotifyIfSpeechWasNotDetectedOnceItStarts: Bool
    public let speechWasNotDetectedOnceItStartsTimeoutInterval: TimeInterval
    public let shouldNotifyIfSpeechWasNotDetectedAtAll: Bool
    public let speechWasNotDetectedAtAllTimeoutInterval: TimeInterval
    
    public init(filename: String, shouldNotifyIfSpeechWasNotDetectedOnceItStarts: Bool, speechWasNotDetectedOnceItStartsTimeoutInterval: TimeInterval,
                shouldNotifyIfSpeechWasNotDetectedAtAll: Bool,
                speechWasNotDetectedAtAllTimeoutInterval: TimeInterval) {
        self.filename = filename
        self.shouldNotifyIfSpeechWasNotDetectedOnceItStarts = shouldNotifyIfSpeechWasNotDetectedOnceItStarts
        self.speechWasNotDetectedOnceItStartsTimeoutInterval = speechWasNotDetectedOnceItStartsTimeoutInterval
        self.shouldNotifyIfSpeechWasNotDetectedAtAll = shouldNotifyIfSpeechWasNotDetectedAtAll
        self.speechWasNotDetectedAtAllTimeoutInterval = speechWasNotDetectedAtAllTimeoutInterval
    }
}
