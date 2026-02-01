---
name: integrating-azure-services
description: Calls Azure Functions from AL using Codeunit "Azure Functions" for serverless .NET execution, and orchestrates Logic Apps workflows triggered by BC business events. Use when generating QR codes or PDFs externally, running .NET libraries unavailable in AL, building file processing workflows, or automating BC-to-external-system data sync.
license: MIT
metadata:
  version: 1.0.0
---

# Skill: AL Azure Integration

## Validation Gates

1. **After Step 2**: Azure Function responds to HTTP request from Postman
2. **After Step 3**: AL code successfully calls function, receives response
3. **Final**: Logic App triggers on BC event, performs expected action

**Note:** In-process model deprecated Nov 2026. Use Isolated Worker (.NET 8+).

## Procedure

### Step 1: Create Azure Function (Isolated Worker)

```csharp
// Program.cs
var host = new HostBuilder()
    .ConfigureFunctionsWorkerDefaults()
    .Build();
host.Run();

// MyFunction.cs
[Function("MyFunction")]
public async Task<HttpResponseData> Run(
    [HttpTrigger(AuthorizationLevel.Function, "post")] HttpRequestData req)
{
    var response = req.CreateResponse(HttpStatusCode.OK);
    await response.WriteStringAsync("Result");
    return response;
}
```

**Required in `.csproj`:** `<TargetFramework>net8.0</TargetFramework>` + `<OutputType>Exe</OutputType>`

### Step 2: Deploy and Get Function URL

1. Deploy to Azure (VS Code / CLI / GitHub Actions)
2. Copy Function URL + Key from Azure Portal → Function App → Functions → Get Function Url

### Step 3: Call Function from AL

```al
procedure CallAzureFunction(InputData: Text): Text
var
    AzureFunction: Codeunit "Azure Functions";
    AzureFunctionResponse: Codeunit "Azure Functions Response";
    AzureFunctionAuth: Codeunit "Azure Functions Authentication";
    IAzureFunctionAuth: Interface "Azure Functions Authentication";
    ResponseText: Text;
begin
    IAzureFunctionAuth := AzureFunctionAuth.CreateCodeAuth(GetFunctionUrl(), GetFunctionKey());

    AzureFunctionResponse := AzureFunction.SendPostRequest(
        IAzureFunctionAuth,
        '{"data": "' + InputData + '"}',
        'application/json');

    if AzureFunctionResponse.IsSuccessful() then
        AzureFunctionResponse.GetResultAsText(ResponseText)
    else
        Error('Azure Function failed: %1', AzureFunctionResponse.GetError());

    exit(ResponseText);
end;

local procedure GetFunctionKey(): Text
var
    FunctionKey: Text;
begin
    if IsolatedStorage.Get('AzureFunctionKey', DataScope::Company, FunctionKey) then
        exit(FunctionKey);
    Error('Azure Function key not configured');
end;
```

### Step 4: Create Logic App (Optional)

**Common triggers:**
- `When a Business Event occurs` → React to BC events
- `Recurrence` → Scheduled data sync
- `When file added to SharePoint` → File processing

**BC Connector (GA 2024):** Use Managed Identity for auth. Enable Run History for debugging.

## Authentication Options

| Method | Code | Use Case |
|--------|------|----------|
| Function Key | `CreateCodeAuth(url, key)` | Simple scenarios |
| Azure AD | `CreateOAuth2(url, ...)` | Enterprise |
| Managed Identity | Via Azure AD | Logic Apps |

## Binary Response (Images/PDFs)

```al
if AzureFunctionResponse.IsSuccessful() then begin
    AzureFunctionResponse.GetResultAsStream(ResultInStream);
    DownloadFromStream(ResultInStream, 'Download', '', '', FileName);
end;
```

## Hosting Plans

| Plan | Cold Start | Best For |
|------|------------|----------|
| Consumption | Yes | Sporadic |
| Flex Consumption | Optional | Production |
| Premium | No | High-frequency |

## Important Notes

**Security:** Never hardcode function keys → Isolated Storage. Use Azure AD for production.

**Telemetry:** Add to `Program.cs` for unified BC + Functions monitoring:
```csharp
.ConfigureServices(services => {
    services.AddApplicationInsightsTelemetryWorkerService();
})
```

## References

See `references/` folder for:
- `azure-functions-patterns.md` - Complete .NET examples

## External Documentation

- [Azure Functions Overview](https://learn.microsoft.com/en-us/azure/azure-functions/functions-overview)
- [Migrate to Isolated Worker](https://learn.microsoft.com/en-us/azure/azure-functions/migrate-dotnet-to-isolated-model)
- [BC Integration with Azure](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/integration-azure-overview)
