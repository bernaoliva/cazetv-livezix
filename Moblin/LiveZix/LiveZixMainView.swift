// LiveZix CazéTV — fork do Moblin
// Tela principal simplificada pro rep. Substitui MainView quando liveZixMode=true.
// Mostra apenas: preview câmera, botão TRANSMITIR, controles essenciais, status central.
import SwiftUI

struct LiveZixMainView: View {
    @EnvironmentObject var model: Model
    @State private var showingSettings = false

    var body: some View {
        ZStack {
            // Background: preview da câmera (reusa view existente do Moblin)
            CameraPreviewView(model: model)
                .ignoresSafeArea()

            // Camadas de UI overlaid
            VStack(spacing: 0) {
                LiveZixTopBar()
                Spacer()
                LiveZixSecondaryControls()
                    .padding(.bottom, 14)
                LiveZixGoLiveButton()
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
    @EnvironmentObject var model: Model

    var body: some View {
        HStack(spacing: 10) {
            LiveZixServerStatusBar()
            Spacer()
            HStack(spacing: 8) {
                if model.isLive {
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
    }

    private func currentStats() -> String {
        // Não dependemos de campos específicos do Moblin pra evitar incompatibilidade
        // com diferentes versões. Mostra apenas a resolução/fps configurada do stream.
        let stream = model.stream
        let res = String(describing: stream.resolution)
            .replacingOccurrences(of: "r", with: "")
        return "\(res) · \(stream.fps)fps"
    }
}

// ─── Status da Central (Remote Control) ──────────────────────────────────
struct LiveZixServerStatusBar: View {
    @EnvironmentObject var model: Model
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

// Poller simples pra checar status de conexão a cada 2s (Moblin não tem publisher pra isso).
// Model é @MainActor, então todos os acessos têm que rodar no MainActor.
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
            // Timer callback roda no main run loop, mas precisa hop pro MainActor via Task
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

// ─── Controles secundários (mic, lanterna, zoom) ─────────────────
// Subviews dedicadas evitam ambiguidade do compilador SwiftUI ao
// passar @Published properties (isTorchOn etc.) inline pra helpers.
private struct LiveZixSecondaryControls: View {
    var body: some View {
        HStack(spacing: 12) {
            TorchButton()
            MicButton()
            ZoomButton(value: 0.5)
            ZoomButton(value: 1.0)
            ZoomButton(value: 2.0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.42))
        .cornerRadius(14)
    }
}

private struct TorchButton: View {
    @EnvironmentObject var model: Model

    var body: some View {
        let active: Bool = model.isTorchOn
        Button {
            model.toggleTorch()
        } label: {
            Image(systemName: "flashlight.on.fill")
                .font(.system(size: 18))
                .foregroundColor(active ? .yellow : .white)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(active ? 0.22 : 0.1))
                .cornerRadius(10)
        }
    }
}

private struct MicButton: View {
    @EnvironmentObject var model: Model
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
        .onAppear {
            let val: Bool = model.isMuteOn
            muted = val
        }
    }
}

private struct ZoomButton: View {
    @EnvironmentObject var model: Model
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
    @EnvironmentObject var model: Model
    @State private var presentingStartConfirm = false
    @State private var presentingStopConfirm = false

    var body: some View {
        Button {
            if model.isLive {
                presentingStopConfirm = true
            } else {
                presentingStartConfirm = true
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: model.isLive ? "stop.fill" : "dot.radiowaves.left.and.right")
                    .font(.system(size: 24, weight: .bold))
                Text(model.isLive ? "PARAR" : "TRANSMITIR")
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: 280)
            .frame(height: 64)
            .background(model.isLive ? Color.red : Color.green)
            .cornerRadius(16)
            .shadow(color: (model.isLive ? Color.red : Color.green).opacity(0.45), radius: 18, x: 0, y: 0)
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
