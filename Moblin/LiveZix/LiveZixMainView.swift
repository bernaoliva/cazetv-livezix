// LiveZix CazéTV — fork do Moblin
// Tela principal simplificada pro rep. Substitui MainView quando liveZixMode=true.
// Layout enxuto: preview em tela cheia (zoom por pinça), barra inferior com 4 ações:
// Trocar câmera · Lanterna · Transmitir · Configurações. Status discreto no topo.
//
// PADRÃO DE ACESSO AO MODEL: só a view raiz usa @EnvironmentObject; subviews recebem
// `let model: Model` (Model é @MainActor+ObservableObject; o dynamic-member lookup via
// EnvironmentObject Wrapper falha em subviews nessa versão do Swift). Reactivity via @State.
import SwiftUI
import UIKit

struct LiveZixMainView: View {
    @EnvironmentObject var model: Model
    @State private var showingSettings = false
    @State private var didSetup = false
    // Indicador de zoom (ex.: "2.3x") enquanto pinça.
    @State private var zoomText = ""
    @State private var showZoom = false
    @State private var zoomHideWork: DispatchWorkItem?

    var body: some View {
        ZStack {
            // Background: preview do Moblin (frame processado pela media engine).
            StreamPreviewView(model: model)
                .ignoresSafeArea()
                // Zoom por pinça (padrão 1x). Reusa o pinch nativo do Moblin.
                .gesture(
                    MagnificationGesture()
                        .onChanged { amount in
                            model.changeZoomX(amount: Float(amount))
                            flashZoom()
                        }
                        .onEnded { amount in
                            model.commitZoomX(amount: Float(amount))
                            flashZoom()
                        }
                )

            // Indicador de zoom — aparece centralizado enquanto/depois de pinçar.
            if showZoom {
                Text(zoomText)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18).padding(.vertical, 9)
                    .background(.black.opacity(0.45), in: Capsule())
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            // Status no topo.
            VStack(spacing: 0) {
                LiveZixTopBar(model: model)
                Spacer()
            }
            // Ações na lateral direita (coluna vertical, ícones compactos).
            HStack(spacing: 0) {
                Spacer()
                LiveZixSideBar(model: model, onSettings: { showingSettings = true })
            }
        }
        .onAppear {
            // model.setup() inicializa câmera/áudio/subsistemas (igual MainView). Sem isso,
            // câmera preta + crash. Guard pra rodar 1x.
            if !didSetup {
                didSetup = true
                model.setup()
            }
            // Mantém a tela acesa — sem isso o iOS suspende o app quando o rep larga o
            // celular e a conexão de Remote Control cai (central perde o controle).
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .sheet(isPresented: $showingSettings) {
            NavigationView {
                LiveZixSettingsView()
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

    // Mostra o nível de zoom atual (model.zoom.x) e some ~1s após parar de pinçar.
    private func flashZoom() {
        zoomText = String(format: "%.1fx", model.zoom.x)
        withAnimation(.easeOut(duration: 0.15)) { showZoom = true }
        zoomHideWork?.cancel()
        let work = DispatchWorkItem {
            withAnimation(.easeIn(duration: 0.3)) { showZoom = false }
        }
        zoomHideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }
}

// ─── Top Bar (status central + AO VIVO) — informativo, não são "ações" ─────
private struct LiveZixTopBar: View {
    let model: Model
    @ObservedObject private var live = LiveZixLiveStatePoller.shared

    var body: some View {
        HStack(spacing: 10) {
            LiveZixServerStatusBar(model: model)
            Spacer()
            if live.isLive {
                HStack(spacing: 7) {
                    Circle().fill(Color.red).frame(width: 9, height: 9)
                    Text("AO VIVO").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                }
                .padding(.horizontal, 11).padding(.vertical, 6)
                .background(Color.black.opacity(0.55)).cornerRadius(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .onAppear { live.start(model: model) }
        .onDisappear { live.stop() }
    }
}

// ─── Status da Central (Remote Control) ──────────────────────────────────
struct LiveZixServerStatusBar: View {
    let model: Model
    @ObservedObject private var rc = LiveZixStatusPoller.shared

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(rc.connected ? Color.green : Color.gray)
                .frame(width: 9, height: 9)
                .shadow(color: rc.connected ? .green : .clear, radius: 4)
            Text(rc.connected ? "Central conectada" : "Central desconectada")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 11).padding(.vertical, 6)
        .background(Color.black.opacity(0.55)).cornerRadius(8)
        .onAppear { rc.start(model: model) }
        .onDisappear { rc.stop() }
    }
}

// ─── Barra lateral direita — 4 ações (ícones compactos) ───────────────────
private struct LiveZixSideBar: View {
    let model: Model
    let onSettings: () -> Void
    @ObservedObject private var live = LiveZixLiveStatePoller.shared
    @State private var torchOn = false
    @State private var presentingStopConfirm = false

    var body: some View {
        VStack(alignment: .center, spacing: 15) {
            actionButton(system: "camera.rotate", label: "Câmera") {
                liveZixToggleCamera()
            }
            actionButton(system: torchOn ? "flashlight.on.fill" : "flashlight.off.fill",
                         label: "Lanterna", tint: torchOn ? .yellow : .white) {
                model.toggleTorch()
                torchOn = model.streamOverlay.isTorchOn
            }
            transmitButton()
            actionButton(system: "gearshape.fill", label: "Config", action: onSettings)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 11)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.black.opacity(0.32))
        )
        .padding(.trailing, 12)
        .onAppear { torchOn = model.streamOverlay.isTorchOn }
    }

    // Botão de ação secundário (câmera / lanterna / config)
    @ViewBuilder
    private func actionButton(system: String, label: String, tint: Color = .white,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: system)
                    .font(.system(size: 17))
                    .foregroundColor(tint)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
    }

    // Botão TRANSMITIR — destaque, estilo gravação (círculo vermelho / quadrado p/ parar)
    @ViewBuilder
    private func transmitButton() -> some View {
        Button {
            if live.isLive {
                presentingStopConfirm = true
            } else {
                model.startStream()
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.9), lineWidth: 3)
                        .frame(width: 56, height: 56)
                    RoundedRectangle(cornerRadius: live.isLive ? 5 : 25)
                        .fill(Color.red)
                        .frame(width: live.isLive ? 22 : 44, height: live.isLive ? 22 : 44)
                        .animation(.easeInOut(duration: 0.2), value: live.isLive)
                }
                Text(live.isLive ? "PARAR" : "TRANSMITIR")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(live.isLive ? .red : .white)
            }
        }
        .confirmationDialog("Parar transmissão?", isPresented: $presentingStopConfirm, titleVisibility: .visible) {
            Button("Parar", role: .destructive) { _ = model.stopStream() }
            Button("Continuar transmitindo", role: .cancel) {}
        }
    }

    // Alterna câmera frontal/traseira na cena ativa e re-attacha (mecanismo nativo do Moblin).
    private func liveZixToggleCamera() {
        guard let scene = model.getSelectedScene() else { return }
        scene.videoSource.cameraPosition = (scene.videoSource.cameraPosition == .front) ? .back : .front
        model.sceneUpdated(attachCamera: true)
    }
}

// ─── Pollers — espelham estado observável pro SwiftUI ──────────────────────
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

    func stop() { timer?.invalidate(); timer = nil }

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

    func stop() { timer?.invalidate(); timer = nil }

    private func update() {
        guard let m = model else { return }
        let live = m.isLive
        if isLive != live {
            let wasLive = isLive
            isLive = live
            // Saiu do ar (true→false): re-busca a config do REP e re-aplica resolução/fps/
            // latência/SRT (que o operador mudou no painel). NÃO mexe no Remote Control.
            if wasLive && !live {
                reapplyRepConfig(model: m)
            }
        }
    }

    private var reapplying = false
    private func reapplyRepConfig(model m: Model) {
        guard !reapplying, let rep = m.database.liveZixSelectedRep else { return }
        reapplying = true
        Task { @MainActor in
            defer { reapplying = false }
            do {
                let creds = try await LiveZixApi.fetchCredentials(rep: rep)
                LiveZixApi.applyCredentials(creds, to: m, includeRemoteControl: false)
            } catch {
                // silencioso: mantém config atual se falhar
            }
        }
    }
}
