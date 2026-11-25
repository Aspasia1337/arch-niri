# Guest-side VM detection cleanup
# Run as Administrator in PowerShell

Write-Host "=== VM Detection Cleanup ===" -ForegroundColor Cyan

# 1. MEASURED BOOT LOGS
Write-Host "`n[1] Clearing TCG/Measured Boot logs..." -ForegroundColor Yellow
try {
    $tcgLog = "C:\Windows\Logs\MeasuredBoot"
    if (Test-Path $tcgLog) {
        Remove-Item "$tcgLog\*" -Force -ErrorAction SilentlyContinue
        Write-Host "  [+] Cleared MeasuredBoot logs" -ForegroundColor Green
    } else {
        Write-Host "  [i] No MeasuredBoot directory found" -ForegroundColor Gray
    }

    $wbcLog = "C:\Windows\Logs\WBCLog"
    if (Test-Path $wbcLog) {
        Remove-Item "$wbcLog\*" -Force -ErrorAction SilentlyContinue
        Write-Host "  [+] Cleared WBCLog" -ForegroundColor Green
    }
} catch {
    Write-Host "  [!] Error: $_" -ForegroundColor Red
}

# 2. POWER CAPABILITIES
Write-Host "`n[2] Fixing power capabilities..." -ForegroundColor Yellow
try {
    powercfg /hibernate on 2>$null
    $highPerf = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
    powercfg /setactive $highPerf 2>$null
    powercfg /change monitor-timeout-ac 15
    powercfg /change disk-timeout-ac 0
    powercfg /change standby-timeout-ac 0
    powercfg /change hibernate-timeout-ac 0

    $csKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"
    Set-ItemProperty -Path $csKey -Name "CsEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $csKey -Name "PlatformAoAcOverride" -Value 0 -Type DWord -ErrorAction SilentlyContinue

    Write-Host "  [+] Power plan set to High Performance" -ForegroundColor Green
} catch {
    Write-Host "  [!] Error: $_" -ForegroundColor Red
}

# 3. FIRMWARE/NVRAM
Write-Host "`n[3] Checking firmware identifiers..." -ForegroundColor Yellow
try {
    $qemuPaths = @(
        "HKLM:\HARDWARE\ACPI\DSDT\BOCHS_",
        "HKLM:\HARDWARE\ACPI\FADT\BOCHS_",
        "HKLM:\HARDWARE\ACPI\RSDT\BOCHS_",
        "HKLM:\HARDWARE\ACPI\DSDT\BXPC__",
        "HKLM:\HARDWARE\ACPI\FADT\BXPC__",
        "HKLM:\HARDWARE\ACPI\RSDT\BXPC__"
    )
    foreach ($path in $qemuPaths) {
        if (Test-Path $path) {
            Write-Host "  [!] FOUND VM indicator: $path" -ForegroundColor Red
        }
    }

    if (Test-Path "HKLM:\HARDWARE\ACPI\DSDT\ALASKA") {
        Write-Host "  [+] ACPI OEM is ALASKA (spoofed correctly)" -ForegroundColor Green
    }
    if (Test-Path "HKLM:\HARDWARE\ACPI\DSDT\BOCHS_") {
        Write-Host "  [!] ACPI still shows BOCHS!" -ForegroundColor Red
    }

    Write-Host "  [+] Firmware check complete" -ForegroundColor Green
} catch {
    Write-Host "  [!] Error: $_" -ForegroundColor Red
}

# 4. REGISTRY CLEANUP
Write-Host "`n[4] Cleaning VM registry artifacts..." -ForegroundColor Yellow
try {
    $qemuGA = "HKLM:\SOFTWARE\QEMU"
    if (Test-Path $qemuGA) {
        Remove-Item -Path $qemuGA -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  [+] Removed QEMU registry key" -ForegroundColor Green
    }

    $virtIO = "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI"
    $virtDevs = Get-ChildItem $virtIO -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match "VEN_1AF4" }
    if ($virtDevs) {
        Write-Host "  [!] Found VirtIO PCI devices in registry (ghost devices)" -ForegroundColor Red
        foreach ($dev in $virtDevs) {
            Write-Host "    - $($dev.PSChildName)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  [+] No VirtIO devices found" -ForegroundColor Green
    }

    $spice = "HKLM:\SOFTWARE\Red Hat"
    if (Test-Path $spice) {
        Remove-Item -Path $spice -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  [+] Removed Red Hat/SPICE registry key" -ForegroundColor Green
    }

    Write-Host "  [i] Checking for ghost VirtIO/QEMU devices..." -ForegroundColor Gray
    $ghostClasses = @("SCSI", "System", "Display", "Net")
    foreach ($class in $ghostClasses) {
        $devs = Get-PnpDevice -Class $class -Status Unknown -ErrorAction SilentlyContinue |
            Where-Object { $_.FriendlyName -match "VirtIO|QEMU|Red Hat|Virtio" }
        foreach ($dev in $devs) {
            Write-Host "    [!] Ghost device: $($dev.FriendlyName) [$($dev.InstanceId)]" -ForegroundColor Red
            pnputil /remove-device "$($dev.InstanceId)" 2>$null
            Write-Host "    [+] Removed ghost device" -ForegroundColor Green
        }
    }
} catch {
    Write-Host "  [!] Error: $_" -ForegroundColor Red
}

# 5. HYPERVISOR LAUNCH TYPE
Write-Host "`n[5] Checking hypervisor launch type..." -ForegroundColor Yellow
$bcdOutput = bcdedit /enum "{current}" 2>$null | Select-String "hypervisorlaunchtype"
if ($bcdOutput -and $bcdOutput -notmatch "Off") {
    bcdedit /set "{current}" hypervisorlaunchtype off 2>$null
    Write-Host "  [+] Disabled hypervisorlaunchtype" -ForegroundColor Green
} else {
    Write-Host "  [+] hypervisorlaunchtype already off or not set" -ForegroundColor Green
}

# 6. EVENT LOGS
Write-Host "`n[6] Clearing relevant event logs..." -ForegroundColor Yellow
try {
    wevtutil cl "Microsoft-Windows-TPM-WMI" 2>$null
    wevtutil cl "Microsoft-Windows-Kernel-Boot/Analytic" 2>$null
    Write-Host "  [+] Cleared TPM and boot event logs" -ForegroundColor Green
} catch {
    Write-Host "  [!] Error: $_" -ForegroundColor Red
}

# 7. Summary
Write-Host "`n=== Cleanup Summary ===" -ForegroundColor Cyan
Write-Host "The following detections need HOST-SIDE fixes:" -ForegroundColor Yellow
Write-Host "  - CPUID signatures: KVM module patches" -ForegroundColor Gray
Write-Host "  - PCI vendor/device ID: QEMU subsystem ID patches" -ForegroundColor Gray
Write-Host "  - System timers/KVM interception: inherent to VM" -ForegroundColor Gray
Write-Host ""
Write-Host "Reboot required for changes to take effect." -ForegroundColor Yellow
