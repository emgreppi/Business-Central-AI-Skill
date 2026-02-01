# KQL Queries for Business Central Telemetry

## KQL Language Basics

KQL (Kusto Query Language) is case-sensitive and similar to T-SQL. Statements are separated by pipe (`|`).

### Key Statements

| Statement | Purpose | Example |
|-----------|---------|---------|
| `let` | Define variable/constant | `let days = 7;` |
| `traces` | Tabular statement (table name) | `traces \| where ...` |

### Key Operators

| Operator | Purpose | Example |
|----------|---------|---------|
| `where` | Filter rows | `where timestamp > ago(24h)` |
| `extend` | Add calculated columns | `extend duration = toint(customDimensions.alDurationMs)` |
| `summarize` | Aggregate data | `summarize count() by eventId` |
| `project` | Select columns to output | `project timestamp, eventId, message` |
| `project-away` | Exclude columns | `project-away customDimensions` |
| `order by` / `sort by` | Sort results | `order by timestamp desc` |

### Key Functions

| Function | Purpose | Example |
|----------|---------|---------|
| `ago(timespan)` | Time relative to now | `ago(24h)`, `ago(7d)` |
| `tostring(value)` | Convert to string | `tostring(customDimensions.eventId)` |
| `toint(value)` | Convert to integer | `toint(customDimensions.alDurationMs)` |
| `toreal(value)` | Convert to decimal | `toreal(totimespan(customDimensions.serverExecutionTime))` |
| `count()` | Count rows | `summarize count()` |
| `countif(predicate)` | Conditional count | `countif(isError)` |
| `avg()`, `min()`, `max()` | Aggregations | `avg(duration)` |
| `percentile(col, n)` | Percentile calculation | `percentile(duration, 95)` |
| `bin(col, size)` | Group into buckets | `bin(timestamp, 1h)` |

### Application Insights Tables

| Table | Content |
|-------|---------|
| `traces` | All telemetry signals (except page views) |
| `pageViews` | Page open events |

---

## Basic Queries

### All Custom Events (Last 24h)

```kql
traces
| where timestamp > ago(24h)
| where customDimensions.eventId startswith "AL<PREFIX>-"
| project
    timestamp,
    eventId = tostring(customDimensions.eventId),
    subCategory = tostring(customDimensions.alSubCategory),
    featureName = tostring(customDimensions.alFeatureName),
    message,
    environmentName = tostring(customDimensions.environmentName),
    companyName = tostring(customDimensions.alCompany)
| order by timestamp desc
```

### Only Errors

```kql
traces
| where timestamp > ago(24h)
| where customDimensions.eventId startswith "AL<PREFIX>-"
| where customDimensions.alSubCategory == "Error"
| project
    timestamp,
    eventId = tostring(customDimensions.eventId),
    featureName = tostring(customDimensions.alFeatureName),
    errorText = tostring(customDimensions.alErrorText),
    callStack = tostring(customDimensions.alErrorCallStack),
    environmentName = tostring(customDimensions.environmentName)
| order by timestamp desc
```

### Only Usage (Success)

```kql
traces
| where timestamp > ago(24h)
| where customDimensions.eventId startswith "AL<PREFIX>-"
| where customDimensions.alSubCategory == "Usage"
| project
    timestamp,
    eventId = tostring(customDimensions.eventId),
    featureName = tostring(customDimensions.alFeatureName),
    message,
    environmentName = tostring(customDimensions.environmentName)
| order by timestamp desc
```

## Analytics Queries

### Error Count by Type (Last 7 Days)

```kql
traces
| where timestamp > ago(7d)
| where customDimensions.eventId startswith "AL<PREFIX>-"
| where customDimensions.alSubCategory == "Error"
| summarize
    errorCount = count(),
    lastOccurrence = max(timestamp)
  by
    eventId = tostring(customDimensions.eventId),
    errorText = tostring(customDimensions.alErrorText)
| order by errorCount desc
```

### Success vs Error Ratio

```kql
traces
| where timestamp > ago(7d)
| where customDimensions.eventId startswith "AL<PREFIX>-"
| extend isError = customDimensions.alSubCategory == "Error"
| summarize
    total = count(),
    errors = countif(isError),
    success = countif(not(isError))
| extend
    errorRate = round(100.0 * errors / total, 2),
    successRate = round(100.0 * success / total, 2)
```

### Events by Environment

```kql
traces
| where timestamp > ago(7d)
| where customDimensions.eventId startswith "AL<PREFIX>-"
| summarize
    eventCount = count(),
    errorCount = countif(customDimensions.alSubCategory == "Error")
  by
    environmentName = tostring(customDimensions.environmentName),
    environmentType = tostring(customDimensions.environmentType)
| order by eventCount desc
```

### Events by App Version

