# CazéTV LiveZix — Build via Codemagic (sem Mac local)

Fork do Moblin com UI simplificada pra reps do CazéTV controlados pela central LiveZix.

## Como buildar (sem Xcode local)

### 1) Subir este repo no GitHub

```bash
# Crie repo PRIVADO em github.com (ex: cazetv-livezix)
# Depois, na máquina local:
git remote remove origin
git remote add origin https://github.com/SEU_USER/cazetv-livezix.git
git add -A
git commit -m "Initial CazéTV LiveZix"
git push -u origin main
```

### 2) Conectar Codemagic

1. Acesse https://codemagic.io → login com GitHub
2. **Add application** → selecione o repo `cazetv-livezix`
3. Codemagic detecta o `codemagic.yaml` na raiz automaticamente
4. **Start new build** → workflow `livezix-unsigned`
5. Aguarde ~10-15 minutos

### 3) Baixar o IPA

Quando build terminar:
- Aba **Artifacts** → baixa **`CazeTV-LiveZix-unsigned.ipa`** (~40 MB)
- Esse IPA está **sem assinatura** — vai ser assinado pelo SideStore no iPhone

### 4) Instalar no iPhone via SideStore

Veja guia em https://docs.sidestore.io/docs/installation/install — resumido:

1. Windows: baixa **AltServer** (https://altstore.io) e instala iTunes + iCloud
2. iPhone: instala **SideStore** via AltServer (pareamento inicial)
3. Manda IPA pro iPhone via AirDrop/iCloud/email
4. SideStore: tap no IPA → assina com sua Apple ID grátis → instala

App aparece como **CazéTV LiveZix** com ícone CazéTV. Refresh automático a cada 7 dias via WiFi (sem cabo) enquanto AltServer estiver rodando no Windows.

## Estrutura LiveZix (modificações sobre o Moblin original)

| Arquivo | O que faz |
|---|---|
| `Moblin/LiveZix/LiveZixConfig.swift` | URL servidor + constantes 12 reps |
| `Moblin/LiveZix/LiveZixCredentials.swift` | Fetcher `/api/moblin_creds?rep=N` |
| `Moblin/LiveZix/LiveZixOnboardingView.swift` | Tela "Selecione seu rep" (12 botões) |
| `Moblin/LiveZix/LiveZixMainView.swift` | UI simplificada (Stream/mic/torch/zoom + central) |
| `Moblin/LiveZix/LiveZixSimpleSettingsView.swift` | Engrenagem com settings reduzidas |
| `MoblinApp.swift` | Router: liveZixMode → onboarding/main; senão Moblin original |
| `Various/Settings/Settings.swift` | Database +2 campos: `liveZixMode`, `liveZixSelectedRep` |
| `View/Settings/SettingsView.swift` | Botão "Voltar pro modo simplificado" |
| `Info.plist` | `CFBundleDisplayName=CazéTV LiveZix` |
| `Assets.xcassets/AppIcon.appiconset/*` | Logo CazéTV (42 lugares) |
| `codemagic.yaml` | CI/CD pra build cloud sem Mac |
| `scripts/add_livezix_files.rb` | Adiciona arquivos LiveZix/ ao project automaticamente |

## Distribuição pra galera (quando crescer)

Quando funcionar pra você:

1. Pagar Apple Developer Program ($99/ano) em https://developer.apple.com/programs/
2. Atualizar `codemagic.yaml` pra signing real (cert + provisioning profile)
3. Codemagic publica direto pro TestFlight
4. Compartilha link `https://testflight.apple.com/join/XXXXXX` com os reps
5. Cada rep instala TestFlight (App Store) → clica no link → app instala

## Server LiveZix (backend)

O app conecta no `https://livezix.livemode.space/api/moblin_creds?rep=N` pra buscar credenciais. Endpoint precisa estar acessível externamente (DNS + porta 443).
