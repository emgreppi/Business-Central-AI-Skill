---
name: optimizing-bc-performance
description: Speeds up slow AL code by optimizing data access patterns, reducing database locks, and fixing inefficient loops. Use when code runs slowly, reports timeout, pages freeze, or you need to make loops faster, reduce SQL queries, avoid table locks, or improve BC SaaS performance.
license: MIT
metadata:
  version: 1.0.0
---

# Skill: AL Performance Rules (BC SaaS)

## Validation Gates

1. **After Data Access**: `SetLoadFields` before every `FindSet`/`Find`, `IsEmpty()` instead of `Count() = 0`
2. **After Reports/APIs**: `DataAccessIntent = ReadOnly` on read-only objects
3. **Final**: No `+=` string concatenation in loops, `TextBuilder` used for 5+ concatenations

**Note:** BC23+ defaults to `ReadCommitted` isolation. Use `UpdLock` only for specific row locking.

## Data Access Rules

| Rule | Description |
|------|-------------|
| **SetLoadFields** | ALWAYS before `FindSet`/`Find` on tables with extensions |
| **IsEmpty()** | Instead of `Count() = 0` (avoids lock on primary index) |
| **SetAutoCalcFields** | Instead of `CalcFields` in loops |
| **Bulk operations** | `ModifyAll`/`DeleteAll` when no triggers needed |

```al
// CORRECT
Item.SetLoadFields("No.", "Description", "Unit Price");
if Item.FindSet() then repeat /* ... */ until Item.Next() = 0;

// CORRECT: IsEmpty instead of Count
if Customer.IsEmpty() then exit;

// WRONG: Count() = 0 causes locks
if Customer.Count() = 0 then exit;  // AVOID!
```

## Transaction Isolation

| Level | Use Case |
|-------|----------|
| **ReadCommitted** | Default (v23+). Counts without locks |
| **UpdLock** | Lock specific rows (GetNextEntryNo) |

```al
// Lock only last row for sequence
GLEntry.ReadIsolation := IsolationLevel::UpdLock;
GLEntry.FindLast();
exit(GLEntry."Entry No." + 1);
```

## Pages & Reports

| Rule | Description |
|------|-------------|
| **DataAccessIntent = ReadOnly** | Reports/APIs that only read (uses Azure SQL replica) |
| **Page Background Tasks** | Heavy calculations in UI (cues, statistics) |

```al
report 50100 "My Report"
{
    DataAccessIntent = ReadOnly;  // Uses read replica
}
```

## Async Patterns

| Method | Characteristics |
|--------|-----------------|
| **Page Background Task** | Read-only, lightweight, bound to page |
| **StartSession** | Max 12h timeout, immediate start |
| **TaskScheduler** | 99 retries, survives restarts |
| **Job Queue** | Scheduled, recurring, with logging |

## Strings & Collections

```al
// CORRECT: TextBuilder for loops
var StringBuilder: TextBuilder;
begin
    foreach Item in Items do
        StringBuilder.AppendLine(Item.Description);
    exit(StringBuilder.ToText());
end;

// WRONG: += in loop - AVOID!
foreach Item in Items do
    Result += Item.Description + '\';
```

**Rule:** Use `TextBuilder` for 5+ concatenations or any loop. Use `Dictionary`/`List` instead of temporary tables.

## Code Review Checklist

```markdown
- [ ] SetLoadFields before FindSet/Find on tables with extensions?
- [ ] IsEmpty() instead of Count() = 0?
- [ ] DataAccessIntent = ReadOnly on read-only reports/APIs?
- [ ] TextBuilder for string concatenations in loops?
- [ ] CommitBehavior on critical integration events?
```

## External Documentation

- [Microsoft: Performance Developer Guide](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/performance/performance-developer)
