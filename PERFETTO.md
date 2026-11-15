# Perfetto-Visualisierung mit rocprofv3

Timeline-basierte Analyse von ROCm/PyTorch-Workloads mit **Perfetto**.

## 1. Trace erzeugen

```bash
# Empfohlen: Kernel + HIP + Memory (gute Balance aus Detail und Größe)
rocprofv3 --kernel-trace --hip-trace --memory-copy-trace \
  --output-format pftrace \
  -d outdir -o mytrace -- \
  python your_script.py
```

Weitere nützliche Kombinationen:

```bash
# Mit Hardware-Countern (Counter-Tracks in Perfetto)
rocprofv3 --kernel-trace --pmc SQ_WAVES,SQ_INSTS_VALU \
  --output-format pftrace -d outdir -o counters -- python script.py

# Mit Scratch-Memory-Tracks
rocprofv3 --scratch-memory-trace --kernel-trace \
  --output-format pftrace -d outdir -o scratch -- python script.py

# Größere Traces (Achtung: Dateigröße!)
rocprofv3 --runtime-trace --output-format pftrace -d outdir -o runtime -- python script.py
```

**Tipp:** Bei langen Trainingsläufen nur einen kurzen Abschnitt profilieren (nach Warm-up) oder mit `roctx`-Markern Regionen auswählen.

## 2. Trace öffnen

1. Browser öffnen: **https://ui.perfetto.dev**
2. **Open trace file** (oben links)
3. Die erzeugte `.pftrace`-Datei auswählen  
   (lokal – nichts wird hochgeladen)

## 3. Navigation in der Perfetto-UI

| Tastenkombination | Funktion |
|-------------------|----------|
| **W / S** | Zoom rein / raus |
| **A / D** | Links / Rechts schieben |
| **Mausrad** | Zoom |
| **Klick auf Slice** | Details anzeigen |
| **?** | Alle Shortcuts anzeigen |
| **Ctrl+Shift+P** | Command Palette |

## 4. Was du in ROCm-Traces siehst

- **Kernel-Tracks** – einzelne Kernel-Dispatches (Name, Dauer)
- **HIP-API-Tracks** – Runtime-Calls (hipMalloc, hipMemcpy, …)
- **Memory-Copy-Tracks** – Host↔Device Transfers
- **Counter-Tracks** (wenn `--pmc` verwendet) – z. B. SQ_WAVES über die Zeit
- **Scratch-Memory-Tracks** – Allokations-Peaks pro Kernel

**Typische Muster:**
- Viele kurze Kernel hintereinander → Launch-Overhead
- Lange Memory-Copies zwischen Kernels → Datenbewegung optimieren
- Ein dominanter Kernel → hier TunableOp / Architektur-Tuning ansetzen

## 5. Analyse-Tipps

1. **Gesamtüberblick** – erst weit herauszoomen, dann in Hotspots reinzoomen
2. **Kernel-Namen suchen** – in der Suchleiste nach `aten::` oder `gemm` filtern
3. **Zeitbereich markieren** – Statistik der markierten Region anzeigen lassen
4. **SQL-Query** (linke Seite → Query) für aggregierte Auswertungen nutzen  
   Beispiel:
   ```sql
   SELECT name, COUNT(*) AS calls, SUM(dur)/1e6 AS total_ms
   FROM slice
   WHERE name LIKE '%gemm%' OR name LIKE '%mm%'
   GROUP BY name
   ORDER BY total_ms DESC
   LIMIT 20;
   ```
5. **Vergleich** – zwei Traces (vor/nach Optimierung) nebeneinander betrachten

## 6. Dateigröße kontrollieren

| Trace-Typ | Typische Größe | Empfehlung |
|-----------|------------------|------------|
| Nur Kernel | klein | Immer sinnvoll |
| Kernel + HIP | mittel | Standard |
| Runtime / Sys | groß–sehr groß | Nur bei Bedarf |
| Mit PMC | größer | Gezielt einsetzen |

Bei sehr großen Dateien:
- Kürzeren Lauf profilieren
- `--perfetto-buffer-size` anpassen (falls nötig)
- Nur die relevanten Traces aktivieren

## 7. Workflow

1. Kurzen, repräsentativen Lauf mit `--output-format pftrace` aufnehmen
2. In Perfetto öffnen und Hotspots finden
3. Optimierung anwenden (TunableOp, Environment-Variablen, Code)
4. Neuen Trace erzeugen und vergleichen
5. Optional: CSV-Stats (`--stats`) parallel für quantitative Zahlen nutzen

## Links

- Perfetto UI: https://ui.perfetto.dev
- rocprofv3 Docs (Perfetto-Abschnitt):  
  https://rocm.docs.amd.com/projects/rocprofiler-sdk/en/latest/how-to/using-rocprofv3.html
- Perfetto Docs: https://perfetto.dev/docs/

## Siehe auch

- [PROFILING.md](PROFILING.md)
- [KERNEL_OPTIMIZATIONS.md](KERNEL_OPTIMIZATIONS.md)
