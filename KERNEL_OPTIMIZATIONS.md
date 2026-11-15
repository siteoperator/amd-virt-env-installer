# ROCm Kernel-Optimierungen

Praktische Wege, um aus ROCm und PyTorch mehr Performance zu holen – ohne selbst HIP-Kernel schreiben zu müssen.

## 1. Wichtige Environment-Variablen

| Variable | Empfohlener Wert | Wirkung |
|----------|------------------|---------|
| `HSA_OVERRIDE_GFX_VERSION` | je nach GPU | Lädt passende Kernel (siehe PERFORMANCE.md) |
| `HSA_NO_SCRATCH_RECLAIM` | `1` | Weniger Overhead bei Kernel-Launches |
| `HSA_ENABLE_SDMA` | `1` (default) oder `0` | DMA-Engines; bei Problemen auf `0` setzen |
| `HIP_FORCE_DEV_KERNARG` | `1` | Kernel-Argumente direkt im Device-Memory (weniger Latenz) |
| `HIP_VISIBLE_DEVICES` | `0` | GPU-Auswahl |
| `PYTORCH_TUNABLEOP_ENABLED` | `1` | Automatische GEMM-Tuning |

**Beispiel-Start:**
```bash
export HSA_OVERRIDE_GFX_VERSION=11.0.0
export HSA_NO_SCRATCH_RECLAIM=1
export HIP_FORCE_DEV_KERNARG=1
export PYTORCH_TUNABLEOP_ENABLED=1
python your_script.py
```

## 2. PyTorch TunableOp (GEMM-Tuning)

Sucht automatisch die besten rocBLAS / hipBLASLt-Kernel für deine Matrix-Größen.

```bash
# Tuning-Lauf (erzeugt tunableop_results0.csv)
PYTORCH_TUNABLEOP_ENABLED=1 python train.py

# Später mit den Ergebnissen
PYTORCH_TUNABLEOP_ENABLED=1 \
PYTORCH_TUNABLEOP_FILENAME=tunableop_results0.csv \
python train.py
```

Typischer Gewinn: **5–20 %** bei GEMM-lastigen Workloads.

## 3. MIOpen Tuning (Convolutions)

```bash
# Einmaliges Tuning und Speichern in der User-DB
export MIOPEN_FIND_ENFORCE=3          # SEARCH
export MIOPEN_FIND_MODE=1
# oder aggressiver:
export MIOPEN_FIND_ENFORCE=2          # DB_UPDATE
```

Ergebnisse landen in `~/.config/miopen/`.

## 4. Profiling

Ausführliche Anleitung zu `rocprofv3` (Kernel-Stats, Traces, Perfetto, PMC):

**[PROFILING.md](PROFILING.md)**

Kurzer Einstieg:
```bash
rocprofv3 --kernel-trace --stats -S -T -d outdir -o myrun -- python your_script.py
```

**Workflow:**
1. Baseline messen
2. Bottleneck finden (compute-bound vs. memory-bound)
3. Environment-Variablen / TunableOp anwenden
4. Erneut messen

## 5. Architektur-spezifische Hinweise

| Architektur | Besonderheiten |
|-------------|----------------|
| **RDNA2 / 680M** | Häufig `HSA_OVERRIDE_GFX_VERSION=10.3.0` |
| **RDNA3 / 780M** | `11.0.0`, WMMA verfügbar |
| **RDNA 3.5 / 890M** | Native oder `11.5.0` |
| **CDNA (Instinct)** | MFMA, CPX/NPS-Partitionen, GPU-initiated SDMA |

## 6. Offizielle Ressourcen

- **ROCm Handbooks** (Programming + Optimization Guide):  
  https://rocm.docs.amd.com/ (suche nach "ROCm Handbooks")
- HIP Performance Guidelines:  
  https://rocm.docs.amd.com/projects/HIP/en/latest/how-to/performance_guidelines.html
- System Optimization:  
  https://rocm.docs.amd.com/en/latest/reference/system-optimization/
- GEMM Tuning Blog:  
  https://rocm.blogs.amd.com/artificial-intelligence/gemm_blog/README.html

## 7. Empfohlene Reihenfolge für Nutzer des Installers

1. GPU mit `rocminfo` sichtbar machen (Gruppen + ggf. HSA_OVERRIDE)
2. `HSA_NO_SCRATCH_RECLAIM=1` und `HIP_FORCE_DEV_KERNARG=1` setzen
3. Bei Training/Inference: `PYTORCH_TUNABLEOP_ENABLED=1` einmal laufen lassen
4. Mit `rocprofv3` oder einfachem Timing prüfen
5. Bei Convolutions MIOpen-Tuning erwägen

Siehe auch: [PERFORMANCE.md](PERFORMANCE.md) · [PROFILING.md](PROFILING.md)
