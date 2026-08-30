# Done

App iOS de hábitos. A ideia: você só libera os outros apps do celular
depois de cumprir o hábito do dia (ex: 5 min de leitura).

## Rodar

Precisa do Xcode instalado (App Store).

```sh
brew install xcodegen   # uma vez
xcodegen generate       # gera Done.xcodeproj
open Done.xcodeproj
```

Depois: escolha um simulador de iPhone no topo do Xcode e aperte ⌘R.

## Estado

- [x] Criar hábitos (nome + minutos por dia)
- [x] Timer de sessão
- [x] Streak de dias consecutivos
- [x] Persistência local (JSON, sem contas de usuário)
- [ ] Bloquear outros apps até cumprir o hábito

O bloqueio usa a Screen Time API da Apple (`FamilyControls` +
`ManagedSettings` + `DeviceActivity`). Exige conta paga do Apple
Developer Program e aprovação da Apple para o entitlement
`com.apple.developer.family-controls`.
