//
//  SpeechRecognizerSupportedLanguage.swift
//
//
//  Created by Tomasz Iwaszek on 18/12/2023.
//

import Foundation

public struct SpeechRecognizerSupportedLanguage {
    public let identifier: String?
    public let name: String?
    public let locale: Locale
    
    public init(identifier: String?, name: String?, locale: Locale) {
        self.identifier = identifier
        self.name = name
        self.locale = locale
    }
}

