import AppKit
import AVFoundation

/// Plays the chosen alert once, and loops the soft tick during work.
@MainActor
final class SoundPlayer {
    private var alert: NSSound?
    private var ticker: AVAudioPlayer?

    func play(_ sound: AlertSound, volume: Double) {
        switch sound {
        case .none:
            return
        case .systemDefault:
            NSSound.beep()
        default:
            guard let name = sound.fileName,
                  let url = Bundle.main.url(forResource: name, withExtension: "aiff", subdirectory: "Sounds")
                    ?? Bundle.main.url(forResource: name, withExtension: "aiff"),
                  let nsSound = NSSound(contentsOf: url, byReference: true) else { return }
            alert?.stop()
            nsSound.volume = Float(volume)
            nsSound.play()
            alert = nsSound
        }
    }

    /// Start or stop the tick loop. Safe to call repeatedly.
    func setTicking(_ active: Bool, volume: Double) {
        if active {
            if ticker == nil,
               let url = Bundle.main.url(forResource: "Tick", withExtension: "aiff", subdirectory: "Sounds")
                ?? Bundle.main.url(forResource: "Tick", withExtension: "aiff"),
               let player = try? AVAudioPlayer(contentsOf: url) {
                player.numberOfLoops = -1
                player.prepareToPlay()
                ticker = player
            }
            ticker?.volume = Float(volume)
            if ticker?.isPlaying == false { ticker?.play() }
        } else {
            ticker?.stop()
            ticker = nil
        }
    }
}
