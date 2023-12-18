//
//  AVAudioSession+Extensions.swift
//
//
//  Created by Tomasz Iwaszek on 18/12/2023.
//

import AVFoundation

extension AVAudioSession {
    func hasPermissionToRecord() async -> Bool {
        await withCheckedContinuation { continuation in
            requestRecordPermission { authorized in
                continuation.resume(returning: authorized)
            }
        }
    }
}
