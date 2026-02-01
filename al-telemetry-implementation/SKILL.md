---
name: implementing-telemetry
description: Logs custom events to Application Insights using Feature Telemetry or Session.LogMessage, tracks feature adoption with LogUptake, and queries telemetry data with KQL. Use when instrumenting BC extensions, debugging production issues, monitoring API integrations, or tracking feature usage.
license: MIT
metadata:
  version: 1.0.0
---

# Skill: AL Telemetry Implementation

## Validation Gates

1. **After Step 3**: Telemetry Logger registered (check `OnRegisterTelemetryLogger` fires)
2. **After Step 5**: Events appear in Application Insights within 5 minutes
3. **Final**: KQL query returns your custom eventIds with correct dimensions

## Key Concept

**EventId prefix:** Platform adds `AL` automatically → Code: `APP-0001` → App Insights: `ALAPP-0001`

## Procedure

### Step 1: Configure Application Insights

**In app.json:**
```json
{
  "applicationInsightsConnectionString": "InstrumentationKey=xxx;IngestionEndpoint=https://xxx.applicationinsights.azure.com/;..."
}
```

Get connection string from: Azure Portal → Application Insights → Overview → Connection String

### Step 2: Choose Telemetry Method

| Method | When to Use |
|--------|-------------|
| **Feature Telemetry** (Recommended) | Standard logging with auto dimensions, uptake tracking |
| **Session.LogMessage** | Direct control, no duplicates, simple scenarios |

### Step 3: Create Telemetry Logger (Required for Feature Telemetry)

**CRITICAL:** Exactly ONE per publisher!

```al
codeunit <ID> "<PREFIX> Telemetry Logger" implements "Telemetry Logger"
{
    Access = Internal;

    procedure LogMessage(
        EventId: Text;
        Message: Text;
        Verbosity: Verbosity;
        DataClassification: DataClassification;
        TelemetryScope: TelemetryScope;
        CustomDimensions: Dictionary of [Text, Text])
    begin
        Session.LogMessage(EventId, Message, Verbosity, DataClassification,
            TelemetryScope, CustomDimensions);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Telemetry Loggers",
        'OnRegisterTelemetryLogger', '', true, true)]
    local procedure OnRegisterTelemetryLogger(var Sender: Codeunit "Telemetry Loggers")
    var
        TelemetryLogger: Codeunit "<PREFIX> Telemetry Logger";
    begin
        Sender.Register(TelemetryLogger);
    end;
}
```

### Step 4: Define EventId Convention

**Format:** `<PREFIX>-<NNNN>` (with hyphen to distinguish from BC standard)

**Organization by Range:**

| Range | Area | Convention |
|-------|------|------------|
| 00xx | Area 1 (e.g., API to System A) | Even = success, Odd = error |
| 01xx | Area 2 (e.g., API to System B) | Even = success, Odd = error |
| 02xx | Authentication | Even = success, Odd = error |
| 09xx | Fallback/Generic | For unmapped operations |

**Example Registry:**

| EventId | Operation | Result |
|---------|-----------|--------|
| `APP-0001` | SendOrder | Success |
| `APP-0002` | SendOrder | Error |
| `APP-0003` | SendLine | Success |
| `APP-0004` | SendLine | Error |

### Step 5: Implement Logging

#### Using Feature Telemetry (Recommended)

```al
var
    FeatureTelemetry: Codeunit "Feature Telemetry";
    CustomDimensions: Dictionary of [Text, Text];
begin
    // Replace <Record> and field names with your source record
    CustomDimensions.Add('<KeyFieldName>', <Record>."<KeyField>");
    CustomDimensions.Add('<RelatedFieldName>', <Record>."<RelatedField>");

    FeatureTelemetry.LogUsage('<PREFIX>-0001', '<FeatureName>', '<OperationDescription>', CustomDimensions);

    FeatureTelemetry.LogError('<PREFIX>-0002', '<FeatureName>', '<OperationDescription>',
        GetLastErrorText(), GetLastErrorCallStack(), CustomDimensions);

    FeatureTelemetry.LogUptake('<PREFIX>-0010', '<FeatureName>',
        Enum::"Feature Uptake Status"::Used);
end;
```

#### Using Session.LogMessage (Direct)

```al
var
    CustomDimensions: Dictionary of [Text, Text];
begin
    // Replace <Record> and field names with your source record
    CustomDimensions.Add('<KeyFieldName>', <Record>."<KeyField>");
    CustomDimensions.Add('Operation', '<OperationName>');

    Session.LogMessage('<PREFIX>-0001', '<LogMessage>', Verbosity::Normal,
        DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
end;
```

### Step 6: Hybrid Logging (Telemetry + Local Table)

For API integrations, use both:
1. **Telemetry**: Synthetic data for monitoring/alerts
2. **Local Table**: Complete JSON for debugging

See BC-Telemetry-Guide.md Section 14 for complete implementation.

### Step 7: Query in Application Insights

**Basic KQL Query:**

```kql
traces
| where timestamp > ago(24h)
| where customDimensions.eventId startswith "AL<PREFIX>-"
| project
    timestamp,
    eventId = tostring(customDimensions.eventId),
    message,
    customDimensions
| order by timestamp desc
```

**Note:** Remember the `AL` prefix rule from Key Concept when searching in App Insights.

## Important Notes

**DataClassification:** ALWAYS use `SystemMetadata` - other values won't be sent!

**TelemetryScope:** `ExtensionPublisher` = only your App Insights | `All` = yours AND customer's

**Multi-App:** ONE Telemetry Logger per publisher. Distinguish apps via `alCallerAppName` dimension.

## Job Queue and Scheduled Task Telemetry

Job Queue entries trigger Scheduled Tasks at platform level. Key event IDs:
- **Job Queue (AL):** `AL0000E24` (Enqueued), `AL0000E25` (Started), `AL0000E26` (Success), `AL0000HE7` (Failure)
- **Scheduled Task (LC):** `LC0040`-`LC0045`, `LC0057` (Created → Failed → Timeout)

Correlate via `alScheduledTaskId` dimension in `AL0000E24`.

See `references/job-queue-telemetry.md` for complete event tables and KQL queries.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Events not appearing | Check `applicationInsightsConnectionString` in app.json |
| Wrong eventId in App Insights | Remember: platform adds `AL` prefix automatically |
| DataClassification error | MUST use `SystemMetadata` - other values won't send |
| Duplicate events | Feature Telemetry creates 2 by design - de-duplicate in KQL |

**Feedback loop:** Fix configuration → Re-deploy → Wait 5 minutes → Re-check in App Insights.

## References

See `references/` folder for:
- `kql-queries.md` - Common KQL queries
- `job-queue-telemetry.md` - Job Queue and Scheduled Task monitoring

## External Documentation

**BC Telemetry:**

- [Microsoft: Telemetry Overview](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/telemetry-overview)
- [Microsoft: Telemetry Event IDs](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/telemetry-event-ids)
- [Microsoft: Feature Telemetry](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/telemetry-feature-telemetry)
- [Microsoft: Custom Telemetry Events](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-instrument-application-for-telemetry-app-insights)
- [Microsoft: Task Scheduler](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-task-scheduler)
- [BCTech Samples & KQL Queries](https://github.com/microsoft/BCTech/tree/master/samples/AppInsights)

**KQL Learning:**

- [MustLearnKQL](https://github.com/rod-trent/MustLearnKQL) - 21-part KQL tutorial series (Sentinel-focused but KQL syntax is universal)
