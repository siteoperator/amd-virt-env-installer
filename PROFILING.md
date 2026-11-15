# Profiling mit rocprofv3

Praktische Anleitung für **rocprofv3** – das aktuelle ROCm-Profiling-Tool.

> **Hinweis:** `rocprof` und `rocprofv2` sind deprecated. Immer `rocprofv3` verwenden.

## Voraussetzungen

```bash
# ROCm-Pfad setzen (falls nötig)
export PATH=$PATH:/opt/rocm/bin

# Oder auf CachyOS/Arch nach Installation der rocm-Pakete
rocprofv3 --version
```

## 1. Schnellstart – Kernel-Statistik

Der häufigste Einstieg: welche Kernel am meisten Zeit verbrauchen.

```bash
# Nach Aktivierung des venvs
source venv/bin/activate

rocprofv3 --kernel-trace --stats -S -T -d outdir -o myrun -- \
  python your_script.py
```

**Wichtige Flags:**
- `--kernel-trace` – Kernel-Dispatches erfassen
- `--stats` – Statistik-CSV erzeugen (`*_kernel_stats.csv`)
- `-S` – Zusammenfassung am Ende anzeigen
- `-T` – Kernel-Namen kürzen (lesbarer)
- `-d outdir` – Ausgabeverzeichnis
- `-o myrun` – Namenspräfix

**Typische Ausgabe (`*_kernel_stats.csv`):**
```
Name,Calls,TotalDurationNs,AverageNs,Percentage,MinNs,MaxNs
"void aten::mm", 420, 123456789, 293944, 45.2, ...
"vectorized_elementwise_kernel", 1200, 87654321, 73045, 32.1, ...
```

## 2. Häufige Profiling-Kommandos

### Nur Kernel-Statistik (schnell)
```bash
rocprofv3 --kernel-trace --stats -S -T -- python script.py
```

### HIP + Kernel + Memory (detaillierter)
```bash
rocprofv3 --hip-trace --kernel-trace --memory-copy-trace --stats -S -T \
  -d outdir -o full -- python script.py
```

### Runtime-Trace (empfohlen für Überblick)
```bash
rocprofv3 --runtime-trace --summary -- python script.py
```

### System-Trace (sehr umfangreich – große Dateien!)
```bash
rocprofv3 --sys-trace --stats -d outdir -o sys -- python script.py
```

### Perfetto-Trace (Visualisierung)
```bash
rocprofv3 --kernel-trace --hip-trace --output-format pftrace \
  -d outdir -o perfetto -- python script.py
# Dann auf https://ui.perfetto.dev öffnen
```

Ausführliche Anleitung zur Perfetto-Visualisierung:

**[PERFETTO.md](PERFETTO.md)**

## 3. PyTorch-spezifisch

```bash
# GPU auswählen + Profiling
ROCR_VISIBLE_DEVICES=0 rocprofv3 --kernel-trace --stats -S -T \
  -d pytorch_out -o torch_run -- \
  python -c "import torch; x=torch.randn(1024,1024,device='cuda'); y=x@x; torch.cuda.synchronize()"
```

**Tipp für lange Trainingsläufe:**  
Nur einen Teil des Laufs profilieren (z. B. nach Warm-up) oder mit `roctx`-Markern Regionen auswählen (siehe offizielle Docs).

## 4. Hardware-Counter (PMC)

```bash
# Verfügbare Counter auflisten
rocprofv3-avail list --pmc

# Beispiel: Waves und VALU-Instructions
rocprofv3 --kernel-trace --pmc SQ_WAVES,SQ_INSTS_VALU \
  -d outdir -o pmc -- python script.py
```

**Hinweis:** Auf manchen RDNA-Karten muss der Performance-Level vorher gesetzt werden, sonst sind Counter deaktiviert.

## 5. Interpretation

| Metrik in Stats | Bedeutung |
|-----------------|-----------|
| `Percentage` | Anteil an der Gesamt-Kernel-Zeit |
| `Calls` | Wie oft der Kernel aufgerufen wurde |
| `AverageNs` / `TotalDurationNs` | Laufzeit |
| Viele kurze Kernel | Overhead durch Kernel-Launches (ggf. Fusion / TunableOp) |
| Ein Kernel dominiert | Hier optimieren (GEMM → TunableOp, Memory → Coalescing) |

## 6. Typischer Workflow

1. **Baseline:** `rocprofv3 --kernel-trace --stats -S -T ...`
2. **Hotspot identifizieren** (höchster Percentage)
3. **Optimierung anwenden** (TunableOp, HSA_NO_SCRATCH_RECLAIM, Mixed Precision, …)
4. **Erneut messen** und vergleichen
5. Optional: Perfetto-Trace für Timeline oder PMC für tiefere Analyse

## 7. Nützliche Links

- Offizielle rocprofv3-Dokumentation:  
  https://rocm.docs.amd.com/projects/rocprofiler-sdk/en/latest/how-to/using-rocprofv3.html
- Quick Reference:  
  https://rocm.docs.amd.com/projects/rocprofiler-sdk/en/latest/quick_guide.html
- Profiling-Guide (PyTorch-Beispiel):  
  https://rocm.blogs.amd.com/software-tools-optimization/profiling-guide/ai_tinyopenfold/README.html

## Siehe auch

- [PERFETTO.md](PERFETTO.md) – Timeline-Visualisierung
- [KERNEL_OPTIMIZATIONS.md](KERNEL_OPTIMIZATIONS.md)
- [PERFORMANCE.md](PERFORMANCE.md)
