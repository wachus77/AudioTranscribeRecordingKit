//
//  AudioTranscribeRecordingError.swift
//
//
//  Created by Tomasz Iwaszek on 18/12/2023.
//

import Foundation

public enum AudioTranscribeRecordingError: CustomNSError, LocalizedError {
    case nilRecognizer
    case notAuthorizedToRecognize
    case notPermittedToRecord
    case recognizerIsUnavailable
    case speechRecognizerShouldBeEnabledForRecording
    
    public var errorDescription: String? {
        switch self {
        case .nilRecognizer: return "Can't initialize speech recognizer"
        case .notAuthorizedToRecognize: return "Not authorized to recognize speech"
        case .notPermittedToRecord: return "Not permitted to record audio"
        case .recognizerIsUnavailable: return "Recognizer is unavailable"
        case .speechRecognizerShouldBeEnabledForRecording:
            return "Speech recognizer should be enabled for recording"
        }
    }
    
    public var errorUserInfo: [String: Any] {
        return [NSLocalizedDescriptionKey: errorDescription ?? ""]
    }
}

