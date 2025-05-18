//
//  MainStageViewController.swift
//  WhiteboardWithRtc
//
//  Created by xuyunshi on 2024/1/29.
//

import AgoraRtcKit
import UIKit
import Whiteboard

struct WhiteboardConfig {
    let usePcm: Bool
    let customUrl: String?
}

struct MainStageViewConfig {
    let joinInfo: JoinInfo
    let whiteboardConfig: WhiteboardConfig
    let useWhiteboard: Bool
}

class MainStageViewController: UIViewController {
    let joinInfo: JoinInfo
    let whiteboardConfig: WhiteboardConfig
    var room: WhiteRoom?
    var sampleRate = 48000, channel = 1, bitPerSample = 16, samples = 1440
    lazy var pcmDataQueue = SafeQueue<Int16>(maxSize: samples * 10)

    init(config: MainStageViewConfig) {
        joinInfo = config.joinInfo
        whiteboardConfig = config.whiteboardConfig
        useWhiteboard = config.useWhiteboard
        super.init(nibName: nil, bundle: nil)
    }

    lazy var agoraKit: AgoraRtcEngineKit = {
        let config = AgoraRtcEngineConfig()
        config.appId = "a185de0a777f4c159e302abcc0f03b64"
        let agoraKit = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        agoraKit.setDefaultAudioRouteToSpeakerphone(true)
        agoraKit.setAudioProfile(.default, scenario: .communication)
        if self.whiteboardConfig.usePcm {
            agoraKit.setParameters("{\"che.audio.start_debug_recording\":\"all\"}")
            agoraKit.setParameters("{\"che.audio.echo.control.solo\": true}")
            agoraKit.setAudioDataFrame(self)
        }
        return agoraKit
    }()

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    let useWhiteboard: Bool

    deinit {
        print("destory main stage vc deinit")
        destroy()
    }

