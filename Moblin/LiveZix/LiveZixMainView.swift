// LiveZix CazéTV — fork do Moblin
// Tela principal simplificada pro rep. Substitui MainView quando liveZixMode=true.
// Mostra apenas: preview câmera, botão TRANSMITIR, controles essenciais, status central.
//
// PADRÃO DE ACESSO AO MODEL:
// Só a view raiz (LiveZixMainView) usa @EnvironmentObject. Todas as subviews
// recebem `let model: Model` como propriedade simples — espelha o padrão usado
// pelo próprio Moblin (ControlBarPortraitView, QuickButtonsView, etc).
// Motivo: Model é `@MainActor + ObservableObject`. Em Xcode 26+/Swift 5 o
// dynamic-member lookup via EnvironmentObject Wrapper falha pra @Published
// dentro de subviews ("requires wrapper EnvironmentObject<Model>.Wrapper").
// Reactivity de live/torch/mic é mantida via @State local sincronizado.
import SwiftUI
import UIKit

struct LiveZixMainView: View {
    @EnvironmentObject var model: Model
    @State private var showingSettings = false
    @State private var didSetup = false

    var body: some View {
        ZStack {
            // Background: preview do Moblin. Usar StreamPreviewView (frame processado pela
            // media engine) e NÃO CameraPreviewView (AVCaptureVideoPreviewLayer cru) — o Moblin
            // mostra o stream preview por padrão (model.cameraPreview=false); o layer cru fica
            // preto porque não é alimentado nesse fluxo, mesmo com a captura/transmissão OK.
            StreamPreviewView(model: model)
                .ignoresSafeArea()

            // Camadas de UI overlaid
            VStack(spacing: 0) {
                LiveZixTopBar(model: model)
                Spacer()
                LiveZixSecondaryControls(model: model)
                    .padding(.bottom, 14)
                LiveZixGoLiveButton(model: model)
                    .padding(.bottom, 20)
            }

            // Engrenagem no canto inferior direito
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .padding(11)
                            .background(Color.black.opacity(0.55))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 18)
                    .padding(.bottom, 22)
                }
            }
        }
        .onAppear {
            // CRÍTICO: inicializa câmera/áudio/subsistemas do Moblin. O MainView original
            // chama model.setup() no onAppear; sem isso a câmera fica preta e qualquer
            // botão crasha (subsistema não inicializado). Guard pra rodar só 1x.
            if !didSetup {
                didSetup = true
                model.setup()
            }
            // Mantém a tela acesa enquanto o rep está no controle remoto. Sem isso o iOS
            // bloqueia/suspende o app quando o rep larga o celular — e a conexão de Remote
            // Control cai, fazendo a central perder o controle. Essencial pro fluxo LiveZix.
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .sheet(isPresented: $showingSettings) {
            NavigationView {
                LiveZixSimpleSettingsView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Fechar") { showingSettings = false }
                        }
                    }
            }
            .environmentObject(model)
        }
    }
}

// ─── Top Bar (status central + bitrate) ──────────────────────────────────
private struct LiveZixTopBar: View {
    let model: Model
    @ObservedObject private var live = LiveZixLiveStatePoller.shared

    var body: some View {
        HStack(spacing: 10) {
            LiveZixServerStatusBar(model: model)
            Spacer()
            HStack(spacing: 8) {
                if live.isLive {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                    Text("AO VIVO")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                Text(currentStats())
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.55))
            .cornerRadius(8)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .onAppear { live.start(model: model) }
        .onDisappear { live.stop() }
    }

    private func currentStats() -> String {
        // Não dependemos de campos específicos do Moblin pra evitar incompatibilidade.
        // Mostra apenas a resolução/fps configurada do stream atual.
        let stream = model.stream
        let res = String(describing: stream.resolution)
            .replacingOccurrences(of: "r", with: "")
        return "\(res) · \(stream.fps)fps"
    }
}

// ─── Status da Central (Remote Control) ──────────────────────────────────
struct LiveZixServerStatusBar: View {
    let model: Model
    @ObservedObject private var rc = LiveZixStatusPoller.shared

    var body: some View {
        Button {
            toggleCentral()
        } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(rc.connected ? Color.green : Color.gray)
                    .frame(width: 9, height: 9)
                    .shadow(color: rc.connected ? .green : .clear, radius: 4)
                Text(rc.connected ? "Central conectada" : "Central desconectada")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.55))
            .cornerRadius(8)
        }
        .onAppear { rc.start(model: model) }
        .onDisappear { rc.stop() }
    }

    private func toggleCentral() {
        let db = model.database
        db.remoteControl.streamer.enabled.toggle()
        model.reloadConnections()
        model.storeSettings()
    }
}

