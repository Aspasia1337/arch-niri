# passthrough notes

Technical notes for the VFIO GPU-passthrough guest. The XML here is a sanitized
template (MACs, UUIDs and SMBIOS identifiers are placeholders); fill them in with
your own hardware before `virsh define`.

## 1. Gather your machine's info

Run these on the host.

**PCI IDs of the GPU and its audio function** (what gets passed through):

```sh
lspci -nnk | grep -A3 -iE 'VGA|audio'
```

Note the `bus:slot.function` (e.g. `0d:00.0` video, `0d:00.1` audio) and the
`[vendor:device]` ids. Put the addresses in the libvirt `<hostdev>` entries and in
the release hook (`hooks/qemu`).

**IOMMU groups** - the GPU and its audio function must sit in their own group:

```sh
for g in /sys/kernel/iommu_groups/*; do
  echo "group ${g##*/}:"
  for d in "$g"/devices/*; do echo "  $(lspci -nns "${d##*/}")"; done
done
```

**SMBIOS / DMI strings** for the spoof (needs root):

```sh
sudo dmidecode -t 0   # BIOS:    vendor, version, release date
sudo dmidecode -t 1   # System:  manufacturer, product, uuid, serial
sudo dmidecode -t 2   # Board:   manufacturer, product, version
sudo dmidecode -t 3   # Chassis: manufacturer
```

Copy those into the `-smbios` `qemu:arg` lines in `vm/win11_gpu.xml`.

## 2. Dynamic bind / unbind

The GPU stays on the host when idle and is handed to the VM on demand:

- **Start:** the `<hostdev>` entries use `managed='yes'`, so libvirt detaches the
  GPU from `amdgpu` and binds it to `vfio-pci` automatically. No `vfio-pci.ids=`
  on the kernel command line, no early `mkinitcpio` binding.
- **Stop:** `hooks/qemu` runs on release, unbinds the card from `vfio-pci`,
  reloads `amdgpu` + `snd_hda_intel`, and re-enables the virtual consoles.

Install the hook:

```sh
sudo install -m755 hooks/qemu /etc/libvirt/hooks/qemu
```

## 3. Hiding the hypervisor

Anti-cheat and anti-analysis code often checks whether it is running in a VM.
These settings (in `<features>` of `vm/win11_gpu.xml`) make that detection fail:

| Setting | Effect |
| --- | --- |
| `<kvm><hidden state='on'/>` | Clears the hypervisor-present CPUID bit (leaf `0x1` ecx[31]) and hides the `KVMKVMKVM` signature at leaf `0x40000000`, so a CPUID check sees no hypervisor. |
| `<hyperv>` enlightenments | Performance features for Windows (timers, interrupts, spinlocks). They advertise Hyper-V, so on their own they reveal the VM. |
| `<vendor_id state='on' value='...'/>` | Spoofs the Hyper-V vendor id; without it the guest reports the default `Microsoft Hv`, a giveaway. Use any 12-character string. |
| `<vmport state='off'/>` | Disables the VMware backdoor I/O port (`0x5658`) that many anti-VM routines probe. |
| `host-passthrough` CPU | Exposes the real Ryzen CPUID and topology (`cores=6, threads=2`, `topoext`) instead of a generic QEMU CPU. |
| `hpet` off, `hypervclock` on, `localtime` | Timer/clock behavior that matches a normal Windows box. |
| SMBIOS spoofing (`type=0..3`) | The guest's firmware reports real bare-metal DMI instead of QEMU defaults. |

Keep the spoofed values internally consistent (for example the `type=1` SMBIOS
uuid), and match them to the host where possible, so nothing contradicts a real
machine.

This covers the common giveaways, but it is only a starting point - a determined
detector probes many more vectors (CPUID timing and hypervisor leaves, ACPI and PCI
device strings, MAC OUI, MSRs, registry and driver artifacts, interrupt timing, and so
on). How far you take it is up to whoever runs this. A good way to see what actually
gets checked is to run a detection library like
[VMAware](https://github.com/kernelwernel/VMAware) inside the guest and close the gaps
it reports; for the deeper tricks, dig through [UnknownCheats](https://www.unknowncheats.me).

## 4. Real disk (PCIe passthrough)

The guest does not use a qcow2/raw image. The boot drive is a **whole physical NVMe
passed through by PCIe** (a `<hostdev>` with `boot order='1'`), so:

- The guest sees a real disk with genuine model/serial and SMART/identify data - there
  is no virtual-disk fingerprint for anti-analysis code to spot.
- Native NVMe performance, no virtual storage layer.
- Because it is the actual physical drive, **the same Windows install can be booted
  directly on bare metal** when needed (just select it in the firmware boot menu); the
  VM and a native boot share one disk.

Find the drive's PCI address and confirm its IOMMU group with:

```sh
lspci -nnk | grep -iA2 'Non-Volatile memory'
```

Pass the controller through as its own `<hostdev>` and give it `boot order='1'`. Keep
this disk off the host's fstab so the two never mount it at once.

## 5. CPU pinning

vCPUs are pinned 1:1 to physical cores and their SMT siblings so the scheduler
does not bounce them, which keeps latency low for games and timing-sensitive code.
Find your core/sibling layout with:

```sh
lscpu -e
cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | sort -u
```

## 6. Define a guest

```sh
# edit vm/win11_gpu.xml for your PCI IDs, SMBIOS, MAC and disk paths first
virsh define vm/win11_gpu.xml
```
