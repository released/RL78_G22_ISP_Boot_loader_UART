param([Parameter(Mandatory=$true)][string]$MapPath,
      [Parameter(Mandatory=$true)][uint32]$RamStart,
      [Parameter(Mandatory=$true)][uint32]$Owner)
$ErrorActionPreference='Stop'
$text=[IO.File]::ReadAllText($MapPath).Replace("`r`n","`n")
$part=[regex]::Match($text,'(?s)\*\*\* Mapping List \*\*\*(.*?)\*\*\* Total Section Size \*\*\*')
if(!$part.Success){throw 'Missing actual linker mapping evidence.'}
$stack=$false;$sum=0L
$rfdSections=@('RFD_CMN_fR','RFD_CF_fR','DRAM_fR','RFD_EXEC_TAIL')
$rfdBounds=@{}
foreach($section in [regex]::Matches($part.Groups[1].Value,'(?m)^(\S+)\s*\n +([0-9a-f]{8}) +([0-9a-f]{8}) +([0-9a-f]+) +\d+')) {
    $name=$section.Groups[1].Value;$start=[Convert]::ToInt64($section.Groups[2].Value,16)
    $end=[Convert]::ToInt64($section.Groups[3].Value,16);$size=[Convert]::ToInt64($section.Groups[4].Value,16)
    if(!$size -or $start -lt 0xF0000){continue}
    if($start -lt $RamStart -or $end -ge 0xFFEE0){throw ('RAM section outside usable target RAM: '+$name)}
    if($start -lt $Owner+16 -and $end -ge $Owner){throw ('No-init owner/handoff overlap: '+$name)}
    if($name -eq '.stack_bss') {if($size -ne 512){throw 'Expected explicit512-byte stack.'};$stack=$true}
    if($name -in $rfdSections) {
        $rfdBounds[$name]=@{ Start=$start; End=$end; Size=$size }
    }
    $sum+=$size
}
if(!$stack){throw 'Missing actual stack reservation.'}
$previousEnd=$null
foreach($name in $rfdSections) {
    $bounds=$rfdBounds[$name]
    if(!$bounds -or $bounds.Size -ne $bounds.End-$bounds.Start+1L) {
        throw "Missing or invalid linked RFD execution section: $name"
    }
    if($null -ne $previousEnd -and $bounds.Start -ne $previousEnd+1L) {
        throw "Gap or overlap in linked RFD execution range at $name"
    }
    $previousEnd=$bounds.End
}
if($rfdBounds['RFD_EXEC_TAIL'].Size -ne 10L){throw 'Expected exactly ten RFD instruction-fetch tail bytes.'}
Write-Host 'PASS contiguous RFD execution sections and ten-byte instruction-fetch tail.'
Write-Host ('PASS actual linker RAM allocation: '+$sum+' bytes including512-byte stack; no owner/register-bank overlap. Dynamic stack hardware NOT RUN.')
