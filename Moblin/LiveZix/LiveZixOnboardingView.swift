// LiveZix CazéTV — fork do Moblin
// Tela inicial: rep escolhe quem é (1..12). App busca credenciais no servidor,
// popula Database (stream + remote control), salva escolha e navega pra MainView.
import SwiftUI

struct LiveZixOnboardingView: View {
    @EnvironmentObject var model: Model
    @State private var isLoading = false
    @State private var loadingRep: Int? = nil
    @State private var errorMessage: String? = nil

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 22) {
                Spacer().frame(height: 12)
                Text("CazéTV LiveZix")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Text("Selecione qual repórter você é")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(1...LiveZixConfig.totalReps, id: \.self) { rep in
                        repButton(rep: rep)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)

                if let err = errorMessage {
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 22)
                }

                Spacer()
                Text("Suas credenciais são geradas pelo servidor LiveZix.\nA configuração é feita uma vez só.")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 16)
            }
        }
    }

    @ViewBuilder
    private func repButton(rep: Int) -> some View {
        Button {
            Task { await selectRep(rep) }
        } label: {
            VStack(spacing: 4) {
                Text("REP \(rep)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(loadingRep == rep ? Color.blue.opacity(0.4) : Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .cornerRadius(10)
            .overlay(alignment: .topTrailing) {
                if loadingRep == rep {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .padding(6)
                }
            }
        }
        .disabled(isLoading)
    }

    private func selectRep(_ rep: Int) async {
        guard !isLoading else { return }
        isLoading = true
        loadingRep = rep
        errorMessage = nil
        defer {
            isLoading = false
            loadingRep = nil
        }
        do {
            let creds = try await LiveZixApi.fetchCredentials(rep: rep)
            await MainActor.run {
                applyCredentials(creds)
                // Marca rep escolhido — MoblinApp router troca pra LiveZixMainView
                model.database.liveZixSelectedRep = rep
                model.storeSettings()
                // Reconecta tudo: stream novo + remote control
                model.reloadConnections()
            }
        } catch {
            await MainActor.run {
                errorMessage = "Falha ao buscar credenciais: \(error.localizedDescription)\nVerifique sua conexão e tente de novo."
            }
        }
    }

    private func applyCredentials(_ creds: LiveZixCredentials) {
        // Aplica tudo (stream + Remote Control) via helper compartilhado.
        LiveZixApi.applyCredentials(creds, to: model, includeRemoteControl: true)
    }
}
