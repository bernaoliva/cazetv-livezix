// LiveZix CazéTV — fork do Moblin
// Constantes globais do servidor LiveZix usadas pelo onboarding e fetch de credenciais.
import Foundation

enum LiveZixConfig {
    /// Total de reps ativos no momento (REP 1..N → SRT_LIVEMODE_01..N).
    /// Inicialmente 4 (Makito 189.112.178.134:5000-5003). Subir conforme adicionar portas no Makito.
    static let totalReps = 4

    /// URL base do servidor LiveZix (HTTP/HTTPS). Endpoint moblin_creds é exposto aqui.
    static let serverBaseUrl = "https://livezix.livemode.space"

    /// Caminho do endpoint que retorna {srt_url, assistant_url, password}
    static let credsApiPath = "/api/moblin_creds"

    /// Nome do estúdio exibido na tela de onboarding pra cada rep
    static func studioName(rep: Int) -> String {
        "Estúdio \(rep)"
    }

    /// Identificador do device no servidor (SRT_LIVEMODE_NN)
    static func deviceName(rep: Int) -> String {
        String(format: "SRT_LIVEMODE_%02d", rep)
    }
}
