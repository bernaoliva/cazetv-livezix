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
    let resolution: String?      // "1920x1080" | "1280x720" | "960x540" | "854x480"
    let fps: Int?                // 60 | 50 | 30 | 25
    let latency: Int?            // ms — latência SRT (default 2000)
    // Config avançada completa (CONFIGURAÇÕES AVANÇADAS no painel). Aplicadas ao sair do ar.
    // Vídeo
    let bitrate: Int?            // kbps — bitrate de vídeo (default 6000)
    let codec: String?           // "h264" | "h265"
    let rateControl: String?     // "abr" | "cbr" | "vbr"
    let h264Profile: String?     // "baseline" | "main" | "high"
    let keyframe: Int?           // s — intervalo de keyframe (default 2)
    let bframes: Bool?           // B-frames
    let lowLight: Bool?          // low light boost
    let adaptiveResolution: Bool? // resolução adaptativa do encoder
    let adaptive: Bool?          // bitrate adaptativo (encoder) (default true)
    let portrait: Bool?          // modo retrato
    // Áudio
    let audioBitrate: Int?       // kbps — bitrate de áudio (default 128)
    let audioCodec: String?      // "aac" | "opus"
    // Transmissão (SRT)
    let srtOverhead: Int?        // % — overhead bandwidth (default 25)
    let srtMaxBwFollowInput: Bool? // seguir banda da entrada
    let srtAdaptive: Bool?       // bitrate adaptativo SRT
    let srtBigPackets: Bool?     // pacotes grandes (MTU)
    // Outras
    let timecodes: Bool?         // timecodes (requer H.265)
    let viewerDelay: Float?      // s — atraso estimado do espectador
    let backgroundStreaming: Bool? // transmitir em 2º plano
    let audioOnly: Bool?         // só áudio — previsto, ainda não aplicado (etapa futura)

    enum CodingKeys: String, CodingKey {
        case rep
        case device
        case srtUrl = "srt_url"
        case assistantUrl = "assistant_url"
        case password
        case resolution
        case fps
        case latency
        case bitrate
        case codec
        case rateControl = "rate_control"
        case h264Profile = "h264_profile"
        case keyframe
        case bframes
        case lowLight = "low_light"
        case adaptiveResolution = "adaptive_resolution"
        case adaptive
        case portrait
        case audioBitrate = "audio_bitrate"
        case audioCodec = "audio_codec"
        case srtOverhead = "srt_overhead"
        case srtMaxBwFollowInput = "srt_max_bw_follow_input"
        case srtAdaptive = "srt_adaptive"
        case srtBigPackets = "srt_big_packets"
        case timecodes
        case viewerDelay = "viewer_delay"
        case backgroundStreaming = "background_streaming"
        case audioOnly = "audio_only"
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
        // ── Vídeo ──
        stream.codec = (creds.codec == "h265") ? .h265hevc : .h264avc
        if let r = creds.resolution, let res = SettingsStreamResolution(rawValue: r) {
            stream.resolution = res
        } else {
            stream.resolution = .r1920x1080
        }
        stream.fps = creds.fps ?? 60
        stream.bitrate = UInt32(creds.bitrate ?? 6000) * 1000
        if let rc = creds.rateControl, let v = SettingsStreamRateControl(rawValue: rateControlRaw(rc)) {
            stream.rateControl = SettingsStreamRateControl.makeValid(value: v)
        }
        if let p = creds.h264Profile, let v = SettingsStreamH264Profile(rawValue: h264ProfileRaw(p)) {
            stream.h264Profile = v
        }
        stream.maxKeyFrameInterval = Int32(creds.keyframe ?? 2)
        stream.bFrames = creds.bframes ?? false
        stream.lowLightBoost = creds.lowLight ?? false
        stream.adaptiveEncoderResolution = creds.adaptiveResolution ?? false
        stream.adaptiveBitrate = creds.adaptive ?? true
        stream.portrait = creds.portrait ?? false
        // ── Áudio ── (canais não é setting limpo no Moblin → fora)
        stream.audioBitrate = (creds.audioBitrate ?? 128) * 1000
        stream.audioCodec = (creds.audioCodec == "opus") ? .opus : .aac
        // ── Transmissão (SRT) ──
        stream.srt.latency = Int32(creds.latency ?? 2000)
        stream.srt.overheadBandwidth = Int32(creds.srtOverhead ?? 25)
        stream.srt.maximumBandwidthFollowInput = creds.srtMaxBwFollowInput ?? true
        stream.srt.adaptiveBitrateEnabled = creds.srtAdaptive ?? true
        stream.srt.bigPackets = creds.srtBigPackets ?? true
        // ── Outras ──
        stream.timecodesEnabled = creds.timecodes ?? false
        stream.estimatedViewerDelay = creds.viewerDelay ?? 8.0
        stream.backgroundStreaming = creds.backgroundStreaming ?? false
        // creds.audioOnly: previsto p/ etapa futura (gate de vídeo no muxer) — ainda inerte.
        if includeRemoteControl {
            db.remoteControl.streamer.enabled = true
            db.remoteControl.streamer.url = creds.assistantUrl
            db.remoteControl.password = creds.password
        }
        model.setCurrentStream(stream: stream)
        model.storeSettings()
    }

    // "abr"/"cbr"/"vbr" → rawValue do enum ("ABR"/"CBR"/"VBR").
    private static func rateControlRaw(_ s: String) -> String { s.uppercased() }
    // "baseline"/"main"/"high" → rawValue ("Baseline"/"Main"/"High").
    private static func h264ProfileRaw(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }
}
