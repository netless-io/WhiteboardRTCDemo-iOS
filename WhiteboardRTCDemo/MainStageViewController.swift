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

    var useWhiteboard = false

    deinit {
        print("destory main stage vc deinit")
        destory()
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
        view.addSubview(logView)

        agoraKit.joinChannel(byToken: joinInfo.rtcToken, channelId: joinInfo.roomUUID, info: nil, uid: UInt(joinInfo.rtcUID)) { [weak self] _, _, elapsed in
            guard let self else { return }
            let _ = self.whiteboardView
            self.append(log: "join rtc elapsed \(elapsed)")
            self.agoraKit.enableAudio()
            self.agoraKit.enableVideo()
            
//            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
//                let src = "https://flat-storage.oss-accelerate.aliyuncs.com/cloud-storage/2024-02/27/4e267833-5662-4150-ab20-cb610ae1dcc0/4e267833-5662-4150-ab20-cb610ae1dcc0.mp4"
////                let src = "https://qiniustatic.wodidashi.com/h5/front-backstage/%E8%A6%81%E8%B7%9F%E6%88%91%E5%9C%A8%E4%B8%80%E8%B5%B7%E7%8A%AF%E5%80%8B%E8%A6%8F%E5%97%8E_1662359064350.mp3"
//                self.agoraKit.playEffect(999, filePath: src, loopCount: 0, pitch: 1, pan: 0, gain: 100)
//                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
//                    print("/State/ start set effect position")
//                    self.agoraKit.setEffectPosition(999, pos: 3000000)
//                }
//            }
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
                let sdk = WhiteSDK(whiteBoardView: whiteboardView!, config: sdkConfig, commonCallbackDelegate: self, effectMixerBridgeDelegate: self.whiteboardConfig.pptMix ? self : nil)
                return sdk
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
    var whiteboardView: WhiteBoardView?

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

    func rtcEngineDidAudioEffectFinish(_: AgoraRtcEngineKit, soundId: Int) {
        sdk?.effectMixer?.setEffectFinished(soundId)
    }

    func rtcEngine(_: AgoraRtcEngineKit, didRequest info: AgoraRtcAudioFileInfo, error _: AgoraAudioFileInfoError) {
        sdk?.effectMixer?.setEffectDurationUpdate(info.filePath, duration: Int(info.durationMs))
    }

    func rtcEngineDidAudioEffectStateChanged(_: AgoraRtcEngineKit, soundId: Int, state: AgoraAudioEffectStateCode) {
        sdk?.effectMixer?.setEffectSoundId(soundId, stateChanged: state.rawValue)
        print("/State/ soundId:\(soundId), state:\(state.rawValue)")
    }
}

extension MainStageViewController: WhiteAudioEffectMixerBridgeDelegate {
    func getEffectsVolume() -> Double {
        agoraKit.getEffectsVolume()
    }
    
    func setEffectsVolume(_ volume: Double) -> Int32 {
        agoraKit.setEffectsVolume(volume)
    }
    
    func setVolumeOfEffect(_ soundId: Int32, withVolume volume: Double) -> Int32 {
        agoraKit.setVolumeOfEffect(soundId, withVolume: volume)
    }
    
    func playEffect(_ soundId: Int32, filePath: String?, loopCount: Int32, pitch: Double, pan: Double, gain: Double, publish: Bool, startPos: Int32) -> Int32 {
        // TODO: Has difference with seek behavior.
//        agoraKit.playEffect(soundId, filePath: filePath, loopCount: loopCount, pitch: pitch, pan: pan, gain: gain, publish: publish, startPos: startPos)
        agoraKit.playEffect(soundId, filePath: filePath, loopCount: loopCount, pitch: pitch, pan: pan, gain: gain, publish: publish)
    }
    
    func stopEffect(_ soundId: Int32) -> Int32 {
        agoraKit.stopEffect(soundId)
    }
    
    func stopAllEffects() -> Int32 {
        agoraKit.stopAllEffects()
    }
    
    func preloadEffect(_ soundId: Int32, filePath: String?) -> Int32 {
        agoraKit.preloadEffect(soundId, filePath: filePath)
    }
    
    func unloadEffect(_ soundId: Int32) -> Int32 {
        agoraKit.unloadEffect(soundId)
    }
    
    func pauseEffect(_ soundId: Int32) -> Int32 {
        agoraKit.pauseEffect(soundId)
    }
    
    func pauseAllEffects() -> Int32 {
        agoraKit.pauseAllEffects()
    }
    
    func resumeEffect(_ soundId: Int32) -> Int32 {
        agoraKit.resumeEffect(soundId)
    }
    
    func resumeAllEffects() -> Int32 {
        agoraKit.resumeAllEffects()
    }
    
    func setEffectPosition(_ soundId: Int32, pos: Int) -> Int32 {
        agoraKit.setEffectPosition(soundId, pos: pos)
    }
    
    func getEffectCurrentPosition(_ soundId: Int32) -> Int32 {
        agoraKit.getEffectCurrentPosition(soundId)
    }
    
    func getEffectDuration(_ filePath: String) -> Int32 {
        agoraKit.getEffectDuration(filePath)
    }
}

//extension AgoraRtcEngineKit: WhiteAudioEffectMixerBridgeDelegate {}

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
