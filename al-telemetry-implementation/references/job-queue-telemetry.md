# Job Queue and Scheduled Task Telemetry

## Overview

Job Queue entries in Business Central trigger Scheduled Tasks at platform level. This creates two related telemetry streams:
- **AL events** (Application): Job Queue lifecycle from application perspective
- **LC events** (Lifecycle): Scheduled Task lifecycle from platform perspective

## Event Flow

```
Job Queue Entry Created
       |
       v
AL0000E24 (Enqueued) -----> LC0040 (Task Created)
       |
       v
[Wait for scheduled time]
       |
       v
AL0000E25 (Started)
       |
       +---> Success Path:
       |     LC0042 (Removed) + LC0043 (Completed) + AL0000E26 (Success)
       |
       +---> Failure Path:
             LC0045 (Failed) + AL0000HE7 (Failure)
```

## Job Queue Event IDs (AL)

| EventId | Event | Key Dimensions |
|---------|-------|----------------|
| `AL0000E24` | Enqueued | `alJobQueueId`, `alScheduledTaskId`, `alObjectType`, `alObjectId` |
| `AL0000E25` | Started | `alJobQueueId`, `alScheduledTaskId` |
| `AL0000E26` | Success | `alJobQueueId`, `alScheduledTaskId`, `serverExecutionTime` |
| `AL0000HE7` | Failure | `alJobQueueId`, `alJobQueueStacktrace`, `alErrorText` |

**Source:** Codeunit 1351 "Telemetry Subscribers"

| Event ID | Codeunit | Publisher |
|----------|----------|-----------|
| AL0000E24 | 453 "Job Queue Enqueue" | OnAfterEnqueueJobQueueEntry |
| AL0000E25 | 448 "Job Queue Dispatcher" | OnBeforeExecuteJob |
| AL0000E26 | 448 "Job Queue Dispatcher" | OnAfterSuccessHandleRequest |
| AL0000HE7 | 450 "Job Queue Error Handler" | OnBeforeLogError |

## Scheduled Task Event IDs (LC)

| EventId | Event | Key Dimensions |
|---------|-------|----------------|
| `LC0040` | Created | `alTaskId` |
| `LC0041` | Ready | `alTaskId` |
| `LC0042` | Removed | `alTaskId` |
| `LC0043` | Completed | `alTaskId`, `serverExecutionTime` |
| `LC0044` | Canceled | `alTaskId` |
| `LC0045` | Failed | `alTaskId`, `failureReason` |
| `LC0057` | Timeout | `alTaskId` |

## KQL Queries

### Count Job Queue Events by Type

```kql
let jobQueueEvents = dynamic(["AL0000E24", "AL0000E25", "AL0000E26", "AL0000HE7"]);
traces
| where timestamp > ago(7d)
| where customDimensions.eventId in (jobQueueEvents)
| summarize count() by eventId = tostring(customDimensions.eventId)
| order by eventId asc
```

### Count Scheduled Task Events by Type

```kql
let taskEvents = dynamic(["LC0040", "LC0041", "LC0042", "LC0043", "LC0044", "LC0045", "LC0057"]);
traces
| where timestamp > ago(7d)
| where customDimensions.eventId in (taskEvents)
| summarize count() by eventId = tostring(customDimensions.eventId)
| order by eventId asc
```

### Get Job Queue Entry with Scheduled Task ID

```kql
traces
| where timestamp > ago(24h)
| where customDimensions.eventId == "AL0000E24"
| project
    timestamp,
    jobQueueId = tostring(customDimensions.alJobQueueId),
    scheduledTaskId = tostring(customDimensions.alScheduledTaskId),
    objectType = tostring(customDimensions.alObjectType),
    objectId = tostring(customDimensions.alObjectId)
| take 10
```

### Correlate Job Queue with Scheduled Task Timeline

