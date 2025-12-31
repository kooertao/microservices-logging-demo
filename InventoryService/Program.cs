using System.Text.Json;
using InventoryService.Middleware;
using InventoryService.Services;

var builder = WebApplication.CreateBuilder(args);

// ???? - ????????JSON ???
builder.Logging.ClearProviders();
builder.Logging.AddJsonConsole(options =>
{
    options.IncludeScopes = true;
    options.TimestampFormat = "yyyy-MM-dd HH:mm:ss.fff ";
    options.UseUtcTimestamp = true;
    options.JsonWriterOptions = new JsonWriterOptions
    {
        Indented = false // ?? JSON?????
    };
});

// ????
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddHttpContextAccessor();
builder.Services.AddSingleton<IInventoryBusinessService, InventoryBusinessService>();

// ??????
builder.Services.AddHealthChecks();

var app = builder.Build();

// ?? HTTP ??
// ?? Swagger???????
app.UseSwagger();
app.UseSwaggerUI();

// ?? Correlation ID ????????
app.UseMiddleware<CorrelationIdMiddleware>();

app.UseAuthorization();
app.MapControllers();
app.MapHealthChecks("/health");

// ????
app.Logger.LogInformation(
    "InventoryService starting up - Environment: {Environment}, Version: {Version}",
    app.Environment.EnvironmentName,
    "1.0.0"
);

app.Run();
