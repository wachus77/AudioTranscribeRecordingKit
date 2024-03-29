//
//  SpeechRecognizerSettings.swift
//
//
//  Created by Tomasz Iwaszek on 18/12/2023.
//

import Foundation
import Speech

public struct SpeechRecognizerSettings {
    public static var availableLanguages: [SpeechRecognizerSupportedLanguage] {
        var availableLanguages: [SpeechRecognizerSupportedLanguage] = []
        for locale in SFSpeechRecognizer.supportedLocales() {
            let language = SpeechRecognizerSupportedLanguage (
                identifier: locale.identifier,
                name: Locale.init(identifier: "en").localizedString(forIdentifier: locale.identifier),
                locale: locale
            )
            availableLanguages.append(language)
        }
        return availableLanguages
    }
    
    public let supportedLanguage: SpeechRecognizerSupportedLanguage?
    
    public let decibelsMinValue: Float?
    
    public init(supportedLanguage: SpeechRecognizerSupportedLanguage?, decibelsMinValue: Float?) {
        self.supportedLanguage = supportedLanguage
        self.decibelsMinValue = decibelsMinValue
    }
}
