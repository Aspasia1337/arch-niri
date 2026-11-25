#!/usr/bin/env python3
"""
USB passthrough toggle for QEMU/KVM + libvirt.

Listens for Escape on a secondary keyboard (always stays on the host)
and toggles other USB devices between host and VM.

The secondary keyboard never gets passed through — it is the control
device that lets you recover your peripherals at any time.

Usage:
    sudo python3 usb_dygma_toggle.py
"""

import os
import sys
import time
import struct
import threading
import subprocess
import xml.etree.ElementTree as ET

# ── Configuration ────────────────────────────────────────────────────
# VM domain name (virsh list --all)
DOMAIN = "YOUR_VM_NAME"
VIRSH = ["virsh", "--connect", "qemu:///system"]

# Devices that get passed through to the VM
USB_DEVICES = [
    # (vendor_id, product_id, "label")
    # Find yours with: lsusb
    (0x0000, 0x0000, "Keyboard"),
    (0x0000, 0x0000, "Mouse"),
]

# Control device — ALWAYS stays on host, triggers the toggle
# Find yours with: ls /dev/input/by-id/
CONTROL_KBD_BY_ID = "usb-YOUR_CONTROL_KEYBOARD-event-kbd"

# ── evdev constants ──────────────────────────────────────────────────
EV_FORMAT = "llHHi"
EV_SIZE = struct.calcsize(EV_FORMAT)
EV_KEY = 0x01
KEY_ESCAPE = 1

lock = threading.Lock()


def virsh(*args, input_xml=None):
    return subprocess.run(
        VIRSH + list(args),
        input=input_xml,
        text=True,
        capture_output=True,
    )


def is_vm_running():
    result = virsh("domstate", DOMAIN)
    if result.returncode != 0:
        print("[ERROR]", result.stderr.strip())
        return False
    return result.stdout.strip().lower() in ("running",)


def get_attached_devices():
    result = virsh("dumpxml", DOMAIN)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip())

    root = ET.fromstring(result.stdout)
    attached = {}

    for dev in root.findall("./devices/hostdev"):
        if dev.get("type") != "usb":
            continue
        vendor = dev.find("./source/vendor")
        product = dev.find("./source/product")
        if vendor is None or product is None:
            continue
        vid = int(vendor.get("id"), 16)
        pid = int(product.get("id"), 16)
        attached[(vid, pid)] = ET.tostring(dev, encoding="unicode")

    return attached


def make_usb_xml(vid, pid):
    return (
        '<hostdev mode="subsystem" type="usb" managed="yes">'
        "<source>"
        f'<vendor id="0x{vid:04x}"/>'
        f'<product id="0x{pid:04x}"/>'
        "</source>"
        "</hostdev>"
    )


def toggle_to_vm():
    with lock:
        if not is_vm_running():
            print("[!] VM is not running")
            return

        print("\n[>>] Attaching devices to VM...")
        try:
            attached = get_attached_devices()
        except Exception as exc:
            print("[ERROR]", exc)
            return

        for vid, pid, name in USB_DEVICES:
            if (vid, pid) in attached:
                print(f"[=] {name} already in VM")
                continue
            xml = make_usb_xml(vid, pid)
            result = virsh(
                "attach-device", DOMAIN, "/dev/stdin", "--live",
                input_xml=xml,
            )
            if result.returncode == 0:
                print(f"[OK] {name} -> VM")
            else:
                print(f"[ERROR] {name}: {result.stderr.strip()}")

        print("[*] Control keyboard stays on host")
        print("[*] Press Escape to return devices\n")


def toggle_to_host():
    with lock:
        if not is_vm_running():
            print("[!] VM not running; nothing to detach")
            return

        print("\n[<<] Returning devices to host...")
        try:
            attached = get_attached_devices()
        except Exception as exc:
            print("[ERROR]", exc)
            return

        for vid, pid, name in USB_DEVICES:
            xml = attached.get((vid, pid))
            if xml is None:
                print(f"[=] {name} already on host")
                continue
            result = virsh(
                "detach-device", DOMAIN, "/dev/stdin", "--live",
                input_xml=xml,
            )
            if result.returncode == 0:
                print(f"[OK] {name} -> host")
            else:
                print(f"[ERROR] {name}: {result.stderr.strip()}")

        print("[*] Devices recovered\n")


def devices_are_in_vm():
    try:
        attached = get_attached_devices()
    except Exception:
        return False
    return any((vid, pid) in attached for vid, pid, _ in USB_DEVICES)


def toggle():
    if devices_are_in_vm():
        toggle_to_host()
    else:
        toggle_to_vm()


def find_event_device(by_id_name):
    path = f"/dev/input/by-id/{by_id_name}"
    if os.path.exists(path):
        return os.path.realpath(path)
    return None


def watch_control_kbd():
    while True:
        dev = find_event_device(CONTROL_KBD_BY_ID)
        if dev is None:
            time.sleep(0.5)
            continue

        try:
            with open(dev, "rb", buffering=0) as f:
                print(f"[*] Listening on control keyboard: {dev}")
                while True:
                    data = f.read(EV_SIZE)
                    if len(data) != EV_SIZE:
                        break
                    _, _, ev_type, code, value = struct.unpack(
                        EV_FORMAT, data
                    )
                    if ev_type != EV_KEY:
                        continue
                    if code == KEY_ESCAPE and value == 1:
                        print("[!] Escape pressed — toggling")
                        threading.Thread(
                            target=toggle, daemon=True,
                        ).start()

        except (OSError, IOError) as exc:
            print(f"[*] Control keyboard disconnected: {exc}")

        time.sleep(0.5)


def main():
    if os.geteuid() != 0:
        print("Run with sudo")
        sys.exit(1)

    print("=" * 50)
    print("   USB PASSTHROUGH TOGGLE")
    print("=" * 50)
    print(f"VM: {DOMAIN}")
    print("Control keyboard: ALWAYS ON HOST")
    for _, _, name in USB_DEVICES:
        print(f"  {name}: toggleable")
    print()

    if is_vm_running():
        print("[*] VM running")
        try:
            attached = get_attached_devices()
            for vid, pid, name in USB_DEVICES:
                where = "VM" if (vid, pid) in attached else "host"
                print(f"[*] {name}: {where}")
        except Exception as exc:
            print("[ERROR]", exc)
    else:
        print("[*] VM not running")

    print()
    print("[Escape] Toggle devices between host and VM")
    print()

    t = threading.Thread(target=watch_control_kbd, daemon=True)
    t.start()

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\n[*] Stopped")


if __name__ == "__main__":
    main()
