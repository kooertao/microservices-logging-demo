using System.Text.Json;
using OrderService.Middleware;
using OrderService.Services;

var builder = WebApplication.CreateBuilder(args);

// 配置日志 - 仅输出到控制台（JSON 格式）
builder.Logging.ClearProviders();
builder.Logging.AddJsonConsole(options =>
{
    options.IncludeScopes = true;
    options.TimestampFormat = "yyyy-MM-dd HH:mm:ss.fff ";
    options.UseUtcTimestamp = true;
    options.JsonWriterOptions = new JsonWriterOptions
    {
        Indented = false // 单行 JSON，便于解析
    };
});

// 添加服务
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddHttpContextAccessor();
builder.Services.AddSingleton<IOrderBusinessService, OrderBusinessService>();

// 注册 Correlation ID Handler
builder.Services.AddTransient<CorrelationIdDelegatingHandler>();

// 配置 HttpClient for InventoryService
builder.Services.AddHttpClient<IInventoryServiceClient, InventoryServiceClient>(client =>
{
    var inventoryServiceUrl = builder.Configuration.GetValue<string>("InventoryService:BaseUrl") 
                              ?? "http://inventory-service.microservices.svc.cluster.local";
    client.BaseAddress = new Uri(inventoryServiceUrl);
    client.Timeout = TimeSpan.FromSeconds(30);
})
.AddHttpMessageHandler<CorrelationIdDelegatingHandler>()
.SetHandlerLifetime(TimeSpan.FromMinutes(5));

// 添加健康检查
builder.Services.AddHealthChecks();

var app = builder.Build();

// 配置 HTTP 管道
// 启用 Swagger（在所有环境）
app.UseSwagger();
app.UseSwaggerUI();

// 添加 Correlation ID 中间件（第一个）
app.UseMiddleware<CorrelationIdMiddleware>();

app.UseAuthorization();
app.MapControllers();
app.MapHealthChecks("/health");

// 启动日志
app.Logger.LogInformation(
    "OrderService starting up - Environment: {Environment}, Version: {Version}",
    app.Environment.EnvironmentName,
    "1.0.0"
);

app.Run();