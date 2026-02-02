---
name: optimizing-bc-performance
description: Speeds up slow AL code by optimizing data access patterns, reducing database locks, and fixing inefficient loops. Use when code runs slowly, reports timeout, pages freeze, or you need to make loops faster, reduce SQL queries, avoid table locks, or improve BC SaaS performance.
license: MIT
metadata:
  version: 1.1.0
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
| **SetCurrentKey** | Use indexed fields for filters to speed up queries |
| **IsEmpty()** | Instead of `Count() = 0` (avoids lock on primary index) |
| **SetAutoCalcFields** | Instead of `CalcFields` in loops |
| **CalcSums** | Instead of loop to sum values |
| **Bulk operations** | `ModifyAll`/`DeleteAll` when no triggers needed |

```al
// CORRECT: SetLoadFields
Item.SetLoadFields("No.", "Description", "Unit Price");
if Item.FindSet() then repeat /* ... */ until Item.Next() = 0;

// CORRECT: SetCurrentKey for indexed fields
CustLedgEntry.SetCurrentKey("Customer No.", "Posting Date");
CustLedgEntry.SetRange("Customer No.", Customer."No.");
CustLedgEntry.SetFilter("Posting Date", '>=%1', StartDate);

// CORRECT: IsEmpty instead of Count
if Customer.IsEmpty() then exit;

// CORRECT: CalcSums instead of loop
GLEntries.SetFilter("G/L Account No.", AccountFilter);
GLEntries.CalcSums(Amount);
TotalAmount := GLEntries.Amount;

// WRONG: Count() = 0 causes locks
if Customer.Count() = 0 then exit;  // AVOID!

// WRONG: Loop to sum values
repeat
    TotalAmount += GLEntries.Amount;  // AVOID!
until GLEntries.Next() = 0;
```

### Warnings

**SetLoadFields + Validate**: Validate may touch other fields, triggering JIT loading and making the "fast" version slower.

```al
// CAUTION: Validate may load additional fields
Customer.SetLoadFields("City");
Customer.FindSet();
repeat
    Customer.Validate(City, Customer.City.Trim());  // May trigger JIT loading!
until Customer.Next() = 0;
```

**IsEmpty not always faster**: If records exist in most cases, `FindSet` directly is faster (avoids double query).

```al
// WRONG when records usually exist (e.g., Sales Lines for Sales Header)
if not SalesLine.IsEmpty() then  // Unnecessary query!
    SalesLine.FindSet();

// CORRECT: Just use FindSet when records expected
if SalesLine.FindSet() then
    repeat /* ... */ until SalesLine.Next() = 0;
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

// Page Background Task for heavy calculations
trigger OnAfterGetCurrRecord()
var
    TaskParameters: Dictionary of [Text, Text];
begin
    CurrPage.EnqueueBackgroundTask(TaskId, Codeunit::DoComplexCalculation, TaskParameters);
end;
```

## Procedure Parameters

Pass only necessary fields, not entire records. Passing a record without `var` creates a memory copy.

```al
// WRONG: Passes entire record (creates memory copy)
NoOfOrders := CountOrdersByCustomer(Customer);

local procedure CountOrdersByCustomer(Customer: Record Customer): Integer
begin
    SalesHeader.SetRange("Sell-to Customer No.", Customer."No.");
    exit(SalesHeader.Count());
end;

// CORRECT: Pass only needed field
NoOfOrders := CountOrdersByCustomer(Customer."No.");

local procedure CountOrdersByCustomer(CustomerNo: Code[20]): Integer
begin
    SalesHeader.SetRange("Sell-to Customer No.", CustomerNo);
    exit(SalesHeader.Count());
end;

// ALTERNATIVE: Use var to pass by reference (no copy)
local procedure ProcessCustomer(var Customer: Record Customer)
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

**Rule:** Use `TextBuilder` for 5+ concatenations or any loop. Use `Dictionary`/`List` instead of temporary tables for in-memory operations.

## Code Review Checklist

```markdown
- [ ] SetLoadFields before FindSet/Find on tables with extensions?
- [ ] SetCurrentKey when filtering on non-primary key fields?
- [ ] IsEmpty() instead of Count() = 0? (only when records rarely exist)
- [ ] CalcSums instead of loop for summing?
- [ ] DataAccessIntent = ReadOnly on read-only reports/APIs?
- [ ] TextBuilder for string concatenations in loops?
- [ ] Procedure parameters: fields instead of full records?
- [ ] CommitBehavior on critical integration events?
```

## External Documentation

- [Microsoft: Performance Developer Guide](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/performance/performance-developer)
- [Stefan Šošić: Performance Patterns Part 1](https://ssosic.com/development/performance-patterns-for-al-code-part-1/)
- [Stefan Šošić: Performance Patterns Part 2](https://ssosic.com/development/performance-patterns-for-al-code-part-2/)
