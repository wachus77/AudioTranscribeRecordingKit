//
//  AudioTranscribeRecordingKit.swift
//
//
//  Created by Tomasz Iwaszek on 18/12/2023.
//

import Foundation
import Speech
import Combine

public final class AudioTranscribeRecordingKit: ObservableObject {
    
    public var speechRecognizerMode: SpeechRecognizerMode
    public var isRecordingEnabled: Bool
    public var numberOfAudioMeters: Int
    public var recordingSettings: RecordingSettings {
        didSet {
            if self.speechRecognizerMode == .disabled && self.isRecordingEnabled && (self.recordingSettings.shouldNotifyIfSpeechWasNotDetectedOnceItStarts || self.recordingSettings.shouldNotifyIfSpeechWasNotDetectedAtAll) {
                error(AudioTranscribeRecordingError.speechRecognizerShouldBeEnabledForRecordingTimeoutNotificationOptions)
                return
            }
        }
    }
    public var speechRecognizerSettings: SpeechRecognizerSettings {
        didSet {
            if let locale = self.speechRecognizerSettings.supportedLanguage?.locale {
                self.recognizer = SFSpeechRecognizer(locale: locale)
            } else {
                self.recognizer = SFSpeechRecognizer()
            }
            
            guard self.recognizer != nil else {
                error(AudioTranscribeRecordingError.nilRecognizer)
                return
            }
        }
    }
    
    @MainActor @Published public var audioMeterValues: [AudioMeterValue]
    @MainActor @Published public var audioMeterSingleValue: AudioMeterValue
    
    private var audioEngine: AVAudioEngine?
    private var mixerNode: AVAudioMixerNode?
    @MainActor @Published public var state: RecordingTranscribingState = .stopped
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?
    
    private var speechWasNotDetectedOnceItStartsTimer: Timer?
    private var speechWasNotDetectedAtAllTimer: Timer?
    
