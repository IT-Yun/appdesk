import Foundation

public enum ManagedAppID: String, Codable, CaseIterable, Identifiable, Sendable {
    case chagok, wru, torrens, flinders
    public var id: String { rawValue }
    public var name: String { switch self { case .chagok: "차곡"; case .wru: "WRU"; case .torrens: "Torrens Market"; case .flinders: "Flinders Collab" } }
    public var symbol: String { switch self { case .chagok: "calendar"; case .wru: "antenna.radiowaves.left.and.right"; case .torrens: "bag"; case .flinders: "person.3" } }
    public var detail: String { switch self { case .chagok: "플래너 · 가계부"; case .wru: "무전 · 위치 연결"; case .torrens: "중고거래 · 세 언어"; case .flinders: "팀 협업 · 대학 생활" } }
}
public struct AppDeskConnection: Codable, Equatable, Sendable {
    public var url: String
    public var token: String
    public init(url: String, token: String) { self.url = url; self.token = token }
    public func validated() throws -> Self {
        guard let address = URLComponents(string: url), address.scheme == "https", address.host?.hasSuffix(".chatgpt.site") == true,
              address.user == nil, address.password == nil, address.query == nil, address.fragment == nil,
              address.port == nil || address.port == 443, address.path.isEmpty || address.path == "/",
              token.count >= 32, token.utf8.count <= 8192,
              !token.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.union(.controlCharacters).contains($0) }) else { throw AppDeskProtocolError.invalid }
        return self
    }
}
public enum AppDeskProtocolError: Error { case invalid, wrongApp, conflictingRequest }
public struct AppDeskCheck: Codable, Equatable, Sendable { public var command: String; public var exitCode: Int? }
public struct AppDeskMessage: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var appID: ManagedAppID
    public var text: String
    public var sentAt: Double
    public var timeZone: String
    public var state: String
    public var reply: String
    public var updatedAt: Double
    public var commit: String?
    public var runID: Int?
    public var checks: [AppDeskCheck]
    public var error: String?
    public var submitted: Bool?
    public init(appID: ManagedAppID, text: String, now: Date = Date(), timeZone: TimeZone = .current) {
        id = UUID(); self.appID = appID; self.text = text; sentAt = now.timeIntervalSince1970; self.timeZone = timeZone.identifier
        state = "local"; reply = "기기에 보관했어요. 연결되면 같은 요청을 다시 전달합니다."; updatedAt = sentAt; checks = []; submitted = false
    }
    public var terminal: Bool { ["built", "published", "no_changes", "failed", "review_required"].contains(state) }
    public var statusLabel: String {
        switch state {
        case "local": "전송 대기"
        case "queued", "dispatched": "실행 대기"
        case "preparing", "starting": "소스 확인"
        case "developing": "앱 수정 중"
        case "testing": "검사 중"
        case "building", "build_pending": "빌드 확인 중"
        case "built": "빌드 완료 · 배포 확인"
        case "published": "업데이트 배포됨"
        case "no_changes": "답변 완료"
        case "review_required": "다음 단계 확인 필요"
        case "quota": "구독 한도 대기"
        case "authentication": "연결 확인 필요"
        case "failed": "작업 결과 확인 필요"
        default: "연결 확인 중"
        }
    }
}
public enum AppDeskMerge {
    public static func apply(_ incoming: [AppDeskMessage], app: ManagedAppID, to existing: inout [AppDeskMessage]) throws {
        guard incoming.allSatisfy({ $0.appID == app && $0.text.count <= 16000 && $0.reply.count <= 20000 && $0.sentAt.isFinite && $0.updatedAt.isFinite }) else { throw AppDeskProtocolError.wrongApp }
        var next = existing
        for var message in incoming {
            message.submitted = true
            if let index = next.firstIndex(where: { $0.id == message.id }) {
                let old = next[index]
                guard old.appID == message.appID, old.text == message.text, abs(old.sentAt - message.sentAt) < 0.001, old.timeZone == message.timeZone else { throw AppDeskProtocolError.conflictingRequest }
                // The first receipt uses the server clock, even if the device clock was ahead.
                if old.submitted != true || message.updatedAt >= old.updatedAt { next[index] = message }
            } else { next.append(message) }
        }
        existing = next.sorted { $0.sentAt < $1.sentAt }
    }
}