// Pollers — espelham state observável pro SwiftUI sem depender do @Published do Model
// (que não atravessa bem a fronteira EnvironmentObject<@MainActor Model> nessa versão).
@MainActor
class LiveZixStatusPoller: ObservableObject {
    static let shared = LiveZixStatusPoller()
    @Published var connected: Bool = false
    private var timer: Timer?
    private weak var model: Model?

    func start(model: Model) {
        self.model = model
        update()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.update() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func update() {
        guard let m = model else { return }
        let isConn = m.isRemoteControlStreamerConnected()
        if connected != isConn { connected = isConn }
    }
}

@MainActor
class LiveZixLiveStatePoller: ObservableObject {
    static let shared = LiveZixLiveStatePoller()
    @Published var isLive: Bool = false
    private var timer: Timer?
    private weak var model: Model?

    func start(model: Model) {
        self.model = model
        update()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.update() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func update() {
        guard let m = model else { return }
        let live = m.isLive
        if isLive != live { isLive = live }
    }
}

// ─── Controles secundários (mic, lanterna, zoom) ─────────────────
private struct LiveZixSecondaryControls: View {
    let model: Model
    var body: some View {
        HStack(spacing: 12) {
            TorchButton(model: model)
            MicButton(model: model)
            ZoomButton(model: model, value: 0.5)
            ZoomButton(model: model, value: 1.0)
            ZoomButton(model: model, value: 2.0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.42))
        .cornerRadius(14)
    }
}

private struct TorchButton: View {
    let model: Model
    @State private var on: Bool = false

    var body: some View {
        Button {
            model.toggleTorch()
            on.toggle()
        } label: {
            Image(systemName: "flashlight.on.fill")
                .font(.system(size: 18))
                .foregroundColor(on ? .yellow : .white)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(on ? 0.22 : 0.1))
                .cornerRadius(10)
        }
        .onAppear { on = model.streamOverlay.isTorchOn }
    }
}

private struct MicButton: View {
    let model: Model
    @State private var muted: Bool = false

    var body: some View {
        Button {
            muted.toggle()
            model.setMuted(value: muted)
        } label: {
            Image(systemName: muted ? "mic.slash.fill" : "mic.fill")
                .font(.system(size: 18))
                .foregroundColor(muted ? .yellow : .white)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(muted ? 0.22 : 0.1))
                .cornerRadius(10)
        }
        .onAppear { muted = model.isMuteOn }
    }
}

private struct ZoomButton: View {
    let model: Model
    let value: Double

    var body: some View {
        Button {
            _ = model.setCameraZoomX(x: Float(value))
        } label: {
            Text("\(formatZoom(value))x")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
        }
    }

    private func formatZoom(_ v: Double) -> String {
        v == floor(v) ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }
}

// ─── Botão TRANSMITIR ────────────────────────────────────────────────────
private struct LiveZixGoLiveButton: View {
    let model: Model
    @ObservedObject private var live = LiveZixLiveStatePoller.shared
    @State private var presentingStartConfirm = false
    @State private var presentingStopConfirm = false

    var body: some View {
        Button {
            if live.isLive {
                presentingStopConfirm = true
            } else {
                presentingStartConfirm = true
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: live.isLive ? "stop.fill" : "dot.radiowaves.left.and.right")
                    .font(.system(size: 24, weight: .bold))
                Text(live.isLive ? "PARAR" : "TRANSMITIR")
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: 280)
            .frame(height: 64)
            .background(live.isLive ? Color.red : Color.green)
            .cornerRadius(16)
            .shadow(color: (live.isLive ? Color.red : Color.green).opacity(0.45), radius: 18, x: 0, y: 0)
        }
        .confirmationDialog("Começar transmissão?", isPresented: $presentingStartConfirm, titleVisibility: .visible) {
            Button("Transmitir") {
                model.startStream()
            }
            Button("Cancelar", role: .cancel) {}
        }
        .confirmationDialog("Parar transmissão?", isPresented: $presentingStopConfirm, titleVisibility: .visible) {
            Button("Parar", role: .destructive) {
                _ = model.stopStream()
            }
            Button("Continuar transmitindo", role: .cancel) {}
        }
    }
}
