#!/bin/bash
# Toggle USB devices between host and VM
# Usage: ./usb_toggle.sh [to-vm|to-host]
#   No args = auto-toggle (detect current state)

DOMAIN="YOUR_VM_NAME"
VIRSH="virsh --connect qemu:///system"

# Replace with your USB vendor:product IDs (lsusb)
KB_XML='<hostdev mode="subsystem" type="usb" managed="yes"><source><vendor id="0x0000"/><product id="0x0000"/></source></hostdev>'
MOUSE_XML='<hostdev mode="subsystem" type="usb" managed="yes"><source><vendor id="0x0000"/><product id="0x0000"/></source></hostdev>'

KB_FILE=$(mktemp /tmp/usb_kb_XXXX.xml)
MOUSE_FILE=$(mktemp /tmp/usb_mouse_XXXX.xml)
echo "$KB_XML" > "$KB_FILE"
echo "$MOUSE_XML" > "$MOUSE_FILE"
trap "rm -f $KB_FILE $MOUSE_FILE" EXIT

if ! $VIRSH domstate "$DOMAIN" 2>/dev/null | grep -q running; then
    echo "VM '$DOMAIN' is not running"
    exit 1
fi

in_vm() {
    $VIRSH dumpxml "$DOMAIN" 2>/dev/null | grep -q '0x0000'
}

action="${1:-auto}"
if [ "$action" = "auto" ]; then
    if in_vm; then
        action="to-host"
    else
        action="to-vm"
    fi
fi

case "$action" in
    to-vm)
        echo ">>> Passing devices to VM..."
        $VIRSH attach-device "$DOMAIN" "$KB_FILE" --live 2>&1
        $VIRSH attach-device "$DOMAIN" "$MOUSE_FILE" --live 2>&1
        echo ">>> Done. Devices now in VM."
        ;;
    to-host)
        echo ">>> Returning devices to host..."
        $VIRSH detach-device "$DOMAIN" "$KB_FILE" --live 2>&1
        $VIRSH detach-device "$DOMAIN" "$MOUSE_FILE" --live 2>&1
        echo ">>> Done. Devices now on host."
        ;;
    *)
        echo "Usage: $0 [to-vm|to-host]"
        exit 1
        ;;
esac
