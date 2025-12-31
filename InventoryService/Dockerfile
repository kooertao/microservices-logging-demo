FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS base
USER $APP_UID
WORKDIR /app
EXPOSE 8080
EXPOSE 8081

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
ARG BUILD_CONFIGURATION=Release
WORKDIR /src

# Add JCI root cert
COPY ["OrderService/GO JCI Root CA 1.crt", "/usr/local/share/ca-certificates/"]
RUN update-ca-certificates

COPY ["InventoryService/InventoryService.csproj", "InventoryService/"]
RUN dotnet restore "./InventoryService/InventoryService.csproj"
COPY . .
WORKDIR "/src/InventoryService"
RUN dotnet build "./InventoryService.csproj" -c $BUILD_CONFIGURATION -o /app/build

FROM build AS publish
ARG BUILD_CONFIGURATION=Release
RUN dotnet publish "./InventoryService.csproj" -c $BUILD_CONFIGURATION -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "InventoryService.dll"]
