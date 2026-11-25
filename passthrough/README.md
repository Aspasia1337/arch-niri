# GPU passthrough

Dual-GPU VFIO passthrough to a Windows guest with hypervisor hiding. Both GPUs
stay on the host when no VM is running and are handed over on demand.

## 1. Gather hardware info

```sh
# PCI addresses of both GPUs and their audio functions
lspci -nnk | grep -A3 -iE 'VGA|audio'

# IOMMU groups — each GPU must sit in its own group
for g in /sys/kernel/iommu_groups/*; do
  echo "group ${g##*/}:"
  for d in "$g"/devices/*; do echo "  $(lspci -nns "${d##*/}")"; done
done

# SMBIOS strings for the spoof (needs root)
sudo dmidecode -t 0   # BIOS:    vendor, version, release date
sudo dmidecode -t 1   # System:  manufacturer, product, uuid, serial
sudo dmidecode -t 2   # Board:   manufacturer, product, version
sudo dmidecode -t 3   # Chassis: manufacturer
```

Put GPU PCI addresses in the libvirt `<hostdev>` entries and in `hooks/qemu`.
Copy SMBIOS values into the `-smbios` `qemu:arg` lines in the VM XML.

## 2. Dynamic bind / unbind

- **Start:** `managed='yes'` in `<hostdev>` — libvirt detaches both GPUs from
  the host driver and binds them to `vfio-pci` automatically.
- **Stop:** `hooks/qemu` runs on release, unbinds from `vfio-pci`, reloads
  `amdgpu` + `snd_hda_intel`, and re-enables the virtual consoles.

```sh
sudo install -m755 hooks/qemu /etc/libvirt/hooks/qemu
```

## 3. Hypervisor hiding

| Setting | Effect |
| --- | --- |
| `kvm hidden='on'` | Clears hypervisor CPUID bit and KVM signature |
| `vendor_id` spoof | Hides the default `Microsoft Hv` string |
| `vmport state='off'` | Disables the VMware backdoor I/O port |
| `host-passthrough` CPU | Exposes real CPUID and topology |
| SMBIOS spoofing | Guest firmware reports real bare-metal DMI |

## 4. Real disk (PCIe passthrough)

The boot drive is a physical NVMe passed through by PCIe — the guest sees a real
disk with genuine SMART/identify data. The same Windows install can be booted
directly on bare metal when needed.

## 5. CPU pinning

vCPUs are pinned 1:1 to physical cores and their SMT siblings. Find your layout:

```sh
lscpu -e
cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | sort -u
```

## 6. USB toggle scripts

Scripts for hot-swapping USB peripherals between host and VM:

| Script | Description |
| --- | --- |
| [`usb_dygma_toggle.py`](scripts/usb_dygma_toggle.py) | Escape on a control keyboard toggles devices |
| [`usb_mouse_toggle.py`](scripts/usb_mouse_toggle.py) | Mouse side buttons to VM, keyboard combo to host |
| [`usb_toggle.sh`](scripts/usb_toggle.sh) | Simple CLI toggle |

All scripts use placeholders — edit the device IDs (`lsusb`) and VM domain name
before use.

## 7. Guest cleanup

[`guest_cleanup.ps1`](scripts/guest_cleanup.ps1) — run inside the Windows guest
as Administrator. Clears measured boot logs, fixes power capabilities, removes
QEMU/VirtIO registry artifacts, and disables hypervisor launch type.

## 8. Define the VM

```sh
# Edit vm/win11_gpu.xml with your PCI addresses, SMBIOS, MAC and disk paths
virsh define vm/win11_gpu.xml
```
