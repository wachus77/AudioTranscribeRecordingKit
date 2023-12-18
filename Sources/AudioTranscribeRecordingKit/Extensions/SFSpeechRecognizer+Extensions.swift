//
//  SFSpeechRecognizer+Extensions.swift
//
//
//  Created by Tomasz Iwaszek on 18/12/2023.
//

import Speech

extension SFSpeechRecognizer {
    static func hasAuthorizationToRecognize() async -> (Bool, SFSpeechRecognizerAuthorizationStatus) {
        await withCheckedContinuation { continuation in
            requestAuthorization { status in
                continuation.resume(returning: (status == .authorized, status))
            }
        }
    }
}
