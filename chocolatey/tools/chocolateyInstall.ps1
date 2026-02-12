$packageName = 'edamame-helper'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$url64 = 'https://github.com/edamametechnologies/edamame_helper/releases/download/v1.0.4/edamame-helper-windows-1.0.4.msi'
$checksum64 = '0000000000000000000000000000000000000000000000000000000000000000'

Install-ChocolateyPackage -PackageName $packageName `
                          -FileType 'msi' `
                          -Url64bit $url64 `
                          -Checksum64 $checksum64 `
                          -ChecksumType64 'sha256' `
                          -SilentArgs '/qn /norestart'




