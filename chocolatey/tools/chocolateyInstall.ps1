$packageName = 'edamame-helper'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$url64 = 'https://github.com/edamametechnologies/edamame_helper/releases/download/v2.0.0/edamame-helper-windows-2.0.0.msi'
$checksum64 = '0000000000000000000000000000000000000000000000000000000000000000'

Install-ChocolateyPackage -PackageName $packageName `
                          -FileType 'msi' `
                          -Url64bit $url64 `
                          -Checksum64 $checksum64 `
                          -ChecksumType64 'sha256' `
                          -SilentArgs '/qn /norestart'




