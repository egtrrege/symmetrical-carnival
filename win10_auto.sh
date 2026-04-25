$isoPath = "C:\temp\Win10_1909.iso"
$isoDirectory = Split-Path $isoPath
$minimumSpace = 15
$availableSpace = (Get-Volume C).SizeRemaining / 1GB
$ProgressPreference = 'SilentlyContinue'

if (-not (Test-Path $isoDirectory)) {
    New-Item -Path $isoDirectory -ItemType directory -Force
}

if (Test-Path $isoPath) {
    Remove-Item -Path $isoPath -Force
}

if (-not (Test-Path $isoPath) -and $availableSpace -gt $minimumSpace) { #win10 base download code modified from FIDO: https://raw.githubusercontent.com/pbatard/Fido/master/Fido.ps1

    #base variables
    $SessionId = [guid]::NewGuid()
    $RequestData = @{}
    $RequestData["GetLangs"] = @("a8f8f489-4c7f-463a-9ca6-5cff94d8d041", "getskuinformationbyproductedition" )
    $RequestData["GetLinks"] = @("cfa9e580-a81e-4a4b-a846-7b21bf4e2e5b", "GetProductDownloadLinksBySku" )

    $FirefoxVersion = Get-Random -Minimum 47 -Maximum 60
    [DateTime]$Min = "1/1/2012"
    [DateTime]$Max = [DateTime]::Now
    $RandomGen = new-object random
    $RandomTicks = [Convert]::ToInt64( ($Max.ticks * 1.0 - $Min.Ticks * 1.0 ) * $RandomGen.NextDouble() + $Min.Ticks * 1.0 )
    $Date = new-object DateTime($RandomTicks)
    $FirefoxDate = $Date.ToString("yyyyMMdd")
    $UserAgent = "Mozilla/5.0 (X11; Linux i586; rv:$FirefoxVersion.0) Gecko/$FirefoxDate Firefox/$FirefoxVersion.0"

    $url = "https://www.microsoft.com/en-US/api/controls/contentinclude/html"
    $url += "?pageId=" + $RequestData["GetLangs"][0]
    $url += "&host=www.microsoft.com"
    $url += "&segments=software-download,Windows10ISO"
    $url += "&query=&action=" + $RequestData["GetLangs"][1]
    $url += "&sessionId=" + $SessionId
    $url += "&productEditionId=1214"
    $url += "&sdVersion=2"
    $r = Invoke-WebRequest -UserAgent $UserAgent -WebSession $Session $url

    $url = "https://www.microsoft.com/en-US/api/controls/contentinclude/html"
    $url += "?pageId=" + $RequestData["GetLinks"][0]
    $url += "&host=www.microsoft.com"
    $url += "&segments=software-download,Windows10ISO"
    $url += "&query=&action=" + $RequestData["GetLinks"][1]
    $url += "&sessionId=" + $SessionId
    $url += "&skuId=8143" #english x64 sku id
    $url += "&language=English"
    $url += "&sdVersion=2"
    $r = Invoke-WebRequest -UserAgent $UserAgent -WebSession $Session $url

    $i = 0
    $SelectedIndex = 0
    $array = @()
    try {
        $Is64 = [Environment]::Is64BitOperatingSystem
        $r = Invoke-WebRequest -UserAgent $UserAgent -WebSession $Session $url
        if (-not $($r.AllElements | ? {$_.id -eq "expiration-time"})) {
            Throw-Error -Req $r -Alt Get-Translation($English[14])
        }
        $html = $($r.AllElements | ? {$_.tagname -eq "input"}).outerHTML
        # Need to fix the HTML and JSON data so that it is well-formed
        $html = $html.Replace("class=product-download-hidden", "")
        $html = $html.Replace("type=hidden", "")
        $html = $html.Replace(">", "/>")
        $html = $html.Replace("IsoX86", """x86""")
        $html = $html.Replace("IsoX64", """x64""")
        $html = "<inputs>" + $html + "</inputs>"
        $xml = [xml]$html
        foreach ($var in $xml.inputs.input) {
            $json = $var.value | ConvertFrom-Json;
            if ($json) {
                $SelectedIndex = $i
                $array += @(New-Object PsObject -Property @{ Type = $json.DownloadType; Link = $json.Uri })
                $i++
            }
        }
        if ($array.Length -eq 0) {
            Throw-Error -Req $r -Alt "Could not retrieve ISO download links"
        }
    } catch {
        Write-Output $_.Exception.Message
        return
    }

    $isoLink = $array | Where-Object {$_.Type -eq 'x64'} | Select -ExpandProperty Link #extract only the x64 download link

    Write-Output "Downloading ISO from $isoLink"
    Invoke-WebRequest -UserAgent $UserAgent -WebSession $Session -Uri $isoLink -OutFile $isoPath #initiate the download


}
