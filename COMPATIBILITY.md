# AMD GPU / APU Kompatibilitätsliste für ROCm

Stand: ROCm ~7.x / 10.x (Linux + Windows).  
Offizielle Quellen:
- [ROCm GPU & OS Support](https://rocm.docs.amd.com/en/latest/release/gpu_os_support.html)
- [Compatibility Matrix](https://rocm.docs.amd.com/en/docs-10.1.0/compatibility/compatibility-matrix.html)
- [TheRock Supported GPUs](https://github.com/ROCm/TheRock/blob/main/SUPPORTED_GPUS.md)

**Hinweis:** Wenn eine GPU nicht in der offiziellen Matrix steht, ist sie nicht offiziell unterstützt. Viele iGPUs funktionieren trotzdem mit `HSA_OVERRIDE_GFX_VERSION`.

## Instinct (Data Center) – voll unterstützt

| GPU | Architektur | LLVM Target |
|-----|-------------|-------------|
| MI355X / MI350X | CDNA4 | gfx950 |
| MI325X / MI300X / MI300A | CDNA3 | gfx942 |
| MI250X / MI250 / MI210 | CDNA2 | gfx90a |
| MI100 | CDNA | gfx908 |

## Radeon PRO (Workstation)

| GPU | Architektur | LLVM Target |
|-----|-------------|-------------|
| Radeon AI PRO R9700 / R9600D | RDNA4 | gfx1201 |
| PRO W7900 / W7800 | RDNA3 | gfx1100 |
| PRO W7700 / V710 | RDNA3 | gfx1101 |
| PRO W6800 / V620 | RDNA2 | gfx1030 |

## Radeon RX (Consumer) – offiziell unterstützt

| GPU | Architektur | LLVM Target |
|-----|-------------|-------------|
| RX 9070 XT / 9070 / 9070 GRE | RDNA4 | gfx1201 |
| RX 9060 XT / 9060 | RDNA4 | gfx1200 |
| RX 7900 XTX / 7900 XT / 7900 GRE | RDNA3 | gfx1100 |
| RX 7800 XT / 7700 XT / 7700 | RDNA3 | gfx1101 |
| RX 7600 / 7600 XT | RDNA3 | gfx1102 |

**Nicht mehr offiziell unterstützt:** Radeon VII, RX 6000 Serie (außer PRO W6800), ältere Generationen.

## Ryzen APUs / iGPUs

| Serie | iGPU | Architektur | LLVM Target | ROCm-Status | HSA_OVERRIDE Hinweis |
|-------|------|-------------|-------------|-------------|----------------------|
| Ryzen AI Max 300 | 8060S / 8050S | RDNA 3.5 | gfx1151 | Offiziell | meist nicht nötig |
| Ryzen AI 300 / 400 | 890M / 880M | RDNA 3.5 | gfx1150 | Offiziell (neuere ROCm) | ggf. `11.0.0` oder `11.5.0` |
| Ryzen AI 300 / 400 | 860M | RDNA 3.5 | gfx1152 | Offiziell | ggf. `11.0.0` |
| Ryzen 7000/8000 / 200 | 780M | RDNA 3 | gfx1103 | Offiziell (ab ~7.1+) | `11.0.0` |
| Ryzen 7000/8000 / 200 | 760M / 740M | RDNA 3 | gfx1103 | Offiziell | `11.0.0` |
| Ryzen 6000 / 7735 | 680M | RDNA 2 | gfx103x | **Nicht offiziell** | `10.3.0` (Workaround) |

## Praktische Hinweise für dieses Projekt

- **780M** (z. B. 8845HS, 8835H): funktioniert in der Regel mit `HSA_OVERRIDE_GFX_VERSION=11.0.0` und aktuellen ROCm-Versionen.
- **890M** (z. B. AI 370 / 470): zunehmend offiziell unterstützt; ggf. trotzdem Override testen.
- **680M**: nur mit Override, nicht garantiert stabil.
- Immer prüfen mit:
  ```bash
  rocminfo | grep -E "Marketing Name|Name:|gfx"
  ```
- Die offizielle Matrix ändert sich mit jeder ROCm-Version. Aktuelle Liste immer hier prüfen:  
  https://rocm.docs.amd.com/en/latest/release/gpu_os_support.html

## Verwandte Dokumentation

- [HSA_OVERRIDE.md](HSA_OVERRIDE.md)
- [DRIVER_MODULES.md](DRIVER_MODULES.md)
- [DIAGNOSTICS.md](DIAGNOSTICS.md)
