var builder = WebApplication.CreateBuilder(args);

// Todos live in the todo-store service; this app serves the UI and forwards /api/todos calls.
// Plain HTTP on purpose so Beyla can propagate trace context between the two services.
var storeUrl = builder.Configuration["TODO_STORE_URL"] ?? "http://todo-store";
builder.Services.AddHttpClient("todo-store", c => c.BaseAddress = new Uri(storeUrl));
// Created todos are also sent to todo-notification-hub, with the same payload as for todo-store
var hubUrl = builder.Configuration["TODO_NOTIFICATION_HUB_URL"] ?? "http://todo-notification-hub";
builder.Services.AddHttpClient("todo-notification-hub", c => c.BaseAddress = new Uri(hubUrl));
var app = builder.Build();

// Serves wwwroot/index.html at "/"
app.UseDefaultFiles();
app.UseStaticFiles();

app.MapGet("/api/todos", (HttpContext ctx, IHttpClientFactory http) =>
    Forward(ctx, http, HttpMethod.Get, "/api/todos"));

app.MapGet("/api/todos/{id:int}", (int id, HttpContext ctx, IHttpClientFactory http) =>
    Forward(ctx, http, HttpMethod.Get, $"/api/todos/{id}"));

app.MapPost("/api/todos", async (HttpContext ctx, IHttpClientFactory http, ILogger<Program> logger) =>
{
    // Read the body once so the same payload can be sent to both todo-store and todo-notification-hub
    using var body = new MemoryStream();
    await ctx.Request.Body.CopyToAsync(body, ctx.RequestAborted);
    var payload = body.ToArray();
    body.Position = 0;
    ctx.Request.Body = body;

    await Forward(ctx, http, HttpMethod.Post, "/api/todos");
    if (ctx.Response.StatusCode is StatusCodes.Status201Created)
        await Notify(ctx, http, logger, payload);
});

app.MapPut("/api/todos/{id:int}", (int id, HttpContext ctx, IHttpClientFactory http) =>
    Forward(ctx, http, HttpMethod.Put, $"/api/todos/{id}"));

app.MapDelete("/api/todos/{id:int}", (int id, HttpContext ctx, IHttpClientFactory http) =>
    Forward(ctx, http, HttpMethod.Delete, $"/api/todos/{id}"));

// Liveness / readiness probes for Kubernetes (local only, does not call todo-store)
app.MapGet("/healthz", () => Results.Ok("healthy"));

app.Run();

// Sends the create payload to todo-notification-hub. A hub failure is only logged, the todo is already created.
static async Task Notify(HttpContext ctx, IHttpClientFactory http, ILogger logger, byte[] payload)
{
    using var request = new HttpRequestMessage(HttpMethod.Post, "/api/notifications");
    request.Content = new ByteArrayContent(payload);
    if (ctx.Request.ContentType is { } contentType)
        request.Content.Headers.TryAddWithoutValidation("Content-Type", contentType);
    try
    {
        using var response = await http.CreateClient("todo-notification-hub").SendAsync(request, ctx.RequestAborted);
        if (!response.IsSuccessStatusCode)
            logger.LogWarning("todo-notification-hub returned {StatusCode}", (int)response.StatusCode);
    }
    catch (HttpRequestException ex)
    {
        logger.LogWarning("todo-notification-hub unavailable: {Message}", ex.Message);
    }
}

// Relays the incoming request body to todo-store and copies status, content type and body back.
static async Task Forward(HttpContext ctx, IHttpClientFactory http, HttpMethod method, string path)
{
    using var request = new HttpRequestMessage(method, path);
    if (method == HttpMethod.Post || method == HttpMethod.Put)
    {
        request.Content = new StreamContent(ctx.Request.Body);
        if (ctx.Request.ContentType is { } contentType)
            request.Content.Headers.TryAddWithoutValidation("Content-Type", contentType);
    }

    HttpResponseMessage response;
    try
    {
        response = await http.CreateClient("todo-store").SendAsync(request, ctx.RequestAborted);
    }
    catch (HttpRequestException ex)
    {
        ctx.Response.StatusCode = StatusCodes.Status502BadGateway;
        await ctx.Response.WriteAsync($"todo-store unavailable: {ex.Message}");
        return;
    }

    using (response)
    {
        ctx.Response.StatusCode = (int)response.StatusCode;
        // 204 / 304 must not carry a body; Kestrel throws if we write one
        if (ctx.Response.StatusCode is StatusCodes.Status204NoContent or StatusCodes.Status304NotModified)
            return;
        if (response.Content.Headers.ContentType is { } responseType)
            ctx.Response.ContentType = responseType.ToString();
        await response.Content.CopyToAsync(ctx.Response.Body);
    }
}
