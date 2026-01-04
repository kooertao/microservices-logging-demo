# Fix Consul Connect Injector Certificate Issue
# This script addresses the expired certificate problem with Consul Connect
# Run this before deploy.ps1 to resolve webhook certificate issues

Write-Host "Consul Connect Injector Certificate Fix" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Function to check if a command exists
function Test-CommandExists {
    param($Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

# Check prerequisites
Write-Host "[Prerequisites] Checking required tools..." -ForegroundColor Green
$missingTools = @()

if (!(Test-CommandExists "kubectl")) {
    $missingTools += "kubectl"
}

if ($missingTools.Count -gt 0) {
    Write-Host "  Missing required tools: $($missingTools -join ', ')" -ForegroundColor Red
    Write-Host "  Please install missing tools and try again." -ForegroundColor Red
    exit 1
}

Write-Host "  All required tools found" -ForegroundColor Green
Write-Host ""

# Step 1: Check if Consul is installed and causing issues
Write-Host "[1/3] Checking Consul installation..." -ForegroundColor Green

try {
    $consulPods = kubectl get pods --all-namespaces -l app=consul -o wide 2>$null
    if ($consulPods -and $consulPods.Count -gt 1) {
        Write-Host "  Found Consul installation:" -ForegroundColor Yellow
        kubectl get pods --all-namespaces -l app=consul
        Write-Host ""
    } else {
        Write-Host "  No Consul pods found directly" -ForegroundColor Gray
    }

    # Check for consul-connect specifically
    $consulConnectPods = kubectl get pods --all-namespaces -l app=consul-connect-injector 2>$null
    if ($consulConnectPods -and $consulConnectPods.Count -gt 1) {
        Write-Host "  Found Consul Connect Injector pods:" -ForegroundColor Yellow
        kubectl get pods --all-namespaces -l app=consul-connect-injector
        Write-Host ""
    }
}
catch {
    Write-Host "  Error checking Consul pods: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Step 2: Check webhook configurations
Write-Host "[2/3] Checking webhook configurations..." -ForegroundColor Green

try {
    # Check mutating webhooks
    $mutatingWebhooks = kubectl get mutatingwebhookconfigurations -o name 2>$null | Select-String "consul"
    if ($mutatingWebhooks) {
        Write-Host "  Found Consul mutating webhook configurations:" -ForegroundColor Yellow
        $mutatingWebhooks | ForEach-Object {
            $webhookName = ($_ -split '/')[1]
            Write-Host "    - $webhookName" -ForegroundColor Cyan
            
            # Get webhook details to check certificate expiration
            $webhookDetails = kubectl get mutatingwebhookconfigurations $webhookName -o json 2>$null | ConvertFrom-Json
            if ($webhookDetails -and $webhookDetails.webhooks) {
                $webhookDetails.webhooks | ForEach-Object {
                    if ($_.clientConfig.service) {
                        Write-Host "      Service: $($_.clientConfig.service.name) (namespace: $($_.clientConfig.service.namespace))" -ForegroundColor Gray
                    }
                }
            }
        }
        Write-Host ""
    } else {
        Write-Host "  No Consul mutating webhook configurations found" -ForegroundColor Green
    }

    # Check validating webhooks
    $validatingWebhooks = kubectl get validatingwebhookconfigurations -o name 2>$null | Select-String "consul"
    if ($validatingWebhooks) {
        Write-Host "  Found Consul validating webhook configurations:" -ForegroundColor Yellow
        $validatingWebhooks | ForEach-Object {
            Write-Host "    - $(($_ -split '/')[1])" -ForegroundColor Cyan
        }
        Write-Host ""
    }
}
catch {
    Write-Host "  Error checking webhooks: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Step 3: Manual certificate regeneration
Write-Host "[3/3] Manual certificate regeneration..." -ForegroundColor Green

$fixed = $false

Write-Host "  Trying manual certificate regeneration..." -ForegroundColor Yellow

# Find Consul namespaces
$consulNamespaces = @()
try {
    $allNamespaces = kubectl get namespaces -o name 2>$null
    $consulNamespaces = $allNamespaces | Where-Object { $_ -match "consul" } | ForEach-Object { ($_ -split '/')[1] }
    
    if (-not $consulNamespaces) {
        # Also check for common namespace names
        $commonConsulNamespaces = @("consul", "consul-system", "hashicorp-consul", "default")
        foreach ($ns in $commonConsulNamespaces) {
            $nsExists = kubectl get namespace $ns 2>$null
            if ($LASTEXITCODE -eq 0) {
                $consulNamespaces += $ns
            }
        }
    }
}
catch {
    Write-Host "    Error finding namespaces: $($_.Exception.Message)" -ForegroundColor Yellow
}

if ($consulNamespaces) {
    foreach ($ns in $consulNamespaces) {
        Write-Host "    Processing namespace: $ns" -ForegroundColor Cyan
        
        # Delete certificate secrets
        try {
            $certSecrets = kubectl get secrets -n $ns -o name 2>$null | Select-String "consul.*cert|tls"
            if ($certSecrets) {
                Write-Host "      Deleting expired certificate secrets..." -ForegroundColor Yellow
                $certSecrets | ForEach-Object {
                    $secretName = ($_ -split '/')[1]
                    kubectl delete secret $secretName -n $ns 2>$null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "        ? Deleted secret: $secretName" -ForegroundColor Green
                        $fixed = $true
                    }
                }
            }
        }
        catch {
            Write-Host "      Error deleting secrets: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
        # Restart Consul Connect Injector
        try {
            $injectorDeployments = kubectl get deployment -n $ns -o name 2>$null | Select-String "consul.*inject"
            if ($injectorDeployments) {
                $injectorDeployments | ForEach-Object {
                    $deploymentName = ($_ -split '/')[1]
                    Write-Host "      Restarting deployment: $deploymentName" -ForegroundColor Yellow
                    kubectl rollout restart deployment $deploymentName -n $ns 2>$null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "      Waiting for rollout to complete..." -ForegroundColor Yellow
                        kubectl rollout status deployment $deploymentName -n $ns --timeout=120s 2>$null
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "        ? Successfully restarted $deploymentName" -ForegroundColor Green
                            $fixed = $true
                        }
                    }
                }
            }
        }
        catch {
            Write-Host "      Error restarting deployments: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
        # Also try to restart other Consul components
        try {
            $otherConsulDeployments = kubectl get deployment -n $ns -o name 2>$null | Select-String "consul" | Select-String -NotMatch "inject"
            if ($otherConsulDeployments) {
                $otherConsulDeployments | ForEach-Object {
                    $deploymentName = ($_ -split '/')[1]
                    Write-Host "      Restarting Consul component: $deploymentName" -ForegroundColor Yellow
                    kubectl rollout restart deployment $deploymentName -n $ns 2>$null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "        ? Successfully restarted $deploymentName" -ForegroundColor Green
                        $fixed = $true
                    }
                }
            }
        }
        catch {
            Write-Host "      Error restarting Consul components: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
        # Check for StatefulSets (like Consul servers)
        try {
            $consulStatefulSets = kubectl get statefulset -n $ns -o name 2>$null | Select-String "consul"
            if ($consulStatefulSets) {
                $consulStatefulSets | ForEach-Object {
                    $statefulSetName = ($_ -split '/')[1]
                    Write-Host "      Restarting StatefulSet: $statefulSetName" -ForegroundColor Yellow
                    kubectl rollout restart statefulset $statefulSetName -n $ns 2>$null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "        ? Successfully restarted $statefulSetName" -ForegroundColor Green
                        $fixed = $true
                    }
                }
            }
        }
        catch {
            Write-Host "      Error restarting StatefulSets: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
        # Remove problematic webhooks if they still exist
        Write-Host "      Removing problematic webhook configurations..." -ForegroundColor Yellow
        
        # Remove mutating webhooks
        $mutatingWebhooks = kubectl get mutatingwebhookconfigurations -o name 2>$null | Select-String "consul"
        if ($mutatingWebhooks) {
            $mutatingWebhooks | ForEach-Object {
                $webhookName = ($_ -split '/')[1]
                Write-Host "        Removing mutating webhook: $webhookName" -ForegroundColor Red
                kubectl delete mutatingwebhookconfigurations $webhookName 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "          ? Removed $webhookName" -ForegroundColor Green
                    $fixed = $true
                }
            }
        }
        
        # Remove validating webhooks
        $validatingWebhooks = kubectl get validatingwebhookconfigurations -o name 2>$null | Select-String "consul"
        if ($validatingWebhooks) {
            $validatingWebhooks | ForEach-Object {
                $webhookName = ($_ -split '/')[1]
                Write-Host "        Removing validating webhook: $webhookName" -ForegroundColor Red
                kubectl delete validatingwebhookconfigurations $webhookName 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "          ? Removed $webhookName" -ForegroundColor Green
                    $fixed = $true
                }
            }
        }
    }
} else {
    Write-Host "    No Consul namespaces found" -ForegroundColor Gray
    
    # Still try to remove webhook configurations even without Consul namespaces
    Write-Host "    Removing problematic webhook configurations..." -ForegroundColor Yellow
    
    # Remove mutating webhooks
    $mutatingWebhooks = kubectl get mutatingwebhookconfigurations -o name 2>$null | Select-String "consul"
    if ($mutatingWebhooks) {
        $mutatingWebhooks | ForEach-Object {
            $webhookName = ($_ -split '/')[1]
            Write-Host "      Removing mutating webhook: $webhookName" -ForegroundColor Red
            kubectl delete mutatingwebhookconfigurations $webhookName 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "        ? Removed $webhookName" -ForegroundColor Green
                $fixed = $true
            }
        }
    }
    
    # Remove validating webhooks
    $validatingWebhooks = kubectl get validatingwebhookconfigurations -o name 2>$null | Select-String "consul"
    if ($validatingWebhooks) {
        $validatingWebhooks | ForEach-Object {
            $webhookName = ($_ -split '/')[1]
            Write-Host "      Removing validating webhook: $webhookName" -ForegroundColor Red
            kubectl delete validatingwebhookconfigurations $webhookName 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "        ? Removed $webhookName" -ForegroundColor Green
                $fixed = $true
            }
        }
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan

if ($fixed) {
    Write-Host "Certificate fix completed successfully! ?" -ForegroundColor Green
    Write-Host ""
    Write-Host "You can now run the deployment script:" -ForegroundColor Cyan
    Write-Host "  .\scripts\deploy.ps1" -ForegroundColor White
} else {
    Write-Host "Certificate fix completed - no changes made" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "If deployment issues persist, consider:" -ForegroundColor Cyan
    Write-Host "1. Completely removing Consul if not needed:" -ForegroundColor White
    Write-Host "   kubectl delete namespace consul" -ForegroundColor Gray
    Write-Host "2. Restarting your Kubernetes cluster:" -ForegroundColor White
    Write-Host "   minikube stop && minikube start" -ForegroundColor Gray
    Write-Host "3. Checking cluster logs for more details" -ForegroundColor White
    Write-Host ""
    Write-Host "Try running the deployment script anyway:" -ForegroundColor Cyan
    Write-Host "  .\scripts\deploy.ps1" -ForegroundColor White
}

Write-Host ""