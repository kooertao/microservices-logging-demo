# Microservices Logging Demo - Kibana ????
# PowerShell ??

Write-Host "?? Setting up Kibana Index Pattern and Dashboard" -ForegroundColor Blue
Write-Host ""

$KibanaUrl = if ($env:KIBANA_URL) { $env:KIBANA_URL } else { "http://localhost:5601" }
$EsUrl = if ($env:ES_URL) { $env:ES_URL } else { "http://localhost:9200" }

# ?? Kibana ??
Write-Host "Waiting for Kibana to be ready..." -ForegroundColor Green
$maxRetries = 60
$retryCount = 0
$kibanaReady = $false

while (-not $kibanaReady -and $retryCount -lt $maxRetries) {
    try {
        $response = Invoke-WebRequest -Uri "$KibanaUrl/api/status" -UseBasicParsing -ErrorAction SilentlyContinue
        if ($response.Content -match "available") {
            $kibanaReady = $true
        }
    } catch {
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 2
        $retryCount++
    }
}

if ($kibanaReady) {
    Write-Host ""
    Write-Host "? Kibana is ready!" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "? Kibana is not ready after $maxRetries attempts" -ForegroundColor Red
    Write-Host "Please check if Kibana is running: kubectl get pods -n logging"
    exit 1
}

# ??????
Write-Host "Creating index pattern..." -ForegroundColor Green
try {
    $body = @{
        attributes = @{
            title = "logs-microservices-*"
            timeFieldName = "@timestamp"
        }
    } | ConvertTo-Json -Depth 10

    $headers = @{
        "kbn-xsrf" = "true"
        "Content-Type" = "application/json"
    }

    $response = Invoke-RestMethod -Uri "$KibanaUrl/api/saved_objects/index-pattern/logs-microservices" -Method Post -Body $body -Headers $headers
    $response | ConvertTo-Json -Depth 10 | Write-Host
    Write-Host ""
    Write-Host "? Index pattern created!" -ForegroundColor Green
} catch {
    if ($_.Exception.Response.StatusCode -eq 409) {
        Write-Host "Index pattern already exists" -ForegroundColor Yellow
    } else {
        Write-Host "Error creating index pattern: $_" -ForegroundColor Red
        Write-Host $_.ErrorDetails.Message
    }
}
Write-Host ""

# ????????
Write-Host "Setting default index pattern..." -ForegroundColor Green
try {
    $body = @{
        value = "logs-microservices"
    } | ConvertTo-Json

    $headers = @{
        "kbn-xsrf" = "true"
        "Content-Type" = "application/json"
    }

    $response = Invoke-RestMethod -Uri "$KibanaUrl/api/kibana/settings/defaultIndex" -Method Post -Body $body -Headers $headers
    $response | ConvertTo-Json | Write-Host
} catch {
    Write-Host "Note: Could not set default index pattern (this is optional)" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "? Setup completed!" -ForegroundColor Green
Write-Host ""
Write-Host "Useful Kibana features to explore:"
Write-Host "  1. Discover: View and search logs"
Write-Host "  2. Create visualizations: Pie charts, line graphs, etc."
Write-Host "  3. Create dashboards: Combine multiple visualizations"
Write-Host ""
Write-Host "Useful search queries in Kibana:"
Write-Host '  - k8s_namespace_name: "microservices"'
Write-Host '  - k8s_pod_name: "order-service*"'
Write-Host '  - log.level: "Error"'
Write-Host '  - k8s_labels_app: "order-service"'
Write-Host ""
Write-Host "Access Kibana at: $KibanaUrl"