```kql
// First get a specific job queue entry
let jobQueueId = "6bdc3fb9-a4ab-4b9e-8a2a-446322edf80e";  // Replace with actual ID
let scheduledTaskId = "4ed2285e-a06a-405c-9bac-d9de2e911b61";  // Replace with actual ID
let jobQueueEvents = dynamic(["AL0000E24", "AL0000E25", "AL0000E26", "AL0000HE7"]);
let taskEvents = dynamic(["LC0040", "LC0041", "LC0042", "LC0043", "LC0044", "LC0045", "LC0057"]);
traces
| where timestamp > ago(24h)
| where customDimensions.eventId in (jobQueueEvents) or customDimensions.eventId in (taskEvents)
| where tostring(customDimensions.alJobQueueId) == jobQueueId
    or tostring(customDimensions.alTaskId) == scheduledTaskId
    or tostring(customDimensions.alScheduledTaskId) == scheduledTaskId
| project
    timestamp,
    eventId = tostring(customDimensions.eventId),
    message
| order by timestamp asc
```

### Find Failed Job Queues with Stack Trace

```kql
traces
| where timestamp > ago(7d)
| where customDimensions.eventId == "AL0000HE7"
| project
    timestamp,
    jobQueueId = tostring(customDimensions.alJobQueueId),
    errorText = tostring(customDimensions.alErrorText),
    stackTrace = tostring(customDimensions.alJobQueueStacktrace),
    objectType = tostring(customDimensions.alObjectType),
    objectId = tostring(customDimensions.alObjectId)
| order by timestamp desc
```

### Job Queue Success Rate

```kql
traces
| where timestamp > ago(7d)
| where customDimensions.eventId in ("AL0000E26", "AL0000HE7")
| summarize
    total = count(),
    success = countif(customDimensions.eventId == "AL0000E26"),
    failed = countif(customDimensions.eventId == "AL0000HE7")
| extend
    successRate = round(100.0 * success / total, 2),
    failureRate = round(100.0 * failed / total, 2)
```

### Job Queue Performance (Execution Time)

```kql
traces
| where timestamp > ago(7d)
| where customDimensions.eventId == "AL0000E26"
| extend
    executionTimeMs = toreal(totimespan(customDimensions.serverExecutionTime)) / 10000,
    objectId = tostring(customDimensions.alObjectId),
    objectType = tostring(customDimensions.alObjectType)
| summarize
    avgTime = avg(executionTimeMs),
    maxTime = max(executionTimeMs),
    minTime = min(executionTimeMs),
    p95Time = percentile(executionTimeMs, 95),
    executions = count()
  by objectType, objectId
| order by avgTime desc
```

### Events in Specific Time Window

```kql
// Analyze all events between job queue start and completion
let startTime = datetime(2024-01-15T13:29:58Z);
let endTime = datetime(2024-01-15T13:30:03Z);
traces
| where timestamp between (startTime .. endTime)
| project
    timestamp,
    eventId = tostring(customDimensions.eventId),
    message,
    sessionId = tostring(customDimensions.session_Id)
| order by timestamp asc
```

## Troubleshooting Guide

### Job Queue Not Running

1. Check if `AL0000E24` (Enqueued) exists
2. Check if `LC0040` (Task Created) followed
3. Look for `LC0044` (Canceled) or `LC0045` (Failed)

### Job Queue Slow

1. Query `AL0000E26` for `serverExecutionTime`
2. Compare with `RT0006` (Report generation) if running reports
3. Check `RT0005` (Long running SQL) in same time window

### Job Queue Failing

1. Query `AL0000HE7` for `alJobQueueStacktrace`
2. Check `alErrorText` for error message
3. Correlate with `LC0045` for platform-level failure info

## Notes

- Scheduled Task events (`LC*`) don't contain reference to source Job Queue
- Use `alScheduledTaskId` from `AL0000E24` to correlate
- Background sessions created for Job Queue are visible in `RT0003`/`RT0004`
- Report execution within Job Queue generates `RT0006` signal