    private let recordingOutputFormatSettings = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: 44100,
        AVNumberOfChannelsKey: 1
    ]
    private let recordingFolderURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    
    private let recordingFileExtension = "m4a"
    
    private var currentAudioMeterIndex: Int = 0
    
    @MainActor @Published public var transcript: String = ""
    
    @MainActor @Published public var partialTranscript: String = ""
    
    @MainActor @Published public var error: Error?
    
    @MainActor public var speechWasNotDetectedOnceItStartsSubject = PassthroughSubject<Void, Never>()
    @MainActor public var speechWasNotDetectedAtAllSubject = PassthroughSubject<Void, Never>()
    @MainActor public var speechWasDetectedSubject = CurrentValueSubject<Bool, Never>(false)
    
    @MainActor public var speechRecognizerAuthorizationStatusSubject = CurrentValueSubject<SFSpeechRecognizerAuthorizationStatus, Never>(.notDetermined)
    
    @MainActor public var recordPermissionAuthorizationStatusSubject = CurrentValueSubject<Bool, Never>(false)
    
    private var isInterrupted = false
    private var configChangePending = false
    
    private var recordingOutputFile: AVAudioFile?
    private var isRecordingWhileAudioEngineIsOn: Bool = false
    
    public var recordingOutputUrl: URL {
        return recordingFolderURL.appendingPathComponent("\(recordingSettings.filename).\(recordingFileExtension)")
    }
    
    // MARK: - Initialization
    
    /**
     Initializes a new AudioTranscribeRecordingKit. If this is the first time you've used the class, it
     requests access to the speech recognizer and the microphone.
     */
    @MainActor
    public init(speechRecognizerMode: SpeechRecognizerMode = .decibels,
                isRecordingEnabled: Bool = true,
                speechRecognizerSettings: SpeechRecognizerSettings = SpeechRecognizerSettings(supportedLanguage: SpeechRecognizerSettings.availableLanguages.first(where: { $0.identifier == "en-US" }), decibelsMinValue: 0.025),
                recordingSettings: RecordingSettings = RecordingSettings(filename: "recording",
                                                                         shouldNotifyIfSpeechWasNotDetectedOnceItStarts: true,
                                                                         speechWasNotDetectedOnceItStartsTimeoutInterval: 2,
                                                                         shouldNotifyIfSpeechWasNotDetectedAtAll: true,
                                                                         speechWasNotDetectedAtAllTimeoutInterval: 10),
                numberOfAudioMeters: Int = 4) {
        self.speechRecognizerMode = speechRecognizerMode
        self.isRecordingEnabled = isRecordingEnabled
        self.speechRecognizerSettings = speechRecognizerSettings
        self.recordingSettings = recordingSettings
        self.numberOfAudioMeters = numberOfAudioMeters
        self.audioMeterValues = [AudioMeterValue](repeating: AudioMeterValue(value: .zero), count: numberOfAudioMeters)
        self.audioMeterSingleValue = AudioMeterValue(value: 0)
        
        if self.speechRecognizerMode == .speechRecognition {
            if let locale = self.speechRecognizerSettings.supportedLanguage?.locale {
                self.recognizer = SFSpeechRecognizer(locale: locale)
            } else {
                self.recognizer = SFSpeechRecognizer()
            }
            
            guard self.recognizer != nil else {
                error(AudioTranscribeRecordingError.nilRecognizer)
                return
            }
        } else {
            self.recognizer = nil
        }
        
        if self.speechRecognizerMode == .disabled && self.isRecordingEnabled && (self.recordingSettings.shouldNotifyIfSpeechWasNotDetectedOnceItStarts || self.recordingSettings.shouldNotifyIfSpeechWasNotDetectedAtAll) {
            error(AudioTranscribeRecordingError.speechRecognizerShouldBeEnabledForRecordingTimeoutNotificationOptions)
            return
        }
        
        registerForNotifications()
    }
    
    // MARK: - Permissions
    
    public func checkRequiredPermissions() async -> Bool {
        var hasFirstRequiredAuthorizationToRecognize = false
        if self.speechRecognizerMode == .speechRecognition {
            hasFirstRequiredAuthorizationToRecognize = await hasAuthorizationToRecognize()
        } else {
            hasFirstRequiredAuthorizationToRecognize = true
        }
        let hasSecondRequiredPermissionToRecord = await hasPermissionToRecord()
        return hasFirstRequiredAuthorizationToRecognize && hasSecondRequiredPermissionToRecord
    }
    
    private func hasAuthorizationToRecognize() async -> Bool {
        let (hasAuthorizationToRecognize, speechRecognizerAuthorizationStatus) = await SFSpeechRecognizer.hasAuthorizationToRecognize()
        
        await speechRecognizerAuthorizationStatusSubject.send(speechRecognizerAuthorizationStatus)
        
        if !hasAuthorizationToRecognize {
            self.error(AudioTranscribeRecordingError.notAuthorizedToRecognize)
        }
        
        return hasAuthorizationToRecognize
    }
    
    private func hasPermissionToRecord() async -> Bool {
        let hasPermissionToRecord = await AVAudioSession.sharedInstance().hasPermissionToRecord()
        
        await recordPermissionAuthorizationStatusSubject.send(hasPermissionToRecord)
        
        if !hasPermissionToRecord {
            self.error(AudioTranscribeRecordingError.notPermittedToRecord)
        }
        return hasPermissionToRecord
    }
    
    // MARK: - Setup
    
    public func setupSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            self.error(error)
        }
    }
    
    public func setupEngine() {
        audioEngine = AVAudioEngine()
        mixerNode = AVAudioMixerNode()
        
        if speechRecognizerMode == .speechRecognition {
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            recognitionRequest?.shouldReportPartialResults = true
            recognitionRequest?.requiresOnDeviceRecognition = false
        }
        
        // Set volume to 0 to avoid audio feedback while recording.
        mixerNode?.volume = 0
        
        audioEngine?.attach(mixerNode!)
        
        makeConnections()
        
        audioEngine?.prepare()
    }
    
    private func makeConnections() {
        guard let audioEngine = audioEngine, let mixerNode = mixerNode else { return }
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        audioEngine.connect(inputNode, to: mixerNode, format: inputFormat)
        
        let mainMixerNode = audioEngine.mainMixerNode
        let mixerFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: inputFormat.sampleRate, channels: 1, interleaved: false)
        audioEngine.connect(mixerNode, to: mainMixerNode, format: mixerFormat)
    }
    
    // MARK: - Control methods (start, stop, pause, resume)
    
    public func stopAudioEngineAndRemoveTap() {
        mixerNode?.removeTap(onBus: 0)
        audioEngine?.stop()
    }
    
    public func startAudioEngineAndInstallTap() {
        guard let audioEngine = audioEngine, let mixerNode = mixerNode  else { return }
        
        do {
            let tapNode: AVAudioNode = mixerNode
            let recordingFormat = tapNode.outputFormat(forBus: 0)
            
            tapNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
                
                guard let self = self else {
                    return
                }
                
                if isRecordingEnabled, isRecordingWhileAudioEngineIsOn, let recordingOutputFile, let convertedBuffer = convertBufferForAAC(buffer: buffer, to: recordingOutputFile.processingFormat) {
                    try? recordingOutputFile.write(from: convertedBuffer)
                }
                
                if isRecordingWhileAudioEngineIsOn {
                    guard let avgPowerInDecibels = AudioTranscribeRecordingKit.avgPowerInDecibels(buffer: buffer) else { return }
                    let scaledAvgPower = AudioTranscribeRecordingKit.scaledPower(power: avgPowerInDecibels)
                    self.audioMeterHandler(scaledAvgPower: scaledAvgPower)
                    if speechRecognizerMode == .decibels {
                        verifyIfScaledAvgPowerCanMeanSpeech(scaledAvgPower: scaledAvgPower)
                    }
                }
            }
            
            try audioEngine.start()
        } catch {
            self.error(error)
        }
    }
    
    public func startRecordingWhileAudioEngineIsOn() {
        if isRecordingEnabled {
            isRecordingWhileAudioEngineIsOn = true
            recordingOutputFile = try? AVAudioFile(forWriting: recordingOutputUrl, settings: recordingOutputFormatSettings)
            setStateAfterStartOrResume()
        }
    }
    
    public func stopRecordingWhileAudioEngineIsOn() {
        isRecordingWhileAudioEngineIsOn = false
        
        speechWasNotDetectedOnceItStartsTimer?.invalidate()
        speechWasNotDetectedOnceItStartsTimer = nil
        speechWasNotDetectedAtAllTimer?.invalidate()
        speechWasNotDetectedAtAllTimer = nil
        
        Task { @MainActor in
            state = .stopped
            audioMeterValues = [AudioMeterValue](repeating: AudioMeterValue(value: .zero), count: numberOfAudioMeters)
            speechWasDetected(detected: false)
        }
    }
    
    
    public func startAudioEngineAndTranscribingAndRecording() {
        if speechRecognizerMode == .speechRecognition {
            guard let recognizer, recognizer.isAvailable else {
                error(AudioTranscribeRecordingError.recognizerIsUnavailable)
                return
            }
        }
        
        guard let audioEngine = audioEngine, let mixerNode = mixerNode  else { return }
        
        do {
            let tapNode: AVAudioNode = mixerNode
            let recordingFormat = tapNode.outputFormat(forBus: 0)
            
            var recordingOutputFile: AVAudioFile?
            if isRecordingEnabled {
                recordingOutputFile = try AVAudioFile(forWriting: recordingOutputUrl, settings: recordingOutputFormatSettings)
            }
            
            tapNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
                
                guard let self = self else {
                    return
                }
                
                if speechRecognizerMode == .speechRecognition{
                    self.recognitionRequest?.append(buffer)
                }
                
                // Convert the buffer format
                if self.isRecordingEnabled, let recordingOutputFile, let convertedBuffer = self.convertBufferForAAC(buffer: buffer, to: recordingOutputFile.processingFormat) {
                    try? recordingOutputFile.write(from: convertedBuffer)
                }
                
                guard let avgPowerInDecibels = AudioTranscribeRecordingKit.avgPowerInDecibels(buffer: buffer) else { return }
                let scaledAvgPower = AudioTranscribeRecordingKit.scaledPower(power: avgPowerInDecibels)
                self.audioMeterHandler(scaledAvgPower: scaledAvgPower)
                if speechRecognizerMode == .decibels {
                    verifyIfScaledAvgPowerCanMeanSpeech(scaledAvgPower: scaledAvgPower)
                }
            }

            if speechRecognizerMode == .speechRecognition, let recognitionRequest = recognitionRequest {
                self.recognitionTask = recognizer?.recognitionTask(with: recognitionRequest, resultHandler: { [weak self] result, error in
                    self?.recognitionHandler(audioEngine: audioEngine, result: result, error: error)
                })
            }
            
            try audioEngine.start()
            setStateAfterStartOrResume()
        } catch {
            stopAudioEngineAndTranscribingAndRecording()
            self.error(error)
        }
    }
    
    public func stopAudioEngineAndTranscribingAndRecording() {
        mixerNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        
        recognitionTask?.cancel()
        recognitionRequest?.endAudio()
        
        speechWasNotDetectedOnceItStartsTimer?.invalidate()
        speechWasNotDetectedOnceItStartsTimer = nil
        speechWasNotDetectedAtAllTimer?.invalidate()
        speechWasNotDetectedAtAllTimer = nil
        
        Task { @MainActor in
            state = .stopped
            audioMeterValues = [AudioMeterValue](repeating: AudioMeterValue(value: .zero), count: numberOfAudioMeters)
            speechWasDetected(detected: false)
        }
    }
    
    public func resumeTranscribingAndRecording()  {
        do {
            try audioEngine?.start()
            setStateAfterStartOrResume()
        } catch {
            self.error(error)
        }
    }
    
    public func pauseTranscribingAndRecording() {
        audioEngine?.pause()
        
        speechWasNotDetectedOnceItStartsTimer?.invalidate()
        speechWasNotDetectedOnceItStartsTimer = nil
        speechWasNotDetectedAtAllTimer?.invalidate()
        speechWasNotDetectedAtAllTimer = nil
        
        Task { @MainActor in
            state = .paused
        }
    }
    
    private func setStateAfterStartOrResume() {
        Task { @MainActor in
            switch ((speechRecognizerMode == .speechRecognition || speechRecognizerMode == .decibels), isRecordingEnabled) {
            case (true, true):
                state = .recordingAndTranscribing
            case (false, true):
                state = .recording
            case (true, false):
                state = .transcribing
            case (false, false):
                state = .audioMeteringOnly
            }
            
            if recordingSettings.shouldNotifyIfSpeechWasNotDetectedAtAll && !speechWasDetectedSubject.value && (state == .recording || state == .recordingAndTranscribing || state == .transcribing) {
                restartSpeechWasNotDetectedAtAllTimer()
            }
        }
    }
    
    // MARK: - Handlers
    
    private func recognitionHandler(audioEngine: AVAudioEngine, result: SFSpeechRecognitionResult?, error: Error?) {
        var receivedFinalResult = false
        if let result = result {
            receivedFinalResult = result.isFinal
            transcribePartial(result.bestTranscription.formattedString)
            speechWasDetected(detected: true)
        }
        
        let receivedError = error != nil
        
        if receivedFinalResult || receivedError {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        if let result, receivedFinalResult {
            transcribe(result.bestTranscription.formattedString)
            speechWasDetected(detected: true)
        } else {
            Task { @MainActor in
                if let error = error {
                    self.error(error)
                    return
                }
                
                if recordingSettings.shouldNotifyIfSpeechWasNotDetectedOnceItStarts && speechWasDetectedSubject.value && (state == .recording || state == .recordingAndTranscribing || state == .transcribing) {
                    restartSpeechWasNotDetectedOnceItStartsTimer()
                }
            }
        }
    }
    
    private func verifyIfScaledAvgPowerCanMeanSpeech(scaledAvgPower: Float) {
        Task { @MainActor in
            if scaledAvgPower >= speechRecognizerSettings.decibelsMinValue ?? 0.025 {
                speechWasDetected(detected: true)
                if recordingSettings.shouldNotifyIfSpeechWasNotDetectedOnceItStarts && speechWasDetectedSubject.value && (state == .recording || state == .recordingAndTranscribing || state == .transcribing) {
                    restartSpeechWasNotDetectedOnceItStartsTimer()
                }
            }
        }
    }
    
    
    private func audioMeterHandler(scaledAvgPower: Float) {
        Task { @MainActor in
            audioMeterSingleValue = AudioMeterValue(value: scaledAvgPower)
            audioMeterValues[currentAudioMeterIndex] = AudioMeterValue(value: scaledAvgPower)
            currentAudioMeterIndex = (currentAudioMeterIndex + 1) % numberOfAudioMeters
        }
    }
    
    private func restartSpeechWasNotDetectedOnceItStartsTimer() {
        speechWasNotDetectedOnceItStartsTimer?.invalidate()
        speechWasNotDetectedOnceItStartsTimer = Timer.scheduledTimer(timeInterval: recordingSettings.speechWasNotDetectedOnceItStartsTimeoutInterval, target: self, selector: #selector(speechWasNotDetectedOnceItStarts), userInfo: nil, repeats: false)
    }
    
    private func restartSpeechWasNotDetectedAtAllTimer() {
        speechWasNotDetectedAtAllTimer?.invalidate()
        speechWasNotDetectedAtAllTimer = Timer.scheduledTimer(timeInterval: recordingSettings.speechWasNotDetectedAtAllTimeoutInterval, target: self, selector: #selector(speechWasNotDetectedAtAll), userInfo: nil, repeats: false)
    }
    
    @objc private func speechWasNotDetectedOnceItStarts() {
        Task { @MainActor in
            guard (state == .recording || state == .recordingAndTranscribing || state == .transcribing) && speechWasDetectedSubject.value else { return }
            speechWasNotDetectedOnceItStartsSubject.send()
        }
    }
    
    @objc private func speechWasNotDetectedAtAll() {
        Task { @MainActor in
            guard (state == .recording || state == .recordingAndTranscribing || state == .transcribing) && !speechWasDetectedSubject.value else { return }
            speechWasNotDetectedAtAllSubject.send()
        }
    }
    
    @objc private func speechWasDetected(detected: Bool) {
        Task { @MainActor in
            guard detected != speechWasDetectedSubject.value else { return }
            guard (detected == true && (state == .recording || state == .recordingAndTranscribing || state == .transcribing)) || detected == false else { return }
            speechWasNotDetectedAtAllTimer?.invalidate()
            speechWasDetectedSubject.send(detected)
        }
    }
    
    // MARK: - UI update
    
    private func transcribe(_ message: String) {
        Task { @MainActor in
            transcript = message
        }
    }
    
    
    private func transcribePartial(_ message: String) {
        Task { @MainActor in
            partialTranscript = message
        }
    }
    
    
    private func error(_ error: Error) {
        Task { @MainActor in
            self.error = error
        }
    }
}

// MARK: - Buffer conversion

extension AudioTranscribeRecordingKit {
    private func convertBufferForAAC(buffer: AVAudioPCMBuffer, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let converter = AVAudioConverter(from: buffer.format, to: format) else {
            print("Could not create audio converter")
            return nil
        }
        
        guard let newBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(format.sampleRate) * buffer.frameLength / AVAudioFrameCount(buffer.format.sampleRate)) else {
            print("Could not create new PCM buffer")
            return nil
        }
        
        var inputBufferIndex: AVAudioFrameCount = 0
        
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            if inputBufferIndex >= buffer.frameCapacity {
                outStatus.pointee = .endOfStream
                return nil // End of data
            }
            
            outStatus.pointee = .haveData
            
            let framesToCopy = min(buffer.frameCapacity - inputBufferIndex, inNumPackets)
            
            guard let bufferFloatChannelData = buffer.floatChannelData else {
                return nil
            }
            
            let inputPointer = bufferFloatChannelData.pointee.advanced(by: Int(inputBufferIndex))
            
            let inputBuffer = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: framesToCopy)
            inputBuffer?.frameLength = framesToCopy
            
            guard let inputBufferFloatChannelData = inputBuffer?.floatChannelData else {
                return nil
            }
            
            for channel in 0..<Int(buffer.format.channelCount) {
                memcpy(inputBufferFloatChannelData[channel], inputPointer.advanced(by: channel), Int(framesToCopy) * MemoryLayout<Float>.size)
            }
            
            inputBufferIndex += framesToCopy
            
            return inputBuffer
        }
        
        var error: NSError?
        converter.convert(to: newBuffer, error: &error, withInputFrom: inputBlock)
        
        if let error = error {
            print("Error during conversion: \(error)")
            return nil
        }
        
        return newBuffer
    }
}

