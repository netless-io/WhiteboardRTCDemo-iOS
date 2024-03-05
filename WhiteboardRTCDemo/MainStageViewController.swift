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
    let pptMix: Bool
    let customUrl: String?
}

struct MainStageViewConfig {
    let joinInfo: JoinInfo
    let whiteboardConfig: WhiteboardConfig
}

class MainStageViewController: UIViewController {
    let joinInfo: JoinInfo
    let whiteboardConfig: WhiteboardConfig
    var room: WhiteRoom?

    init(config: MainStageViewConfig) {
        joinInfo = config.joinInfo
        whiteboardConfig = config.whiteboardConfig
        super.init(nibName: nil, bundle: nil)
    }

    lazy var agoraKit: AgoraRtcEngineKit = {
        let config = AgoraRtcEngineConfig()
        config.appId = "a185de0a777f4c159e302abcc0f03b64"
        let agoraKit = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        agoraKit.setDefaultAudioRouteToSpeakerphone(true)
        return agoraKit
    }()

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func destory() {
        room?.disconnect()
        agoraKit.leaveChannel()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    func setup() {
        view.backgroundColor = .gray
        view.addSubview(whiteboardView)
        view.addSubview(logView)

        agoraKit.joinChannel(byToken: joinInfo.rtcToken, channelId: joinInfo.roomUUID, info: nil, uid: UInt(joinInfo.rtcUID)) { _, _, elapsed in
            self.append(log: "join rtc elapsed \(elapsed)")
            self.agoraKit.enableAudio()
            self.agoraKit.enableVideo()
        }

        let whiteconfig = WhiteRoomConfig(uuid: joinInfo.whiteboardRoomUUID, roomToken: joinInfo.whiteboardRoomToken, uid: "myuid")
        whiteconfig.isWritable = true
        sdk.joinRoom(with: whiteconfig, callbacks: self) { _, room, error in
            if let error {
                self.append(log: "join room error \(error)")
                return
            }
            self.append(log: "join room success")
            self.room = room
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let ratio = 16.0 / 9.0
        
        if view.bounds.height > view.bounds.width {
            let whiteboardWidth = view.bounds.width
            let whiteboardHeight = view.bounds.width / ratio
            whiteboardView.frame = .init(x: 0, y: 0, width: whiteboardWidth, height: whiteboardHeight)
            
            let logHeight = view.bounds.height - whiteboardView.bounds.height
            logView.frame = .init(x: 0, y: view.bounds.height - logHeight, width: view.bounds.width, height: logHeight)
        } else {
            let whiteboardWidth = view.bounds.width / 2
            let whiteboardHeight = view.bounds.width / ratio
            whiteboardView.frame = .init(x: 0, y: 0, width: whiteboardWidth, height: whiteboardHeight)
            
            let logWidth = view.bounds.width - whiteboardView.bounds.width
            logView.frame = .init(x: whiteboardWidth, y: 0, width: logWidth, height: view.bounds.height)
        }
    }

    lazy var sdk: WhiteSDK = {
        let sdkConfig = WhiteSdkConfiguration(app: "sdfsdf/dsf")
        sdkConfig.useMultiViews = true
        sdkConfig.log = true
        sdkConfig.loggerOptions = ["printLevelMask": WhiteSDKLoggerOptionLevelKey.debug.rawValue]
        let sdk = WhiteSDK(whiteBoardView: whiteboardView, config: sdkConfig, commonCallbackDelegate: self, audioMixerBridgeDelegate: self)
        return sdk
    }()

    lazy var whiteboardView: WhiteBoardView = {
        if let url = whiteboardConfig.customUrl {
            return WhiteBoardView(customUrl: url)
        }
        return WhiteBoardView()
    }()

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

extension MainStageViewController: WhiteAudioMixerBridgeDelegate {
    func startAudioMixing(_ filePath: String, loopback: Bool, replace: Bool, cycle: Int) {
        agoraKit.startAudioMixing(filePath, loopback: loopback, replace: replace, cycle: cycle, startPos: 0)
    }
    
    func stopAudioMixing() {
        agoraKit.stopAudioMixing()
    }
    
    func pauseAudioMixing() {
        agoraKit.pauseAudioMixing()
    }
    
    func resumeAudioMixing() {
        agoraKit.resumeAudioMixing()
    }
    
    func setAudioMixingPosition(_ position: Int) {
        agoraKit.setAudioMixingPosition(position)
    }
}


extension MainStageViewController: AgoraRtcEngineDelegate, WhiteCommonCallbackDelegate, WhiteRoomCallbackDelegate {
    func logger(_ dict: [AnyHashable : Any]) {
        append(log: dict.description)
    }
    
    func rtcEngine(_: AgoraRtcEngineKit, connectionChangedTo state: AgoraConnectionStateType, reason: AgoraConnectionChangedReason) {
        append(log: "rtc connection changed \(state), reason: \(reason)")
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, localAudioMixingStateDidChanged state: AgoraAudioMixingStateCode, reason: AgoraAudioMixingReasonCode) {
        sdk.audioMixer?.setMediaState(state.rawValue, errorCode: Int(reason.rawValue))
        print("audio mixing local state \(state.rawValue), reason: \(reason.rawValue)")
    }
}

extension AgoraConnectionStateType: CustomStringConvertible {
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

extension AgoraConnectionChangedReason: CustomStringConvertible {
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