    func destroy() {
        room?.disconnect()
        agoraKit.leaveChannel()
        agoraKit.setAudioDataFrame(nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    func setup() {
        view.backgroundColor = .gray
        view.addSubview(logView)

        agoraKit.joinChannel(byToken: joinInfo.rtcToken, channelId: joinInfo.roomUUID, info: nil, uid: UInt(joinInfo.rtcUID)) { [weak self] _, _, elapsed in
            guard let self else { return }
            self.append(log: "join rtc elapsed \(elapsed)")
            self.agoraKit.enableAudio()
            self.agoraKit.enableVideo()
        }

        if useWhiteboard {
            whiteboardView = {
                if let url = whiteboardConfig.customUrl {
                    return WhiteBoardView(customUrl: url)
                }
                return WhiteBoardView()
            }()
            sdk = {
                let sdkConfig = WhiteSdkConfiguration(app: "sdfsdf/dsf")
                sdkConfig.useMultiViews = true
                sdkConfig.log = true
                sdkConfig.loggerOptions = ["printLevelMask": WhiteSDKLoggerOptionLevelKey.debug.rawValue]
                if whiteboardConfig.usePcm {
                    let sdk = WhiteSDK(whiteBoardView: whiteboardView!, config: sdkConfig, commonCallbackDelegate: self, pcmDataDelegate: self)
                    return sdk
                } else {
                    let sdk = WhiteSDK(whiteBoardView: whiteboardView!, config: sdkConfig, commonCallbackDelegate: self)
                    return sdk
                }
            }()

            view.addSubview(whiteboardView!)
            let whiteconfig = WhiteRoomConfig(uuid: joinInfo.whiteboardRoomUUID, roomToken: joinInfo.whiteboardRoomToken, uid: "myuid")
            whiteconfig.isWritable = true
            sdk!.joinRoom(with: whiteconfig, callbacks: self) { [weak self] _, room, error in
                guard let self else { return }
                if let error {
                    self.append(log: "join room error \(error)")
                    return
                }
                self.append(log: "join room success")
                self.room = room
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let ratio = 16.0 / 9.0
        if view.bounds.height > view.bounds.width {
            let whiteboardWidth = view.bounds.width
            let whiteboardHeight = view.bounds.width / ratio
            whiteboardView?.frame = .init(x: 0, y: 0, width: whiteboardWidth, height: whiteboardHeight)

            let logHeight = view.bounds.height - (whiteboardView?.bounds.height ?? 0)
            logView.frame = .init(x: 0, y: view.bounds.height - logHeight, width: view.bounds.width, height: logHeight)
        } else {
            let whiteboardWidth = view.bounds.width / 2
            let whiteboardHeight = view.bounds.width / ratio
            whiteboardView?.frame = .init(x: 0, y: 0, width: whiteboardWidth, height: whiteboardHeight)

            let logWidth = view.bounds.width - (whiteboardView?.bounds.width ?? 0)
            logView.frame = .init(x: whiteboardWidth, y: 0, width: logWidth, height: view.bounds.height)
        }
    }

    var sdk: WhiteSDK?
    weak var whiteboardView: WhiteBoardView?

    lazy var logView: UITextView = {
        let view = UITextView(frame: .zero)
        view.isEditable = false
        view.backgroundColor = .lightGray
        return view
    }()

    func append(log: String) {
        logView.text.append("\(Date()) : " + log + "\n")
        print(log)
        if !logView.isDragging {
            logView.setContentOffset(.init(x: 0, y: logView.contentSize.height - logView.bounds.height), animated: true)
        }
    }
}

extension MainStageViewController: AgoraRtcEngineDelegate, WhiteCommonCallbackDelegate, WhiteRoomCallbackDelegate {
    func logger(_ dict: [AnyHashable: Any]) {
        if let consoleLog = dict["[WhiteWKConsole]"] as? String {
            append(log: "console: \(consoleLog)")
        } else {
            append(log: dict.description)
        }
    }

    func rtcEngine(_: AgoraRtcEngineKit, connectionChangedTo state: AgoraConnectionStateType, reason: AgoraConnectionChangedReason) {
        append(log: "/State/RTC Connect/ state: \(state.description) reason: \(reason.description)")
    }
}

extension MainStageViewController: WhiteAudioPcmDataDelegate {
    func pcmDataUpdate(_ int16Array: [NSNumber]) {
        if let array = int16Array as? [Int16] {
            pcmDataQueue.enqueue(array)
        }
    }
}

extension MainStageViewController: AgoraAudioDataFrameProtocol {
    func onRecordAudioFrame(_: AgoraAudioFrame) -> Bool {
        return true
    }

    func onMixedAudioFrame(_: AgoraAudioFrame) -> Bool {
        return true
    }

    func onPlaybackAudioFrame(beforeMixing _: AgoraAudioFrame, uid _: UInt) -> Bool {
        return true
    }

    func getObservedAudioFramePosition() -> AgoraAudioFramePosition {
        return .playback
    }

    func getMixedAudioParams() -> AgoraAudioParam {
        let param = AgoraAudioParam()
        param.channel = 1
        param.mode = .readOnly
        param.sampleRate = 44100
        param.samplesPerCall = 1024
        return param
    }

    func getRecordAudioParams() -> AgoraAudioParam {
        let param = AgoraAudioParam()
        param.channel = 1
        param.mode = .readOnly
        param.sampleRate = 44100
        param.samplesPerCall = 1024
        return param
    }

    func getPlaybackAudioParams() -> AgoraAudioParam {
        let param = AgoraAudioParam()
        param.channel = channel
        param.mode = .readWrite
        param.sampleRate = sampleRate
        param.samplesPerCall = samples * channel
        return param
    }

    func onPlaybackAudioFrame(_ frame: AgoraAudioFrame) -> Bool {
        if let data = pcmDataQueue.dequeue(count: samples * channel) {
            let count = data.count * MemoryLayout<Int16>.size
            let data = Data(bytes: data, count: count)
            data.withUnsafeBytes { (pcmBuffer: UnsafeRawBufferPointer) in
                guard let addr = pcmBuffer.baseAddress else {
                    memset(frame.buffer, 0, count)
                    return
                }
                memcpy(frame.buffer, addr, count)
            }
            frame.samplesPerSec = sampleRate
            frame.channels = channel
            frame.bytesPerSample = bitPerSample / 8
            frame.samplesPerChannel = samples
        } else {
            memset(frame.buffer, 0, samples * channel * 2)
        }
        return true
    }
}


extension AgoraConnectionStateType: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .disconnected: "disconnected"
        case .connecting: "connecting"
        case .connected: "connected"
        case .reconnecting: "reconnecting"
        case .failed: "failed"
        @unknown default: "default"
        }
    }
}

extension AgoraConnectionChangedReason: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .connecting: "connecting"
        case .joinSuccess: "joinSuccess"
        case .interrupted: "interrupted"
        case .bannedByServer: "bannedByServer"
        case .joinFailed: "joinFailed"
        case .leaveChannel: "leaveChannel"
        case .invalidAppId: "invalidAppId"
        case .invalidChannelName: "invalidChannelName"
        case .invalidToken: "invalidToken"
        case .tokenExpired: "tokenExpired"
        case .rejectedByServer: "rejectedByServer"
        case .settingProxyServer: "settingProxyServer"
        case .renewToken: "renewToken"
        case .clientIpAddressChanged: "clientIpAddressChanged"
        case .keepAliveTimeout: "keepAliveTimeout"
        case .sameUidLogin: "sameUidLogin"
        case .tooManyBroadcasters: "tooManyBroadcasters"
        @unknown default: "default"
        }
    }
}
