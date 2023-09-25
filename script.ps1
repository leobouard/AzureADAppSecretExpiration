param(
    [array]$Webhooks,
    [int]$Days = 30
)

function Get-Expiration {
    param([datetime]$EndDateTime)

    $days = [int](New-TimeSpan -End $EndDateTime).TotalDays
    if ($days -lt 0) { 
        'that has **already expired**'
    } else {
        "that will expire in **$days days**"
    }
}

Connect-MgGraph -Scope User.Read.All, Application.Read.All

$apps = Get-MgApplication
$date = (Get-Date).AddDays($Days)

$apps = $apps | Where-Object {
    ($_.PasswordCredentials -and $_.PasswordCredentials.EndDateTime -lt $date) -or
    ($_.KeyCredentials -and $_.KeyCredentials.EndDateTime -lt $date)
}

if (!$apps) { exit }

[string]$body = @'
{
	"@type": "MessageCard",
	"@context": "https://schema.org/extensions",
	"summary": "Azure AD certificates & secret expiration",
	"themeColor": "0078D7",
	"title": "Azure AD certificates & secret expiration",
	"sections": {{SECTIONS}}
}
'@

[string]$sectionTemplate = @'
{
    "startGroup": true,
    "activityTitle": "$appName",
    "activitySubtitle": "$appId",
    "text": "This Azure AD application uses a $type $expiration",
    "facts": $facts,
    "potentialAction": [
        {
            "@type": "OpenUri",
            "name": "View in Azure",
            "targets": [
                {
                    "os": "default",
                    "uri": "$uri"
                }
            ]
        }
    ]
}
'@

$sections = $apps | ForEach-Object {

    $appName = $_.DisplayName
    $appId   = $_.AppId
    $uri     = "https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Credentials/appId/$appId/isMSAApp~/false"
    $owners  = Get-MgApplicationOwner -ApplicationId $_.Id | ForEach-Object { (Get-MgUser -UserId $_.Id).DisplayName }
    $owners  = $owners -join ', '

    $_.PasswordCredentials | Where-Object {$_.EndDateTime -lt $date} | ForEach-Object {
        $type = 'client secret'
        $expiration = Get-Expiration -EndDateTime $_.EndDateTime
        $hint = if ($_.Hint) { $_.Hint + '******' } else { '' }
        $facts = ([ordered]@{
            'Secret hint' = $hint
            Owners        = $owners -join ', '
            Expiration    = Get-Date $_.EndDateTime -Format 'yyyy-MM-dd HH:mm:ss'
        }).GetEnumerator() | ForEach-Object {[PSCustomObject]@{name=$_.Key;value=$_.Value}} | ConvertTo-Json
        $ExecutionContext.InvokeCommand.ExpandString($sectionTemplate)
        Clear-Variable type,hint,facts
    }

    $_.KeyCredentials | Where-Object {$_.EndDateTime -lt $date} | ForEach-Object {
        $type = 'certificate'
        $expiration = Get-Expiration -EndDateTime $_.EndDateTime
        $facts = ([ordered]@{
            'Certificate name' = $_.DisplayName
            Owners        = $owners -join ', '
            Expiration    = Get-Date $_.EndDateTime -Format 'yyyy-MM-dd HH:mm:ss'
        }).GetEnumerator() | ForEach-Object {[PSCustomObject]@{name=$_.Key;value=$_.Value}} | ConvertTo-Json
        $ExecutionContext.InvokeCommand.ExpandString($sectionTemplate)
        Clear-Variable type,facts
    }

    Clear-Variable appName,appId,uri,owners
}

$sections = "[`n" + ($sections -join ",`n") + "`n]"
$body = $body -replace '{{SECTIONS}}',$sections
$bodyAsBytes = [System.Text.Encoding]::UTF8.GetBytes($body)

$Webhooks | ForEach-Object {
    Invoke-RestMethod -Method POST -Body $bodyAsBytes -Uri $_ -ContentType 'Application/Json'
}
