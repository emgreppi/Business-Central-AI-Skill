# Azure Functions Code Examples

## Complete Azure Function (Isolated Worker - .NET 8)

### Project Structure

```
MyFunctionApp/
├── Program.cs
├── MyFunction.cs
├── host.json
├── local.settings.json
└── MyFunctionApp.csproj
```

### MyFunctionApp.csproj

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <AzureFunctionsVersion>v4</AzureFunctionsVersion>
    <OutputType>Exe</OutputType>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.Azure.Functions.Worker" Version="1.21.0" />
    <PackageReference Include="Microsoft.Azure.Functions.Worker.Sdk" Version="1.17.2" />
    <PackageReference Include="Microsoft.Azure.Functions.Worker.Extensions.Http" Version="3.1.0" />
    <PackageReference Include="Microsoft.ApplicationInsights.WorkerService" Version="2.22.0" />
    <PackageReference Include="Microsoft.Azure.Functions.Worker.ApplicationInsights" Version="1.2.0" />
    <!-- Add your third-party packages here -->
    <PackageReference Include="QRCoder" Version="1.7.0" />
  </ItemGroup>
</Project>
```

### Program.cs

```csharp
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

var host = new HostBuilder()
    .ConfigureFunctionsWorkerDefaults()
    .ConfigureServices(services => {
        // Add Application Insights for unified telemetry with BC
        services.AddApplicationInsightsTelemetryWorkerService();
        services.ConfigureFunctionsApplicationInsights();
    })
    .Build();

host.Run();
```

### host.json

```json
{
  "version": "2.0",
  "logging": {
    "applicationInsights": {
      "samplingSettings": {
        "isEnabled": true,
        "excludedTypes": "Request"
      },
      "enableLiveMetricsFilters": true
    }
  }
}
```

### local.settings.json

```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
    "APPLICATIONINSIGHTS_CONNECTION_STRING": "InstrumentationKey=xxx;..."
  }
}
```

### MyFunction.cs (QR Code Generator Example)

```csharp
using System.Net;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using QRCoder;
using System.Text.Json;

namespace MyFunctionApp;

public class QRCodeGenerator
{
    private readonly ILogger _logger;

    public QRCodeGenerator(ILoggerFactory loggerFactory)
    {
        _logger = loggerFactory.CreateLogger<QRCodeGenerator>();
    }

    [Function("GenerateQRCode")]
    public async Task<HttpResponseData> Run(
        [HttpTrigger(AuthorizationLevel.Function, "post")] HttpRequestData req)
    {
        _logger.LogInformation("QR Code generation request received");

        // Parse request body
        var requestBody = await req.ReadAsStringAsync();
        var data = JsonSerializer.Deserialize<QRCodeRequest>(requestBody);

        if (string.IsNullOrEmpty(data?.Content))
        {
            var badResponse = req.CreateResponse(HttpStatusCode.BadRequest);
            await badResponse.WriteStringAsync("Content is required");
            return badResponse;
        }

        // Validate URL if provided
        if (!string.IsNullOrEmpty(data.Content) &&
            !Uri.TryCreate(data.Content, UriKind.Absolute, out _))
        {
            // Allow non-URL content too
            _logger.LogInformation("Generating QR for non-URL content");
        }

        // Generate QR Code
        using var qrGenerator = new QRCodeGenerator();
        var qrCodeData = qrGenerator.CreateQrCode(
            data.Content,
            QRCodeGenerator.ECCLevel.Q
        );
        var qrCode = new PngByteQRCode(qrCodeData);
        var qrCodeImage = qrCode.GetGraphic(20);

        // Return image
        var response = req.CreateResponse(HttpStatusCode.OK);
        response.Headers.Add("Content-Type", "image/png");
        await response.Body.WriteAsync(qrCodeImage);

        _logger.LogInformation("QR Code generated successfully");
        return response;
    }
}

