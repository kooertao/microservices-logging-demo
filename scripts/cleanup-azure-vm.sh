#!/bin/bash

# Azure VM ???? - Bash ??

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

RESOURCE_GROUP="${1:-}"
FORCE="${2:-}"

if [ -z "$RESOURCE_GROUP" ]; then
    echo -e "${RED}? Error: Resource group name is required${NC}"
    echo ""
    echo "Usage: $0 <resource-group-name> [--force]"
    echo ""
    echo "Example:"
    echo "  $0 microservices-logging-rg"
    echo "  $0 microservices-logging-rg --force"
    exit 1
fi

echo -e "${YELLOW}???  Azure Resource Cleanup Script${NC}"
echo ""

# ?????????
RG_EXISTS=$(az group exists --name "$RESOURCE_GROUP")

if [ "$RG_EXISTS" = "false" ]; then
    echo -e "${RED}? Resource group '$RESOURCE_GROUP' does not exist.${NC}"
    exit 1
fi

# ???????????
echo -e "${CYAN}?? Resources in '$RESOURCE_GROUP':${NC}"
az resource list --resource-group "$RESOURCE_GROUP" --output table
echo ""

# ????
if [ "$FORCE" != "--force" ]; then
    echo -e "${RED}??  WARNING: This will DELETE ALL resources in the resource group!${NC}"
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " confirmation
    
    if [ "$confirmation" != "yes" ]; then
        echo -e "${YELLOW}? Cleanup cancelled.${NC}"
        exit 0
    fi
fi

echo ""
echo -e "${YELLOW}???  Deleting resource group '$RESOURCE_GROUP'...${NC}"
echo -e "   ${NC}This may take several minutes...${NC}"

# ?????
az group delete --name "$RESOURCE_GROUP" --yes --no-wait

echo ""
echo -e "${GREEN}? Deletion initiated. Resources are being deleted in the background.${NC}"
echo ""
echo -e "${CYAN}?? To check deletion status, run:${NC}"
echo "   az group show --name $RESOURCE_GROUP"
echo ""
echo -e "   ${NC}If the resource group still exists, wait a few minutes and try again.${NC}"
echo ""
