# Run as ADMINISTRATOR, with the Kindle in fastboot (VID_1949 / PID_D0D0) and WinUSB already
# installed with Zadig.
#
# Google's fastboot.exe looks for the Android interface GUID, not the random one Zadig assigns,
# so it doesn't see the device. This sets the Android GUID and restarts the device in Windows
# (it does not power off the Kindle).

$vidpid = 'VID_1949&PID_D0D0'
$guid   = '{F72FE0D4-CBCB-407D-8814-9ED673D0DD6B}'

$dev = Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -like "USB\$vidpid*" } | Select-Object -First 1
if (-not $dev) { throw "No device with $vidpid found. Is the Kindle in fastboot and connected?" }

$inst = $dev.InstanceId
$key  = "HKLM:\SYSTEM\CurrentControlSet\Enum\$inst\Device Parameters"
Write-Host "Device: $inst"

Write-Host "Previous value:" (Get-ItemProperty $key).DeviceInterfaceGUIDs
Set-ItemProperty -Path $key -Name DeviceInterfaceGUIDs -Value @($guid) -Type MultiString
Write-Host "New value:     " (Get-ItemProperty $key).DeviceInterfaceGUIDs

Disable-PnpDevice -InstanceId $inst -Confirm:$false
Start-Sleep 2
Enable-PnpDevice  -InstanceId $inst -Confirm:$false
Start-Sleep 3
Get-PnpDevice -InstanceId $inst | Format-List Status, FriendlyName
Write-Host "Done. Run 'fastboot devices' to check."
