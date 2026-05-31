// LiveZix CazéTV — fork do Moblin
// Hub de configurações do rep (engrenagem na MainView). NÃO é simplificado:
// expõe TODAS as configurações do Moblin, porém organizadas em camadas/categorias
// (Vídeo · Áudio · Transmissão · Câmera · Display) reusando as telas nativas do Moblin.
// A última entrada — "Tudo (Moblin completo)" — abre o SettingsView inteiro pra
// acessar absolutamente tudo (chat/Twitch/Tesla/debug) sem sair do shell LiveZix.
//
// `showAllSettings=true` é forçado no onAppear pra destravar as linhas avançadas
// dentro das telas nativas (ex.: bitrate/keyframe/b-frames em StreamVideoSettingsView,
// que ficam escondidas atrás desse flag). Mantém liveZixMode=true (não joga o rep fora).
import SwiftUI

struct LiveZixSettingsView: View {
    @EnvironmentObject var model: Model
    @State private var showSwitchRepConfirm = false

    var body: some View {
        Form {
            // ── Identidade ──────────────────────────────────────────────
            Section(header: Text("Identidade")) {
                if let r = model.database.liveZixSelectedRep {
                    HStack {
                        Text("Rep").foregroundColor(.secondary)
                        Spacer()
                        Text("REP \(r) — \(LiveZixConfig.studioName(rep: r))")
                            .foregroundColor(.primary)
                    }
                    Button("Trocar de rep") {
                        showSwitchRepConfirm = true
                    }
                    .foregroundColor(.orange)
                } else {
                    Text("Nenhum rep selecionado")
                }
            }

            // ── Categorias (telas nativas do Moblin, nada bloqueado) ─────
            Section(header: Text("Configurações"),
                    footer: Text("Todas as opções do Moblin, organizadas por categoria.")) {
                NavigationLink {
                    StreamVideoSettingsView(database: model.database, stream: model.stream)
                } label: {
                    Label("Vídeo", systemImage: "video")
                }
                NavigationLink {
                    StreamAudioSettingsView(stream: model.stream,
                                            bitrate: Float(model.stream.audioBitrate / 1000))
                } label: {
                    Label("Áudio", systemImage: "waveform")
                }
                NavigationLink {
                    LiveZixTransmissionSettingsView(model: model)
                } label: {
                    Label("Transmissão (SRT)", systemImage: "dot.radiowaves.left.and.right")
                }
                NavigationLink {
                    CameraSettingsView(database: model.database,
                                       stream: model.stream,
                                       color: model.database.color)
                } label: {
                    Label("Câmera", systemImage: "camera")
                }
                NavigationLink {
                    DisplaySettingsView(database: model.database)
                } label: {
                    Label("Display", systemImage: "rectangle.inset.topright.fill")
                }
            }

            // ── Central LiveZix (Remote Control) ─────────────────────────
            Section(header: Text("Central LiveZix")) {
                Toggle("Conectar central remotamente", isOn: Binding(
                    get: { model.database.remoteControl.streamer.enabled },
                    set: { newVal in
                        model.database.remoteControl.streamer.enabled = newVal
                        model.reloadConnections()
                        model.storeSettings()
                    }
                ))
                HStack {
                    Text("URL central").foregroundColor(.secondary)
                    Spacer()
                    Text(shortUrl(model.database.remoteControl.streamer.url))
                        .font(.caption).monospaced()
                        .lineLimit(1).truncationMode(.middle)
                }
                HStack {
                    Text("Status")
                    Spacer()
                    Circle()
                        .fill(model.isRemoteControlStreamerConnected() ? Color.green : Color.gray)
                        .frame(width: 10, height: 10)
                    Text(model.isRemoteControlStreamerConnected() ? "conectada" : "desconectada")
                        .foregroundColor(.secondary)
                }
            }

            // ── Tudo (Moblin completo) ───────────────────────────────────
            Section(footer: Text("Acesso a 100% das funções do Moblin (chat, plataformas, debug etc.). Indicado pra diagnóstico.")) {
                NavigationLink {
                    SettingsView(database: model.database)
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    Label("Tudo (Moblin completo)", systemImage: "slider.horizontal.3")
                }
            }

            Section {
                Text("CazéTV LiveZix · v1.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Configurações")
        .onAppear {
            // Destrava as linhas avançadas dentro das telas nativas (nada bloqueado).
            if !model.database.showAllSettings {
                model.database.showAllSettings = true
                model.storeSettings()
            }
        }
        .confirmationDialog("Trocar de rep?",
                            isPresented: $showSwitchRepConfirm,
                            titleVisibility: .visible) {
            Button("Voltar pra tela de seleção", role: .destructive) {
                model.database.liveZixSelectedRep = nil
                model.storeSettings()
                model.liveZixActiveRep = nil   // router volta pro onboarding
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Suas credenciais atuais serão removidas e você voltará pra tela de escolha de rep.")
        }
    }

    private func shortUrl(_ url: String) -> String {
        if url.count > 38 {
            return String(url.prefix(20)) + "…" + String(url.suffix(15))
        }
        return url
    }
}

// Transmissão: agrupa URL + SRT(LA) numa tela só (as duas telas nativas do Moblin).
private struct LiveZixTransmissionSettingsView: View {
    let model: Model

    var body: some View {
        Form {
            Section(header: Text("Destino")) {
                NavigationLink {
                    StreamUrlSettingsView(stream: model.stream)
                } label: {
                    HStack {
                        Text("URL")
                        Spacer()
                        Text(model.stream.url)
                            .font(.caption).monospaced()
                            .foregroundColor(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                    }
                }
                NavigationLink {
                    StreamSrtSettingsView(stream: model.stream, srt: model.stream.srt)
                } label: {
                    Label("SRT", systemImage: "antenna.radiowaves.left.and.right")
                }
            }
        }
        .navigationTitle("Transmissão")
    }
}
