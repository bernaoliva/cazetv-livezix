// LiveZix CazéTV — fork do Moblin
// Settings simplificadas (engrenagem na MainView). Mostra apenas o essencial
// pro rep — destino SRT, vídeo, áudio. "Avançado" mostra todas as settings Moblin.
import SwiftUI

struct LiveZixSimpleSettingsView: View {
    @EnvironmentObject var model: Model
    @State private var showAdvancedConfirm = false
    @State private var showSwitchRepConfirm = false

    var body: some View {
        Form {
            // Identidade
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

            // Stream / transmissão atual
            Section(header: Text("Transmissão")) {
                HStack {
                    Text("URL").foregroundColor(.secondary)
                    Spacer()
                    Text(shortUrl(model.stream.url))
                        .font(.caption).monospaced()
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Picker("Resolução", selection: Binding(
                    get: { model.stream.resolution },
                    set: { newVal in model.stream.resolution = newVal; model.storeSettings() }
                )) {
                    ForEach(SettingsStreamResolution.allCases, id: \.self) { r in
                        Text(String(describing: r).replacingOccurrences(of: "r", with: ""))
                            .tag(r)
                    }
                }
                Picker("FPS", selection: Binding(
                    get: { model.stream.fps },
                    set: { newVal in model.stream.fps = newVal; model.storeSettings() }
                )) {
                    Text("25").tag(25)
                    Text("30").tag(30)
                    Text("50").tag(50)
                    Text("60").tag(60)
                }
                HStack {
                    Text("Bitrate")
                    Spacer()
                    Text("\(model.stream.bitrate / 1_000_000) Mbps")
                        .foregroundColor(.secondary)
                }
                Stepper(
                    "",
                    value: Binding(
                        get: { Int(model.stream.bitrate / 1_000_000) },
                        set: { newVal in
                            model.stream.bitrate = UInt32(max(1, newVal)) * 1_000_000
                            model.storeSettings()
                        }
                    ),
                    in: 1...20
                )
            }

            // Áudio
            Section(header: Text("Áudio")) {
                NavigationLink(destination: emptySheet("Entrada de microfone configura-se em Avançado")) {
                    Text("Entrada de microfone")
                }
                HStack {
                    Text("Bitrate áudio")
                    Spacer()
                    Text("\(model.stream.audioBitrate / 1000) kbps")
                        .foregroundColor(.secondary)
                }
            }

            // Central
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

            // Avançado — abre o Moblin original
            Section(header: Text("Avançado")) {
                Button {
                    showAdvancedConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Mostrar todas as opções (Moblin completo)")
                            .foregroundColor(.primary)
                    }
                }
                .alert("Mostrar Moblin completo?",
                       isPresented: $showAdvancedConfirm) {
                    Button("Mostrar tudo", role: .destructive) {
                        model.database.showAllSettings = true
                        model.database.liveZixMode = false
                        model.storeSettings()
                    }
                    Button("Cancelar", role: .cancel) {}
                } message: {
                    Text("Vai aparecer todas as funções do Moblin original (Twitch/YouTube/Chat/etc). Indicado só pra diagnóstico. Pra voltar, vá em Settings → CazéTV → Modo simplificado.")
                }
            }

            Section {
                Text("CazéTV LiveZix · v1.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Configurações")
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

    @ViewBuilder
    private func emptySheet(_ msg: String) -> some View {
        VStack {
            Text(msg)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .padding()
            Spacer()
        }
    }
}
