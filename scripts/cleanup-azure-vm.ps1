# Azure VM ????
# ???? Azure ??

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host "???  Azure Resource Cleanup Script" -ForegroundColor Yellow
Write-Host ""

# ?????????
$rgExists = az group exists --name $ResourceGroup

if ($rgExists -eq "false") {
    Write-Host "? Resource group '$ResourceGroup' does not exist." -ForegroundColor Red
    exit 1
}

# ???????????
Write-Host "?? Resources in '$ResourceGroup':" -ForegroundColor Cyan
az resource list --resource-group $ResourceGroup --output table
Write-Host ""

# ????
if (-not $Force) {
    Write-Host "??  WARNING: This will DELETE ALL resources in the resource group!" -ForegroundColor Red
    Write-Host ""
    $confirmation = Read-Host "Are you sure you want to continue? (yes/no)"
    
    if ($confirmation -ne "yes") {
        Write-Host "? Cleanup cancelled." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host ""
Write-Host "???  Deleting resource group '$ResourceGroup'..." -ForegroundColor Yellow
Write-Host "   This may take several minutes..." -ForegroundColor Gray

# ?????
az group delete --name $ResourceGroup --yes --no-wait

Write-Host ""
Write-Host "? Deletion initiated. Resources are being deleted in the background." -ForegroundColor Green
Write-Host ""
Write-Host "?? To check deletion status, run:" -ForegroundColor Cyan
Write-Host "   az group show --name $ResourceGroup" -ForegroundColor White
Write-Host ""
Write-Host "   If the resource group still exists, wait a few minutes and try again." -ForegroundColor Gray
Write-Host ""
