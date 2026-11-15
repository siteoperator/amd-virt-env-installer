# AMD Virt / ROCm Performance Tuning

Praktische Tipps für maximale Performance mit ROCm + PyTorch auf AMD-Hardware – besonders in virtuellen Umgebungen, auf CachyOS und bei Ryzen-APUs.

## 1. HSA_OVERRIDE_GFX_VERSION (wichtigstes Tuning)

Viele iGPUs und ältere Karten brauchen diesen Override, damit ROCm die richtigen Kernel lädt.

| GPU / APU              | Empfohlener Wert     | Bemerkung |
|------------------------|----------------------|---------|
| Radeon 680M (7735HS, 6900HX) | `10.3.0`         | RDNA2 |
| Radeon 780M (8845HS, 8835H)  | `11.0.0`         | RDNA3 / Phoenix |
| Radeon 890M (AI 370, AI 470) | `11.0.0` oder `11.5.0` | RDNA 3.5 |
| RX 6700 XT / 6600 etc. | `10.3.0`             | Oft nötig |
| RX 7900 / 7800 (neuere ROCm) | meist **kein** Override | Native |

**Setzen:**

```bash
export HSA_OVERRIDE_GFX_VERSION=11.0.0
# oder dauerhaft in ~/.bashrc / systemd service
```

**Prüfen:**

```bash
rocminfo | grep -E "Marketing Name|Name:|gfx"
```

## 2. System-Tuning (Host & Gast)

### Gruppen & Rechte
```bash
sudo usermod -a -G render,video $USER
# neu einloggen
```

### Kernel-Parameter (optional, je nach Hardware)
- `amdgpu.gttsize=...` – mehr GPU-Memory auf APUs (unified memory)
- `ttm.pages_limit=...` – zusammen mit gttsize
- `iommu=pt` oder `amd_iommu=on` (je nach Setup)
- Ab Linux 7.4: **PerfOpt** für iGPUs bringt oft 15–25 % bei LLM/AI

### CachyOS / Arch Vorteile
- Aktueller Kernel (oft bereits PerfOpt oder bessere amdgpu-Unterstützung)
- Offizielle `rocm-*` Pakete im Extra-Repo
- Schnellere Updates als Ubuntu LTS

## 3. Virtualisierung (VFIO / SR-IOV / Container)

| Methode       | Performance vs. Bare-Metal | Empfehlung |
|---------------|----------------------------|------------|
| **Container** (Docker/Podman) | ~100 % | Beste Wahl für die meisten Fälle |
| **VFIO Passthrough** | ~95–100 % | Volle GPU, Reset-Bug beachten |
| **SR-IOV (Instinct)** | ~96–99 % Bandwidth | Gut für Inference, schlechter für tightly-coupled Multi-GPU |

**Container-Beispiel (nahezu native Performance):**
```bash
docker run --rm -it \
  --device=/dev/kfd --device=/dev/dri \
  --group-add video --group-add render \
  --ipc=host --shm-size 8g \
  rocm/pytorch
```

## 4. PyTorch / Workload-Tuning

```bash
# Nach Aktivierung des venvs
export HSA_OVERRIDE_GFX_VERSION=11.0.0   # falls nötig
export HIP_VISIBLE_DEVICES=0
export HSA_ENABLE_SDMA=0                 # manchmal stabiler auf iGPUs

python -c "import torch; print(torch.cuda.is_available(), torch.cuda.get_device_name(0))"
```

### Empfohlene Flags / Settings
- `torch.backends.cudnn.benchmark = True` (wenn ähnliche Input-Größen)
- Mixed Precision (`torch.autocast`)
- Für LLMs: größere Batch-Sizes wenn VRAM reicht, oder Flash Attention / optimierte Backends

## 5. Monitoring

```bash
# GPU-Auslastung
watch -n 1 rocm-smi

# Oder
rocminfo
amd-smi   # falls verfügbar
```

## 6. Typische Performance-Probleme & Fixes

| Problem                        | Lösung |
|--------------------------------|--------|
| GPU nicht erkannt              | Gruppen + HSA_OVERRIDE + rocminfo prüfen |
| Langsam / CPU-Fallback         | Falscher Override oder fehlende Kernel |
| Reset-Bug nach VM              | Host-Reboot oder vendor-reset (begrenzt) |
| Schlechte iGPU-Performance     | HSA_OVERRIDE + mehr GTT-Memory + aktueller Kernel |
| OOM auf APU                    | Shared Memory Limits anheben (gttsize) |

## 7. Empfohlene Reihenfolge

1. `rocminfo` und `rocm-smi` prüfen
2. Gruppen `render` + `video`
3. Richtiges `HSA_OVERRIDE_GFX_VERSION` setzen
4. Aktuellen Kernel (besonders CachyOS) nutzen
5. Container bevorzugen vor VFIO (weniger Stress)
6. Benchmark mit deinem echten Workload

## Links

- Offizielle ROCm System Optimization: https://rocm.docs.amd.com/en/latest/reference/system-optimization/
- Virtualisierung: [VIRTUALIZATION.md](VIRTUALIZATION.md)
- Installer: [README.md](README.md)
