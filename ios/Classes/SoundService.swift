import AVFoundation
import AudioToolbox

class SoundService {
    var playerRingBackTone: AVAudioPlayer!
    var speakerOn: Bool!
    var ringToneSoundID: SystemSoundID = 0

    init() {
        // Set default ringing sound to a system sound, such as the default "new mail" sound
        ringToneSoundID = 1007 // Choose a sound ID from Apple’s system sounds list
    }

    func unInit() {
        if playerRingBackTone != nil, playerRingBackTone.isPlaying {
            playerRingBackTone.stop()
        }
    }

    func speakerEnabled(_ enabled: Bool) {
        let session = AVAudioSession.sharedInstance()
        var options = session.categoryOptions

        if enabled {
            options.insert(.defaultToSpeaker)
        } else {
            options.remove(.defaultToSpeaker)
        }
        do {
            try session.setCategory(.playAndRecord, options: options)
            NSLog("Playback OK")
        } catch {
            NSLog("ERROR: CANNOT enable speaker. Message from code: \"\(error)\"")
        }
    }

    func isSpeakerEnabled() -> Bool {
        speakerOn
    }

    func playRingTone() -> Bool {
        // Use system sound for ringing
        if ringToneSoundID != 0 {
            speakerEnabled(true)
            AudioServicesPlaySystemSound(ringToneSoundID)
            return true
        }
        return false
    }

    func stopRingTone() -> Bool {
        // Stop the ringtone by disposing of the sound
        if ringToneSoundID != 0 {
            AudioServicesDisposeSystemSoundID(ringToneSoundID)
        }
        speakerEnabled(true)
        return true
    }

    func playRingBackTone() -> Bool {
        if playerRingBackTone == nil {
            playerRingBackTone = initPlayerWithPath("ringbacktone.mp3", fromPlugin: true)
        }
        if playerRingBackTone != nil {
            playerRingBackTone.numberOfLoops = -1
            speakerEnabled(false)
            playerRingBackTone.play()
            return true
        }
        return false
    }

    func stopRingBackTone() -> Bool {
        if playerRingBackTone != nil, playerRingBackTone.isPlaying {
            playerRingBackTone.stop()
            speakerEnabled(true)
        }
        return true
    }

    private func initPlayerWithPath(_ fileName: String, fromPlugin: Bool = false) -> AVAudioPlayer? {
        let bundle: Bundle
        if fromPlugin {
            // Replace `PluginClassName` with an actual class from your plugin
            guard let pluginBundle = Bundle(for: MptCallkitPlugin.self).url(forResource: "mpt_callkit", withExtension: "bundle"),
                  let resourceBundle = Bundle(url: pluginBundle) else {
                NSLog("ERROR: Could not locate plugin bundle.")
                return nil
            }
            bundle = resourceBundle
        } else {
            bundle = Bundle.main
        }
        
        // Fetch the file path
        guard let path = bundle.path(forResource: fileName, ofType: nil) else {
            NSLog("ERROR: Could not find audio file \(fileName).")
            return nil
        }

        let url = URL(fileURLWithPath: path)
        var player: AVAudioPlayer?

        do {
            player = try AVAudioPlayer(contentsOf: url)
        } catch {
            NSLog("ERROR: Could not initialize AVAudioPlayer. \(error.localizedDescription)")
        }

        return player
    }
}
