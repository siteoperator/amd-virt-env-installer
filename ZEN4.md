# Zen4-spezifisches Tuning

Optimierungen speziell für AMD Zen 4 CPUs (Ryzen 7000/8000 Serie, z. B. 8845HS, 8835H) und verwandte Zen5 APUs.

## CachyOS znver4 Repository

Das `znver4`-Repository kompiliert Pakete mit `-march=znver4` und aktiviert zusätzliche Instruktionen über x86-64-v4 hinaus:

- `avx512bf16`, `avx512bitalg`, `avx512ifma`, `avx512vbmi(2)`, `avx512vnni`, `avx512vpopctndq`
- `gfni`, `clzero`, `mwaitx` usw.

Wird bei Installation auf Zen4/Zen5 automatisch aktiviert.

### Prüfung

```bash
gcc -march=native -Q --help=target 2>&1 | grep march
# Erwartung: znver4 oder znver5
```

## Compiler & Kernel

- Clang ThinLTO + AutoFDO auf dem Standard-Kernel
- Verbesserte LLVM/Clang znver4-Modelle (Latency-/uop-Tabellen korrigiert)
- Preferred Core Support im `amd-pstate` Driver

## amd-pstate auf Zen4

Empfohlen: **`amd_pstate=active`** (EPP / Autonomous Mode).

Details: [AMD_PSTATE.md](AMD_PSTATE.md)

## ROCm auf Zen4 APUs (z. B. 780M / gfx1103)

- `HSA_OVERRIDE_GFX_VERSION=11.0.0` (oder ohne Override auf neueren ROCm-Versionen testen)
- Kombination aus aktuellem Kernel + znver4-Userspace + korrektem HSA-Override bringt die größten Gewinne
- Keine speziellen ROCm-only Zen4-Patches nötig

## Praktische Empfehlungen

1. Auf `znver4`-Repositories wechseln/prüfen
2. Standard `linux-cachyos` (ThinLTO + AutoFDO) oder BORE nutzen
3. `amd_pstate=active` setzen
4. `powerprofilesctl set performance` (oder balanced) für Compute-Workloads
5. `gpu_recovery=1` aus [DRIVER_MODULES.md](DRIVER_MODULES.md) anwenden

## Verwandte Modelle

| Modell          | Architektur | iGPU     | Typischer gfx |
|-----------------|-------------|----------|---------------|
| 8845HS / 8835H  | Zen 4       | 780M     | gfx1103       |
| AI 370 / 470    | Zen 5       | 890M     | gfx1150       |