```kql
traces
| where timestamp > ago(7d)
| where customDimensions.eventId startswith "AL<PREFIX>-"
| summarize
    eventCount = count(),
    errorCount = countif(customDimensions.alSubCategory == "Error")
  by
    appVersion = tostring(customDimensions.alCallerAppVersion)
| order by appVersion desc
```

## De-duplication Queries

Feature Telemetry creates duplicate events by design. Use these patterns to de-duplicate:

### De-duplicated Event Count

```kql
traces
| where timestamp > ago(7d)
| where customDimensions.eventId startswith "AL<PREFIX>-"
| summarize
    take_any(timestamp),
    take_any(message)
  by
    eventId = tostring(customDimensions.eventId),
    bin(timestamp, 1s),
    documentNo = tostring(customDimensions.alDocumentNo)
| count
```

### De-duplicated Performance Stats

```kql
traces
| where timestamp > ago(7d)
| where customDimensions.eventId startswith "AL<PREFIX>-"
| where tostring(customDimensions.alDurationMs) != ""
// First de-duplicate
| summarize
    take_any(timestamp),
    durationMs = take_any(toint(customDimensions.alDurationMs))
  by
    eventId = tostring(customDimensions.eventId),
    operation = tostring(customDimensions.alOperation),
    bin(timestamp, 1s)
// Then calculate stats
| summarize
    avgDuration = avg(durationMs),
    maxDuration = max(durationMs),
    minDuration = min(durationMs),
    p95Duration = percentile(durationMs, 95),
    callCount = count()
  by operation
| order by avgDuration desc
```

## Custom Dimensions Queries

### With Custom Dimensions (API Logging Example)

```kql
traces
| where timestamp > ago(24h)
| where customDimensions.eventId startswith "AL<PREFIX>-"
| extend
    documentNo = tostring(customDimensions.alDocumentNo),
    operation = tostring(customDimensions.alOperation),
    httpStatus = toint(customDimensions.alHttpStatus),
    durationMs = toint(customDimensions.alDurationMs),
    url = tostring(customDimensions.alURL)
| project
    timestamp,
    eventId = tostring(customDimensions.eventId),
    documentNo,
    operation,
    httpStatus,
    durationMs,
    url
| order by timestamp desc
```

### Find Slow Operations

```kql
traces
| where timestamp > ago(7d)
| where customDimensions.eventId startswith "AL<PREFIX>-"
| where toint(customDimensions.alDurationMs) > 5000  // > 5 seconds
| project
    timestamp,
    eventId = tostring(customDimensions.eventId),
    operation = tostring(customDimensions.alOperation),
    durationMs = toint(customDimensions.alDurationMs),
    documentNo = tostring(customDimensions.alDocumentNo)
| order by durationMs desc
```

## Uptake/Adoption Queries

### Feature Uptake Funnel

```kql
traces
| where timestamp > ago(30d)
| where customDimensions.eventId startswith "AL<PREFIX>-"
| where customDimensions.alSubCategory == "Uptake"
| summarize
    discovered = countif(customDimensions.alFeatureUptakeStatus == "Discovered"),
    setup = countif(customDimensions.alFeatureUptakeStatus == "Set up"),
    used = countif(customDimensions.alFeatureUptakeStatus == "Used")
  by featureName = tostring(customDimensions.alFeatureName)
```

### Companies Using Feature

```kql
traces
| where timestamp > ago(30d)
| where customDimensions.eventId startswith "AL<PREFIX>-"
| where customDimensions.alSubCategory == "Usage"
| summarize
    usageCount = count(),
    lastUsed = max(timestamp)
  by
    companyName = tostring(customDimensions.alCompany),
    environmentName = tostring(customDimensions.environmentName)
| order by usageCount desc
```

## Alert Queries

### High Error Rate Alert

```kql
traces
| where timestamp > ago(1h)
| where customDimensions.eventId startswith "AL<PREFIX>-"
| summarize
    total = count(),
    errors = countif(customDimensions.alSubCategory == "Error")
| where errors > 0 and (errors * 100.0 / total) > 10  // Alert if > 10% errors
```

### Specific Error Pattern

```kql
traces
| where timestamp > ago(1h)
| where customDimensions.eventId startswith "AL<PREFIX>-"
| where customDimensions.alSubCategory == "Error"
| where customDimensions.eventId == "AL<PREFIX>-0002"  // Specific error type
| count
| where Count > 5  // Alert if > 5 occurrences in 1 hour
```

## Notes

- Replace `<PREFIX>` with your actual EventId prefix (e.g., `SST`, `APP`)
- Custom dimensions added in code get `al` prefix in Application Insights
  - Code: `DocumentNo` → AI: `alDocumentNo`
- Adjust time ranges as needed (`ago(24h)`, `ago(7d)`, etc.)

## External Resources

- [KQL Tutorial](https://learn.microsoft.com/en-us/azure/data-explorer/kusto/query/)
- [BCTech KQL Samples](https://github.com/microsoft/BCTech/tree/master/samples/AppInsights/KQL/Queries)
