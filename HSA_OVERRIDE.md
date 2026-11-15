# HSA_OVERRIDE_GFX_VERSION – Details

Was die Variable macht, wann sie nötig ist und welche Werte für Ryzen-iGPUs und discrete GPUs sinnvoll sind.

## Was macht die Variable?

`HSA_OVERRIDE_GFX_VERSION` zwingt die ROCm-Runtime, die GPU als eine andere Architektur zu melden.

Beispiel:
```bash
export HSA_OVERRIDE_GFX_VERSION=11.0.0
```

Die Runtime lädt dann die Kernel, die für `gfx1100` gebaut wurden, auch wenn die GPU eigentlich `gfx1103` ist.

**Wichtig:**
- Nur setzen, wenn es wirklich nötig ist.
- Bei offiziell unterstützten Karten (oder wenn `rocminfo` die GPU korrekt zeigt) kann ein Override die Erkennung **kaputt machen**.
- Format: `major.minor.stepping` (z. B. `10.3.0`, `11.0.0`, `11.5.0`).

## Schnellreferenz für häufige Ryzen-iGPUs

| CPU / iGPU              | Native gfx | Empfohlener Override | Hinweis |
|-------------------------|------------|----------------------|---------|
| Ryzen 7 7735HS / 6900HX (680M) | gfx103x   | `10.3.0`            | RDNA2 – fast immer nötig |
| Ryzen 7 8845HS / 8835H (780M)  | gfx1103   | `11.0.0`            | Häufig noch nötig (abhängig von ROCm-Version) |
| Ryzen AI 9 370 / 470 (890M)    | gfx1150   | oft **keins** oder `11.0.0` / `11.5.0` | Neuere ROCm-Versionen unterstützen native besser |
| Ryzen AI Max (Strix Halo)      | gfx1151   | meist **keins**     | Native Support in neueren Stacks |

## Discrete GPUs (Auszug)

| GPU                     | Native gfx | Override nötig? |
|-------------------------|------------|-----------------|
| RX 7900 XTX / XT        | gfx1100    | Nein            |
| RX 7800 XT / 7700 XT    | gfx1101    | Nein            |
| RX 7600                 | gfx1102    | Nein            |
| RX 6800 / 6900 XT       | gfx1030    | Nein            |
| RX 6700 XT / 6600       | gfx1031–1034 | `10.3.0`     |

## Wann setzen?

1. `rocminfo` zeigt **keine GPU** oder nur CPU
2. PyTorch / Ollama / llama.cpp fällt still auf CPU zurück
3. Fehlermeldungen wie:
   - `no rocblas support for gfx target`
   - `HSA_STATUS_ERROR_INVALID_ISA`
   - `Cannot read TensileLibrary.dat`

**Workflow:**
```bash
# 1. Ohne Override testen
unset HSA_OVERRIDE_GFX_VERSION
rocminfo | grep -E 'Marketing|gfx|GPU'

# 2. Mit Override testen
export HSA_OVERRIDE_GFX_VERSION=11.0.0
rocminfo | grep -E 'Marketing|gfx|GPU'
```

## Persistenz

```bash
# Einmalig in der Shell
export HSA_OVERRIDE_GFX_VERSION=11.0.0

# Dauerhaft (z. B. ~/.bashrc oder systemd)
echo 'export HSA_OVERRIDE_GFX_VERSION=11.0.0' >> ~/.bashrc
```

Für systemd-Dienste (z. B. Ollama):
```bash
sudo systemctl edit ollama
# [Service]
# Environment="HSA_OVERRIDE_GFX_VERSION=11.0.0"
```

## Häufige Fehler

| Problem | Ursache |
|---------|---------|
| GPU verschwindet nach dem Setzen | Falscher Wert oder Karte ist bereits nativ unterstützt |
| `gfx000` oder HSA-Fehler | Leerer String (`HSA_OVERRIDE_GFX_VERSION=""`) – Variable muss unset sein oder gültigen Wert haben |
| Läuft, aber langsam / instabil | Override auf zu entfernte Architektur |

## Empfehlung für dieses Repo

1. Zuerst ohne Override laufen lassen und `rocminfo` + PyTorch-Check machen.
2. Nur bei Bedarf den passenden Wert aus der Tabelle setzen.
3. Den Wert in der Dokumentation / README der eigenen Workloads festhalten.

## Siehe auch

- [DIAGNOSTICS.md](DIAGNOSTICS.md)
- [PERFORMANCE.md](PERFORMANCE.md)
- [KERNEL_OPTIMIZATIONS.md](KERNEL_OPTIMIZATIONS.md)
