//
//  ContentView.swift
//  WhiteboardRTCDemo
//
//  Created by xuyunshi on 2024/2/2.
//

import AgoraRtcKit
import SwiftUI
import Whiteboard

struct MainStageRepresentView: UIViewControllerRepresentable {
    func updateUIViewController(_: MainStageViewController, context _: Context) {}

    let config: MainStageViewConfig

    static func dismantleUIViewController(_ uiViewController: MainStageViewController, coordinator _: ()) {
        uiViewController.destory()
    }

    func makeUIViewController(context _: Context) -> MainStageViewController {
        return MainStageViewController(config: config)
    }
}

struct ContentView: View {
    @AppStorage("rtcChannelId") var rtcChannelId: String = ""
    @AppStorage("rtcToken") var rtcToken: String = ""
    @AppStorage("rtcUid") var rtcUid: Int = 0
    @AppStorage("whiteRoomUuid") var whiteRoomUuid: String = ""
    @AppStorage("region") var region: String = ""
    @AppStorage("whiteRoomToken") var whiteRoomToken: String = ""
    @AppStorage("usePptEffectMix") var usePptEffectMix: Bool = true

    @AppStorage("useCustomWhiteboardURL") var useCustomWhiteboardURL: Bool = false
    @AppStorage("customWhiteboardURL") var customWhiteboardURL: String = ""

    @State var status: String = ""
    @State var showMainStage = false

    var body: some View {
        NavigationView {
            mainContentView()
        }
    }

