# AMD GPU Virtualisierung

Übersicht über Virtualisierungsmöglichkeiten für AMD GPUs im Kontext von ROCm und diesem Installer.

## Wichtige Unterscheidung

| Methode              | Geeignet für                          | ROCm-Unterstützung | Bemerkung |
|----------------------|-------------------------------------|-------------------|---------|
| **VFIO Passthrough** | Consumer Radeon + Instinct          | Ja (Gast)         | GPU gehört komplett einer VM |
| **SR-IOV (MxGPU/GIM)** | Instinct MI200/MI300/MI350 + ausgewählte Radeon PRO | Ja (Gast) | Eine GPU in mehrere Virtual Functions aufteilen |
| **Container (Docker/Podman)** | Alle ROCm-fähigen GPUs             | Ja                | Einfachste Lösung, kein Hypervisor |
| **LXC / Privileged Container** | Alle                               | Ja                | Host-Treiber wird geteilt |

**Consumer-Radeon (RX 6000/7000/9000)** unterstützen offiziell **kein SR-IOV**.  
Nur vollständiger VFIO-Passthrough oder Container sind praktikabel.

## 1. VFIO GPU Passthrough (QEMU/KVM, Proxmox, libvirt)

### Voraussetzungen Host
- IOMMU aktiviert (BIOS: AMD-Vi / IOMMU)
- Kernel-Parameter: `amd_iommu=on iommu=pt` (oder äquivalent)
- GPU und zugehörige Audio-Funktion an `vfio-pci` gebunden
- Kein `amdgpu`-Treiber auf dem Host für die durchgereichte Karte (oder sauberes Unbind)

### Typische Schritte
1. IOMMU-Gruppen prüfen (`find /sys/kernel/iommu_groups -type l`)
2. GPU-IDs ermitteln (`lspci -nn | grep VGA`)
3. VFIO-Module laden und IDs binden
4. VM mit PCIe-Passthrough erstellen (Q35 + OVMF empfohlen)
5. Im **Gast** ROCm / diesen Installer ausführen

### Bekannte Probleme
- **Reset Bug** bei älteren AMD-Karten (Polaris, Vega, teilweise Navi) – nach VM-Shutdown kehrt die GPU nicht sauber zum Host zurück.
- RX 6000/7000/9000 sind oft besser, aber nicht garantiert reset-safe.
- Workaround: Host-Reboot oder spezielle Hook-Skripte / vendor-reset (begrenzt).

### Empfehlung
Für reine Compute-Workloads (ROCm/PyTorch) sind **Container** oft einfacher und stabiler als volles Passthrough.

## 2. SR-IOV / MxGPU (nur Instinct & ausgewählte PRO)

Offiziell unterstützt auf:
- Instinct MI210, MI300X, MI325X, MI350X, MI355X
- Radeon PRO V710 u. ä.

Erfordert den **AMD GPU Virtualization Driver (GIM)**.  
Damit kann eine physische GPU in mehrere Virtual Functions (VFs) aufgeteilt und an verschiedene VMs weitergegeben werden.

Dokumentation:  
https://instinct.docs.amd.com/projects/virt-drv/

## 3. Container (empfohlen für die meisten Fälle)

```bash
# Beispiel mit dem offiziellen ROCm-Docker-Image
docker run --rm -it --device=/dev/kfd --device=/dev/dri \
  --group-add video --group-add render \
  rocm/pytorch
```

Oder mit dem hier erstellten venv auf dem Host und Device-Passthrough.

Vorteile:
- Kein Reset-Problem
- Nahezu native Performance
- Einfache Verwaltung

## 4. ROCm im Gast (nach Passthrough)

Sobald die GPU in der VM sichtbar ist (`lspci` zeigt die AMD-Karte), kann dieser Installer ganz normal im Gast verwendet werden:

```bash
./install.sh
# oder
INSTALL_ROCM=1 ./install.sh
```

Zusätzlich prüfen:
- Benutzer in Gruppen `render` und `video`
- `/dev/kfd` und `/dev/dri` vorhanden
- `rocminfo` zeigt die GPU

## Nützliche Links

- AMD ROCm Virtualization Docs: https://rocm.docs.amd.com/
- Instinct Virtualization Driver: https://instinct.docs.amd.com/projects/virt-drv/
- VFIO-Guides (Community): Arch Wiki, Proxmox Forum, Level1Techs
- Reset-Bug Diskussionen: oft bei RX 5000/6000 Serien

## Zusammenfassung

| Use-Case                     | Beste Lösung                  |
|-----------------------------|-------------------------------|
| Einzelne VM, volle GPU      | VFIO Passthrough              |
| Mehrere VMs, eine GPU teilen| SR-IOV (nur Instinct/PRO)     |
| Entwicklung / AI Workloads  | Docker/Podman mit Device-Passthrough |
| Homelab / Proxmox           | LXC oder VFIO (mit Reset-Prüfung) |

Bei Fragen oder konkreten Setups (Proxmox, KVM, bestimmte GPU) einfach Issue eröffnen.
