# Test Script - Demonstrates Correlation ID and Cross-Service Logging
# This script makes requests to OrderService which then calls InventoryService
# All logs will be traceable via the Correlation ID

param(
    [string]$OrderServiceUrl = "http://localhost:8080"
)

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Microservices Logging Demo - Test Script" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Generate a unique correlation ID for this test
$correlationId = [guid]::NewGuid().ToString()

Write-Host "Test Correlation ID: $correlationId" -ForegroundColor Yellow
Write-Host "Use this ID to search logs in Kibana!" -ForegroundColor Green
Write-Host ""

# Test 1: Create a successful order
Write-Host "[Test 1] Creating a successful order..." -ForegroundColor Cyan

$orderRequest = @{
    customerId = "CUST-$(Get-Random -Minimum 100 -Maximum 999)"
    items = @(
        @{
            productId = "PROD-1"
            productName = "Laptop"
            quantity = 1
            unitPrice = 1299.99
        }
    )
    totalAmount = 1299.99
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "$OrderServiceUrl/api/orders" `
        -Method Post `
        -Headers @{
            "Content-Type" = "application/json"
            "X-Correlation-ID" = $correlationId
        } `
        -Body $orderRequest

    Write-Host "? Order created successfully: $($response.id)" -ForegroundColor Green
    Write-Host "  Status: $($response.status)" -ForegroundColor Gray
    Write-Host "  Customer: $($response.customerId)" -ForegroundColor Gray
    Write-Host ""
} catch {
    Write-Host "? Failed to create order: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
}

Start-Sleep -Seconds 2

# Test 2: Try to create an order with insufficient inventory
Write-Host "[Test 2] Creating order with insufficient inventory..." -ForegroundColor Cyan

$correlationId2 = [guid]::NewGuid().ToString()
Write-Host "Test 2 Correlation ID: $correlationId2" -ForegroundColor Yellow

$orderRequest2 = @{
    customerId = "CUST-$(Get-Random -Minimum 100 -Maximum 999)"
    items = @(
        @{
            productId = "PROD-4"
            productName = "Monitor"
            quantity = 100
            unitPrice = 399.99
        }
    )
    totalAmount = 39999.00
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "$OrderServiceUrl/api/orders" `
        -Method Post `
        -Headers @{
            "Content-Type" = "application/json"
            "X-Correlation-ID" = $correlationId2
        } `
        -Body $orderRequest2 `
        -ErrorAction Stop

    Write-Host "? Order created: $($response.id)" -ForegroundColor Green
} catch {
    Write-Host "? Expected failure - Insufficient inventory" -ForegroundColor Yellow
    Write-Host "  Error: $($_.ErrorDetails.Message)" -ForegroundColor Gray
    Write-Host ""
}

Start-Sleep -Seconds 2

# Test 3: Check inventory directly
Write-Host "[Test 3] Checking inventory directly..." -ForegroundColor Cyan

$correlationId3 = [guid]::NewGuid().ToString()
Write-Host "Test 3 Correlation ID: $correlationId3" -ForegroundColor Yellow

$checkRequest = @{
    productId = "PROD-1"
    quantity = 1
} | ConvertTo-Json

try {
    # Note: This would need InventoryService to be exposed, or we can skip this test
    Write-Host "  (Skipping - InventoryService is internal)" -ForegroundColor Gray
    Write-Host ""
} catch {
    Write-Host "? Failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
}

# Test 4: Get all orders
Write-Host "[Test 4] Retrieving all orders..." -ForegroundColor Cyan

$correlationId4 = [guid]::NewGuid().ToString()

try {
    $response = Invoke-RestMethod -Uri "$OrderServiceUrl/api/orders" `
        -Method Get `
        -Headers @{
            "X-Correlation-ID" = $correlationId4
        }

    Write-Host "? Retrieved $($response.Count) orders" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "? Failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
}

# Summary
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Test Summary" -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Correlation IDs used in this test:" -ForegroundColor Cyan
Write-Host "  Test 1 (Successful Order): $correlationId" -ForegroundColor White
Write-Host "  Test 2 (Insufficient Inv):  $correlationId2" -ForegroundColor White
Write-Host "  Test 4 (Get All Orders):    $correlationId4" -ForegroundColor White
Write-Host ""

Write-Host "To view logs in Kibana:" -ForegroundColor Yellow
Write-Host "1. Navigate to Discover" -ForegroundColor White
Write-Host "2. Search for: CorrelationId:`"$correlationId`"" -ForegroundColor White
Write-Host "3. You'll see logs from both OrderService AND InventoryService!" -ForegroundColor Green
Write-Host ""

Write-Host "Example Kibana queries:" -ForegroundColor Cyan
Write-Host "  - All logs for Test 1: CorrelationId:`"$correlationId`"" -ForegroundColor Gray
Write-Host "  - Only OrderService:   CorrelationId:`"$correlationId`" AND k8s_labels.app:`"order-service`"" -ForegroundColor Gray
Write-Host "  - Only InventoryService: CorrelationId:`"$correlationId`" AND k8s_labels.app:`"inventory-service`"" -ForegroundColor Gray
Write-Host "  - Errors only:         CorrelationId:`"$correlationId`" AND Level:`"Error`"" -ForegroundColor Gray
Write-Host ""

Write-Host "Key Observations:" -ForegroundColor Yellow
Write-Host "  ? Same CorrelationId flows through OrderService ? InventoryService" -ForegroundColor Green
Write-Host "  ? All logs are structured (JSON) with consistent fields" -ForegroundColor Green
Write-Host "  ? Duration metrics show service latency" -ForegroundColor Green
Write-Host "  ? Errors include stack traces and context" -ForegroundColor Green
Write-Host ""