    func mainContentView() -> some View {
        ScrollView {
            VStack {
                Label {
                    TextField("rtcChannelId", text: $rtcChannelId)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .multilineTextAlignment(.trailing)
                } icon: {
                    Text("RTC Channel")
                }
                Label {
                    TextField("rtcToken", text: $rtcToken)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .multilineTextAlignment(.trailing)
                } icon: {
                    Text("RTC Token")
                }
                Label {
                    TextField("RTC Uid", text: .init(get: {
                        rtcUid.description
                    }, set: { i in
                        rtcUid = Int(i) ?? 0
                    }))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .multilineTextAlignment(.trailing)
                } icon: {
                    Text("RTC Uid")
                }
                Label {
                    TextField("whiteRoomUuid", text: $whiteRoomUuid)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .multilineTextAlignment(.trailing)
                } icon: {
                    Text("WhiteRoom UUID")
                }
                Label {
                    TextField("whiteRoomToken", text: $whiteRoomToken)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .multilineTextAlignment(.trailing)
                } icon: {
                    Text("WhiteRoom Token")
                }
                Label {
                    TextField("WhiteRoom Region", text: $region)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .multilineTextAlignment(.trailing)
                } icon: {
                    Text("WhiteRoom region")
                }
                Toggle("PptEffectMix", isOn: $usePptEffectMix)

                Toggle("Custom WB URL", isOn: $useCustomWhiteboardURL)
                if useCustomWhiteboardURL {
                    TextField("Input Custom WB URL", text: $customWhiteboardURL)
                        .multilineTextAlignment(.trailing)
                        .onAppear {
                            if customWhiteboardURL.isEmpty {
                                customWhiteboardURL = "http://10.6.0.90:8080"
                            }
                        }
                }

                HStack {
                    Button(action: {
                        generateNewFromFlatDev()
                    }, label: {
                        Text("New")
                        Image(systemName: "plus.square")
                    })
                    .foregroundColor(.white)
                    .font(.headline)
                    .padding(14)
                    .background(Capsule().fill(.red))

                    Button {
                        showMainStage.toggle()
                    } label: {
                        Text("Enter Now")
                            .foregroundColor(.white)
                            .font(.headline)
                            .padding(14)
                            .background(Capsule().fill(.blue))
                    }
                    .disabled(
                        rtcChannelId.isEmpty ||
                            rtcToken.isEmpty ||
                            rtcUid == 0 ||
                            whiteRoomUuid.isEmpty ||
                            whiteRoomToken.isEmpty
                    )
                    .fullScreenCover(isPresented: $showMainStage,
                           content: {
                               let joinInfo = JoinInfo(
                                   rtcToken: rtcToken,
                                   rtcUID: rtcUid,
                                   whiteboardRoomToken: whiteRoomToken,
                                   whiteboardRoomUUID: whiteRoomUuid,
                                   roomUUID: rtcChannelId,
                                   region: region
                               )
                               let whiteboardConfig = WhiteboardConfig(pptMix: usePptEffectMix, customUrl: useCustomWhiteboardURL ? customWhiteboardURL : nil)
                               NavigationView {
                                   MainStageRepresentView(
                                       config: .init(joinInfo: joinInfo, whiteboardConfig: whiteboardConfig)
                                   )
                                   .toolbar {
                                       ToolbarItemGroup(placement: .navigation) {
                                           Button("Close") {
                                               showMainStage = false
                                           }
                                           Button("Copy Web Link") {
                                               UIPasteboard.general.string = "https://demo.whiteboard.agora.io/room/\(joinInfo.whiteboardRoomUUID)?token=\(joinInfo.whiteboardRoomToken)&region=\(joinInfo.region)"
                                           }
                                       }
                                   }
                               }
                           })
                }.padding(.horizontal)

                if #available(iOS 16.0, *) {
                    let info = JoinInfo(rtcToken: rtcToken, rtcUID: rtcUid, whiteboardRoomToken: whiteRoomToken, whiteboardRoomUUID: whiteRoomUuid, roomUUID: rtcChannelId, region: region)
                    let str = String(data: try! JSONEncoder().encode(info), encoding: .utf8)!
                    let _ = UIPasteboard.general.string = str
                    ShareLink(item: str) {
                        Text("Copy Info And Share")
                            .foregroundColor(.white)
                            .font(.headline)
                            .padding(14)
                            .background(Capsule().fill(.blue))
                    }
                } else {
                    Button {
                        let info = JoinInfo(rtcToken: rtcToken, rtcUID: rtcUid, whiteboardRoomToken: whiteRoomToken, whiteboardRoomUUID: whiteRoomUuid, roomUUID: rtcChannelId, region: region)
                        let str = String(data: try! JSONEncoder().encode(info), encoding: .utf8)!
                        UIPasteboard.general.string = str
                    } label: {
                        Text("Copy Info")
                            .foregroundColor(.white)
                            .font(.headline)
                            .padding(14)
                            .background(Capsule().fill(.blue))
                    }
                }

                if #available(iOS 16.0, *) {
                    PasteButton(payloadType: String.self) { strs in
                        guard let str = strs.first else { return }
                        applyFromString(str)
                    }
                } else {
                    Button {
                        guard let str = UIPasteboard.general.string else { return }
                        applyFromString(str)
                    } label: {
                        Text("Get Pasteboard")
                            .foregroundColor(.white)
                            .font(.headline)
                            .padding(14)
                            .background(Capsule().fill(.blue))
                    }
                }

                bottomView()
            }
        }
    }

    @ViewBuilder
    func bottomView() -> some View {
        Label(
            title: { Text("RTC Version") },
            icon: { Text(AgoraRtcEngineKit.getSdkVersion()) }
        )
        Label(
            title: { Text("Whiteboard  Version") },
            icon: { Text(WhiteSDK.version()) }
        )
        Text(status)
    }

    func applyFromString(_: String) {
        guard let data = UIPasteboard.general.string?.data(using: .utf8) else { return }
        do {
            let info = try JSONDecoder().decode(JoinInfo.self, from: data)
            guard !info.whiteboardRoomUUID.isEmpty else { return }
            apply(info)
        } catch {
            print("get value error \(error)")
        }
    }

    func apply(_ info: JoinInfo) {
        rtcChannelId = info.roomUUID
        rtcToken = info.rtcToken
        whiteRoomUuid = info.whiteboardRoomUUID
        whiteRoomToken = info.whiteboardRoomToken
        rtcUid = info.rtcUID
        region = info.region
    }

    func generateNewFromFlatDev() {
        status = "Start reqeust"
        var request = URLRequest(url: .init(string: "http://10.6.0.90:8888/create")!)
        request.httpMethod = "POST"
        URLSession.shared.dataTask(with: request) { data, _, _ in
            DispatchQueue.main.async {
                self.status = "Reqeust response"
                do {
                    if let data {
                        let info = try JSONDecoder().decode(JoinInfo.self, from: data)
                        // For old simulator. wtf.
                        status = "Start reqeust"
                        self.apply(info)
                        self.status = "Reqeust success"
                    }
                } catch {
                    print("error \(error)")
                    self.status = "Reqeust error \(error)"
                }
            }
        }.resume()
    }
}

#Preview {
    ContentView()
}

struct JoinInfo: Codable {
    let rtcToken: String
    let rtcUID: Int
    let whiteboardRoomToken: String
    let whiteboardRoomUUID: String
    let roomUUID: String
    let region: String
}

struct OData: Codable {
    let data: JoinInfo
}