// MARK: - Decibel calculation

extension AudioTranscribeRecordingKit {
    public static func avgPowerInDecibels(buffer: AVAudioPCMBuffer) -> Float? {
        guard let channelData = buffer.floatChannelData else {
            return nil
        }
        
        let channelDataValue = channelData.pointee
        
        let channelDataValueArray = stride(
            from: 0,
            to: Int(buffer.frameLength),
            by: buffer.stride)
            .map { channelDataValue[$0] }
        
        let rms = sqrt(channelDataValueArray.map {
            return $0 * $0
        }
            .reduce(0, +) / Float(buffer.frameLength))
        
        let avgPower = 20 * log10(rms)
        
        return avgPower
    }
    
    public static func scaledPower(power: Float) -> Float {
        guard power.isFinite else {
            return 0.0
        }
        
        let minDb: Float = -80
        
        if power < minDb {
            return 0.0
        } else if power >= 0.0 {
            return 1.0
        } else {
            let linearScale: Float = pow(10.0, 0.05 * power)
            return linearScale
        }
    }
}

// MARK: - Interrupt handling

extension AudioTranscribeRecordingKit {
    /// When recording audio in your app, it’s not guaranteed that it will have access to the microphone at all times. It is possible that the recording is interrupted by phone calls, or by other processes that take over the microphone, such as Siri. We need to take appropriate actions both when the interruption begins, and when it ends, and this is done by listening to notifications sent by the AVAudioSession.
    private func registerForNotifications() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: nil
        )
        { [weak self] (notification) in
            guard let self = self else {
                return
            }
            
            let userInfo = notification.userInfo
            let interruptionTypeValue: UInt = userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt ?? 0
            let interruptionType = AVAudioSession.InterruptionType(rawValue: interruptionTypeValue)!
            
            switch interruptionType {
            case .began:
                self.isInterrupted = true
                Task { @MainActor in
                    if self.state == .recordingAndTranscribing {
                        self.pauseTranscribingAndRecording()
                    }
                }
            case .ended:
                self.isInterrupted = false
                
                // Activate session again
                try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
                
                self.handleConfigurationChange()
                
                Task { @MainActor in
                    if self.state == .paused {
                        self.resumeTranscribingAndRecording()
                    }
                }
            @unknown default:
                break
            }
        }
        
        /// When there are changes to the hardware configuration, such as when an external microphone is connected or disconnected, the AVAudioEngineConfigurationChange notification is sent. We need to listen to this notification, and depending on whether the session is interrupted or not, rewire the node connections in the engine
        NotificationCenter.default.addObserver(
            forName: Notification.Name.AVAudioEngineConfigurationChange,
            object: nil,
            queue: nil
        ) { [weak self] (notification) in
            guard let self = self else {
                return
            }
            
            self.configChangePending = true
            
            if (!self.isInterrupted) {
                self.handleConfigurationChange()
            }
        }
        
        /// Under rare circumstances, the system terminates and restarts its media services daemon. Respond to these events by reinitializing your app’s audio objects (such as players, recorders, converters, or audio queues) and resetting your audio session’s category, options, and mode configuration. Your app shouldn’t restart its media playback, recording, or processing until initiated by user action.
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil,
            queue: nil
        ) { [weak self] (notification) in
            guard let self = self else {
                return
            }
            
            self.setupSession()
            self.setupEngine()
        }
    }
    
    private func handleConfigurationChange() {
        if configChangePending {
            makeConnections()
        }
        
        configChangePending = false
    }
}