public class QRCodeRequest
{
    public string? Content { get; set; }
}
```

---

## AL Code to Call Azure Function

### Setup Table

```al
table 50100 "Azure Function Setup"
{
    Caption = 'Azure Function Setup';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
        }
        field(10; "Function URL"; Text[250])
        {
            Caption = 'Function URL';
        }
        field(11; "Has Function Key"; Boolean)
        {
            Caption = 'Has Function Key';
            FieldClass = FlowField;
            CalcFormula = exist("Isolated Storage Entry" where("Key" = const('AzureFunctionKey')));
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    procedure SetFunctionKey(FunctionKey: SecretText)
    begin
        if FunctionKey.IsEmpty() then begin
            if IsolatedStorage.Contains('AzureFunctionKey', DataScope::Company) then
                IsolatedStorage.Delete('AzureFunctionKey', DataScope::Company);
        end else
            IsolatedStorage.Set('AzureFunctionKey', FunctionKey, DataScope::Company);
    end;

    procedure GetFunctionKey(): SecretText
    var
        FunctionKey: SecretText;
    begin
        if IsolatedStorage.Get('AzureFunctionKey', DataScope::Company, FunctionKey) then
            exit(FunctionKey);
        exit('');
    end;
}
```

### Caller Codeunit

```al
codeunit 50100 "Azure Function Mgt"
{
    procedure GenerateQRCode(Content: Text; var TempBlob: Codeunit "Temp Blob"): Boolean
    var
        Setup: Record "Azure Function Setup";
        AzureFunction: Codeunit "Azure Functions";
        AzureFunctionResponse: Codeunit "Azure Functions Response";
        AzureFunctionAuth: Codeunit "Azure Functions Authentication";
        IAzureFunctionAuth: Interface "Azure Functions Authentication";
        RequestBody: Text;
        ResultInStream: InStream;
        OutStr: OutStream;
    begin
        Setup.Get();
        if Setup."Function URL" = '' then
            Error('Azure Function URL not configured');

        IAzureFunctionAuth := AzureFunctionAuth.CreateCodeAuth(
            Setup."Function URL",
            Setup.GetFunctionKey()
        );

        RequestBody := '{"content": "' + EscapeJson(Content) + '"}';

        AzureFunctionResponse := AzureFunction.SendPostRequest(
            IAzureFunctionAuth,
            RequestBody,
            'application/json'
        );

        if not AzureFunctionResponse.IsSuccessful() then begin
            LogError(AzureFunctionResponse.GetError());
            exit(false);
        end;

        AzureFunctionResponse.GetResultAsStream(ResultInStream);
        TempBlob.CreateOutStream(OutStr);
        CopyStream(OutStr, ResultInStream);

        exit(true);
    end;

    local procedure EscapeJson(Input: Text): Text
    begin
        Input := Input.Replace('\', '\\');
        Input := Input.Replace('"', '\"');
        exit(Input);
    end;

    local procedure LogError(ErrorText: Text)
    var
        FeatureTelemetry: Codeunit "Feature Telemetry";
        CustomDimensions: Dictionary of [Text, Text];
    begin
        CustomDimensions.Add('ErrorText', ErrorText);
        FeatureTelemetry.LogError(
            'Azure Function',
            'Azure Integration',
            'AzureFunctionCallFailed',
            ErrorText,
            CustomDimensions
        );
    end;
}
```

### Page Extension with QR Action

```al
pageextension 50100 "Customer Card Ext" extends "Customer Card"
{
    actions
    {
        addlast(processing)
        {
            action(GenerateQRCode)
            {
                ApplicationArea = All;
                Caption = 'Generate QR Code';
                Image = BarCode;
                ToolTip = 'Generate a QR code for this customer''s website';

                trigger OnAction()
                var
                    AzureFunctionMgt: Codeunit "Azure Function Mgt";
                    TempBlob: Codeunit "Temp Blob";
                    InStr: InStream;
                    FileName: Text;
                begin
                    if Rec."Home Page" = '' then
                        Error('Customer does not have a Home Page configured');

                    if not AzureFunctionMgt.GenerateQRCode(Rec."Home Page", TempBlob) then
                        Error('Failed to generate QR Code');

                    TempBlob.CreateInStream(InStr);
                    FileName := Rec."No." + '_QRCode.png';
                    DownloadFromStream(InStr, 'Download QR Code', '', 'PNG Files (*.png)|*.png', FileName);
                end;
            }
        }
        addlast(Promoted)
        {
            actionref(GenerateQRCodeRef; GenerateQRCode) { }
        }
    }
}
```

---

## Other Common Azure Function Examples

### PDF Generation Function

```csharp
[Function("GeneratePDF")]
public async Task<HttpResponseData> GeneratePdf(
    [HttpTrigger(AuthorizationLevel.Function, "post")] HttpRequestData req)
{
    var data = await req.ReadFromJsonAsync<PdfRequest>();

    // Use a library like iTextSharp, PdfSharp, or QuestPDF
    var pdfBytes = GeneratePdfDocument(data);

    var response = req.CreateResponse(HttpStatusCode.OK);
    response.Headers.Add("Content-Type", "application/pdf");
    await response.Body.WriteAsync(pdfBytes);
    return response;
}
```

### Data Transformation Function

```csharp
[Function("TransformData")]
public async Task<HttpResponseData> Transform(
    [HttpTrigger(AuthorizationLevel.Function, "post")] HttpRequestData req)
{
    var input = await req.ReadFromJsonAsync<TransformRequest>();

    // Complex transformation logic that would be slow in AL
    var result = PerformComplexTransformation(input);

    var response = req.CreateResponse(HttpStatusCode.OK);
    await response.WriteAsJsonAsync(result);
    return response;
}
```

### Timer-Triggered Cleanup Function

```csharp
[Function("DailyCleanup")]
public void RunCleanup([TimerTrigger("0 0 2 * * *")] TimerInfo timer)
{
    _logger.LogInformation($"Cleanup function executed at: {DateTime.Now}");

    // Call BC API to perform cleanup
    // Or process external data
}
```

---

## Deployment

### From Visual Studio Code

1. Install Azure Functions extension
2. Sign in to Azure
3. Open Command Palette: `Azure Functions: Deploy to Function App...`
4. Select subscription and Function App

### From CLI

```bash
# Build
dotnet build --configuration Release

# Publish
func azure functionapp publish <FunctionAppName>
```

### GitHub Actions (CI/CD)

```yaml
name: Deploy Azure Function

on:
  push:
    branches: [main]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x'

      - name: Build
        run: dotnet build --configuration Release

      - name: Publish
        run: dotnet publish -c Release -o ./publish

      - name: Deploy to Azure
        uses: Azure/functions-action@v1
        with:
          app-name: ${{ env.AZURE_FUNCTIONAPP_NAME }}
          package: './publish'
          publish-profile: ${{ secrets.AZURE_FUNCTIONAPP_PUBLISH_PROFILE }}
```
