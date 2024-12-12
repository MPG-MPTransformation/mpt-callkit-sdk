import AVFoundation

// private implementation
//
class SoundService {
    var playerRingBackTone: AVAudioPlayer!
    var playerRingTone: AVAudioPlayer!
    var speakerOn: Bool!

    func initPlayerWithPath(_ path: String) -> AVAudioPlayer {
        // Locate the plugin's bundle where the Assets folder resides
        guard let url = Bundle(for: type(of: self)).url(forResource: path, withExtension: "mp3") else {
           NSLog("File not found")
           fatalError("Failed to initialize AVAudioPlayer")
        }

        var player: AVAudioPlayer!
        do {
            player = try AVAudioPlayer(contentsOf: url)
        } catch {
            fatalError("Failed to initialize AVAudioPlayer: \(error)")
        }

        return player
    }

    func unInit() {
        if playerRingBackTone != nil {
            if playerRingBackTone.isPlaying {
                playerRingBackTone.stop()
            }
        }

        if playerRingTone != nil {
            if playerRingTone.isPlaying {
                playerRingTone.stop()
            }
        }
    }

    //
    // SoundService
    //
    func speakerEnabled(_ enabled: Bool) -> Bool {
        let session = AVAudioSession.sharedInstance()
        var options = session.categoryOptions

        if enabled {
            options.insert(AVAudioSession.CategoryOptions.defaultToSpeaker)
        } else {
            options.remove(AVAudioSession.CategoryOptions.defaultToSpeaker)
        }

        try! session.setCategory(AVAudioSession.Category(rawValue: convertFromAVAudioSessionCategory(AVAudioSession.Category.playAndRecord)), options: options)
        return true
    }

    func isSpeakerEnabled() -> Bool {
        speakerOn
    }

    @discardableResult
    func playRingTone() -> Bool {
        if playerRingTone == nil {
            playerRingTone = initPlayerWithPath("ringbacktone")
        }
        if playerRingTone != nil {
            playerRingTone.numberOfLoops = -1
            _ = speakerEnabled(true)
            playerRingTone.play()
            return true
        }
        return false
    }

    @discardableResult
    func stopRingTone() -> Bool {
        if playerRingTone != nil, playerRingTone.isPlaying {
            playerRingTone.stop()
            _ = speakerEnabled(true)
        }
        return true
    }

    @discardableResult
    func playRingBackTone() -> Bool {
        if playerRingBackTone == nil {
            playerRingBackTone = initPlayerWithPath("ringbacktone")
        }
        if playerRingBackTone != nil {
            playerRingBackTone.numberOfLoops = -1
            _ = speakerEnabled(false)
            playerRingBackTone.play()
            return true
        }

        return false
    }

    @discardableResult
    func stopRingBackTone() -> Bool {
        if playerRingBackTone != nil, playerRingBackTone.isPlaying {
            playerRingBackTone.stop()
            _ = speakerEnabled(true)
        }
        return true
    }
}

// Helper function inserted by Swift 4.2 migrator.
private func convertFromAVAudioSessionCategory(_ input: AVAudioSession.Category) -> String {
    input.rawValue
}
