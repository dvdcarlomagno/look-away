import CoreAudio
import Foundation

@MainActor
final class MicrophoneMonitor: ObservableObject {
    @Published private(set) var isMicActive = false

    private var propertyListenerBlock: AudioObjectPropertyListenerBlock?
    private var deviceListenerBlock: AudioObjectPropertyListenerBlock?
    private var observedDeviceID: AudioDeviceID?

    init() {
        startMonitoring()
    }

    private func startMonitoring() {
        refreshMicState()

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in
                self?.attachDeviceListener()
            }
        }
        propertyListenerBlock = block

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main,
            block
        )

        attachDeviceListener()
    }

    private func attachDeviceListener() {
        guard let deviceID = defaultInputDeviceID() else {
            refreshMicState()
            return
        }

        if observedDeviceID == deviceID, deviceListenerBlock != nil {
            refreshMicState()
            return
        }

        if let observedDeviceID, let deviceListenerBlock {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(
                observedDeviceID,
                &address,
                DispatchQueue.main,
                deviceListenerBlock
            )
        }

        observedDeviceID = deviceID

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in
                self?.refreshMicState()
            }
        }
        deviceListenerBlock = block

        AudioObjectAddPropertyListenerBlock(deviceID, &address, DispatchQueue.main, block)
        refreshMicState()
    }

    private func refreshMicState() {
        let active = Self.checkMicrophoneInUse()
        guard active != isMicActive else { return }
        isMicActive = active
    }

    private func defaultInputDeviceID() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        return status == noErr ? deviceID : nil
    }

    nonisolated static func checkMicrophoneInUse() -> Bool {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        ) == noErr else {
            return false
        }

        var isRunning: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        var runningAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(deviceID, &runningAddress, 0, nil, &size, &isRunning) == noErr else {
            return false
        }
        return isRunning != 0
    }
}
