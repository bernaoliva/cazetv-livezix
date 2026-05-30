// LiveZix CazéTV — fork do Moblin
// Modelo e fetcher das credenciais por rep. App busca essas infos do server
// LiveZix uma vez ao escolher rep no onboarding e salva localmente no Database.
import Foundation
import SwiftUI

struct LiveZixCredentials: Codable {
    let rep: Int
    let device: String           // "SRT_LIVEMODE_05"
    let srtUrl: String           // "srt://189.84...:5015?streamid=...&mode=caller&latency=2000"
    let assistantUrl: String     // "ws://livezix.livemode.space:9001/moblin/SRT_LIVEMODE_05"
    let password: String
    // Config persistente editável no painel (tuner.html). Opcionais p/ compat com server antigo.
    let resolution: String?      // "1920x1080" | "1280x720" | "960x540" | "640x480"
    let fps: Int?                // 60 | 50 | 30 | 25
    let latency: Int?            // ms — latência SRT (default 2000)

    enum CodingKeys: String, CodingKey {
        case rep
        case device
        case srtUrl = "srt_url"
        case assistantUrl = "assistant_url"
        case password
        case resolution
        case fps
        case latency
    }
}

enum LiveZixApiError: Error, LocalizedError {
    case invalidUrl
    case http(Int)
    case decoding(String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidUrl: return "URL do servidor LiveZix inválida"
        case .http(let code): return "Servidor LiveZix respondeu HTTP \(code)"
        case .decoding(let s): return "Resposta inválida do servidor: \(s)"
        case .network(let s): return "Falha de rede: \(s)"
        }
    }
}

class LiveZixApi {
    /// Busca credenciais no servidor LiveZix pra um rep específico.
    /// Servidor expõe GET /api/moblin_creds?rep=N — público (segurança via password).
    static func fetchCredentials(rep: Int) async throws -> LiveZixCredentials {
        guard var components = URLComponents(string: LiveZixConfig.serverBaseUrl + LiveZixConfig.credsApiPath) else {
            throw LiveZixApiError.invalidUrl
        }
        components.queryItems = [URLQueryItem(name: "rep", value: String(rep))]
        guard let url = components.url else { throw LiveZixApiError.invalidUrl }

        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw LiveZixApiError.network("resposta sem status HTTP")
            }
            if http.statusCode < 200 || http.statusCode >= 300 {
                throw LiveZixApiError.http(http.statusCode)
            }
            do {
                let creds = try JSONDecoder().decode(LiveZixCredentials.self, from: data)
                return creds
            } catch {
                throw LiveZixApiError.decoding(error.localizedDescription)
            }
        } catch let api as LiveZixApiError {
            throw api
        } catch {
            throw LiveZixApiError.network(error.localizedDescription)
        }
    }

    /// Aplica as credenciais ao Database/stream do Moblin. Reutilizado pelo onboarding
    /// (com Remote Control) e ao sair do ar (só stream, sem mexer no RC pra não derrubar
    /// a conexão de controle). resolution/fps/latency vêm do painel (config persistente).
    @MainActor
    static func applyCredentials(_ creds: LiveZixCredentials, to model: Model, includeRemoteControl: Bool) {
        let db = model.database
        let streamName = "CazéTV — \(LiveZixConfig.studioName(rep: creds.rep))"
        let stream: SettingsStream
        if let existing = db.streams.first(where: { $0.name == streamName }) {
            stream = existing
        } else {
            stream = SettingsStream(name: streamName)
            db.streams.append(stream)
        }
        stream.url = creds.srtUrl
        stream.enabled = true
        stream.codec = .h264avc
        if let r = creds.resolution, let res = SettingsStreamResolution(rawValue: r) {
            stream.resolution = res
        } else {
            stream.resolution = .r1920x1080
        }
        stream.fps = creds.fps ?? 60
        stream.bitrate = 6_000_000
        stream.audioBitrate = 128_000
        stream.srt.latency = Int32(creds.latency ?? 2000)
        if includeRemoteControl {
            db.remoteControl.streamer.enabled = true
            db.remoteControl.streamer.url = creds.assistantUrl
            db.remoteControl.password = creds.password
        }
        model.setCurrentStream(stream: stream)
        model.storeSettings()
    }
}
