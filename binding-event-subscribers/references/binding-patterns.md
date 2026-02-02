# Event Binding Patterns Reference

Additional patterns and anti-patterns for manual event subscriber binding.

## Pattern: Scoped Transaction Binding

Bind subscribers only for the duration of a specific transaction:

```al
codeunit 50110 "DEMOAudit Logger"
{
    EventSubscriberInstance = Manual;

    var
        AuditEntries: List of [Text];

    [EventSubscriber(ObjectType::Table, Database::"Sales Line", 'OnAfterModifyEvent', '', false, false)]
    local procedure OnAfterModifySalesLine(var Rec: Record "Sales Line"; var xRec: Record "Sales Line")
    begin
        if Rec.Quantity <> xRec.Quantity then
            AuditEntries.Add(StrSubstNo('Line %1: Qty changed from %2 to %3',
                Rec."Line No.", xRec.Quantity, Rec.Quantity));
    end;

    procedure GetAuditLog(): Text
    var
        StringBuilder: TextBuilder;
        Entry: Text;
    begin
        foreach Entry in AuditEntries do
            StringBuilder.AppendLine(Entry);
        exit(StringBuilder.ToText());
    end;

    procedure ClearLog()
    begin
        Clear(AuditEntries);
    end;
}
```

```al
codeunit 50111 "DEMOOrder Processor"
{
    procedure ProcessOrderWithAudit(var SalesHeader: Record "Sales Header")
    var
        AuditLogger: Codeunit "DEMOAudit Logger";
        AuditLog: Text;
    begin
        // Start auditing
        BindSubscription(AuditLogger);

        // Process the order (all modifications will be logged)
        ProcessOrderInternal(SalesHeader);

        // Get audit results before unbinding
        AuditLog := AuditLogger.GetAuditLog();

        // Stop auditing
        UnbindSubscription(AuditLogger);

        // Save audit log
        SaveAuditLog(SalesHeader."No.", AuditLog);
    end;

    local procedure ProcessOrderInternal(var SalesHeader: Record "Sales Header")
    begin
        // Order processing logic that modifies sales lines
    end;

    local procedure SaveAuditLog(OrderNo: Code[20]; AuditLog: Text)
    begin
        // Save to audit table or send to external system
    end;
}
```

## Pattern: Feature Toggle Binding

Enable/disable functionality through feature flags:

```al
codeunit 50112 "DEMOFeature Subscribers"
{
    EventSubscriberInstance = Manual;

    [EventSubscriber(ObjectType::Table, Database::Customer, 'OnAfterInsertEvent', '', false, false)]
    local procedure OnAfterInsertCustomer(var Rec: Record Customer)
    begin
        // New feature: Auto-assign customer template
        AutoAssignTemplate(Rec);
    end;

    local procedure AutoAssignTemplate(var Customer: Record Customer)
    begin
        // Feature implementation
    end;
}
```

```al
codeunit 50113 "DEMOFeature Manager"
{
    var
        FeatureSubscribers: Codeunit "DEMOFeature Subscribers";
        IsBound: Boolean;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"System Initialization", 'OnAfterLogin', '', false, false)]
    local procedure OnAfterLogin()
    begin
        // Bind feature subscribers based on setup
        InitializeFeatures();
    end;

    local procedure InitializeFeatures()
    var
        FeatureSetup: Record "DEMOFeature Setup";
    begin
        if not FeatureSetup.Get() then
            exit;

        if FeatureSetup."Auto Template Assignment" and not IsBound then begin
            BindSubscription(FeatureSubscribers);
            IsBound := true;
        end;
    end;

    procedure RefreshFeatures()
    var
        FeatureSetup: Record "DEMOFeature Setup";
    begin
        FeatureSetup.Get();

        if FeatureSetup."Auto Template Assignment" and not IsBound then begin
            BindSubscription(FeatureSubscribers);
            IsBound := true;
        end else if not FeatureSetup."Auto Template Assignment" and IsBound then begin
            UnbindSubscription(FeatureSubscribers);
            IsBound := false;
        end;
    end;
}
```

## Pattern: Test Isolation

Use manual binding to control event behavior in tests:

```al
codeunit 50114 "DEMOExternal API Subscriber"
{
    EventSubscriberInstance = Manual;

    [EventSubscriber(ObjectType::Table, Database::"Sales Header", 'OnAfterInsertEvent', '', false, false)]
    local procedure OnAfterInsertSalesHeader(var Rec: Record "Sales Header")
    begin
        // Call external API - we want to disable this in tests
        CallExternalAPI(Rec);
    end;

    local procedure CallExternalAPI(SalesHeader: Record "Sales Header")
    begin
        // External API call
    end;
}
```

```al
// Production code - binds the subscriber
codeunit 50115 "DEMOSales Setup"
{
    var
        ExternalAPISubscriber: Codeunit "DEMOExternal API Subscriber";

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"System Initialization", 'OnAfterLogin', '', false, false)]
    local procedure OnAfterLogin()
    begin
        BindSubscription(ExternalAPISubscriber);
    end;
}

// Test code - does NOT bind, so external API is not called
[Test]
procedure TestSalesOrderCreation()
var
    SalesHeader: Record "Sales Header";
begin
    // ExternalAPISubscriber is Manual and not bound in test context
    // So no external API calls during test

    // Arrange & Act
    CreateSalesOrder(SalesHeader);

    // Assert
    Assert.IsTrue(SalesHeader."No." <> '', 'Sales order should be created');
end;
```

## Anti-Pattern: Critical Business Logic

**DO NOT** use manual binding for logic that must always execute:

```al
// WRONG: Critical validation that could be missed
codeunit 50120 "DEMOCredit Check" // BAD EXAMPLE
{
    EventSubscriberInstance = Manual;  // WRONG!

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnBeforePostSalesDoc', '', false, false)]
    local procedure OnBeforePostSalesDoc(var SalesHeader: Record "Sales Header")
    begin
        // If this codeunit is not bound, credit check is skipped!
        CheckCustomerCredit(SalesHeader);
    end;
}
```

**CORRECT:** Use StaticAutomatic for critical logic:

```al
// CORRECT: Critical validation always runs
codeunit 50121 "DEMOCredit Check"
{
    // EventSubscriberInstance = StaticAutomatic (default, no need to specify)

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnBeforePostSalesDoc', '', false, false)]
    local procedure OnBeforePostSalesDoc(var SalesHeader: Record "Sales Header")
    begin
        // This always runs - credit check cannot be bypassed
        CheckCustomerCredit(SalesHeader);
    end;
}
```

## Anti-Pattern: Forgetting to Unbind

**Problem:** Leaving subscribers bound longer than needed:

```al
// WRONG: No unbind - subscribers stay active until session ends
pageextension 50102 "DEMOItem Card Ext" extends "Item Card"
{
    var
        ItemSubscribers: Codeunit "DEMOItem Subscribers";

    trigger OnOpenPage()
    begin
        BindSubscription(ItemSubscribers);
        // Missing OnClosePage with UnbindSubscription!
    end;
}
```

**CORRECT:** Always unbind when done:

```al
pageextension 50103 "DEMOItem Card Ext" extends "Item Card"
{
    var
        ItemSubscribers: Codeunit "DEMOItem Subscribers";
        IsBound: Boolean;

    trigger OnOpenPage()
    begin
        BindSubscription(ItemSubscribers);
        IsBound := true;
    end;

    trigger OnClosePage()
    begin
        if IsBound then
            UnbindSubscription(ItemSubscribers);
    end;
}
```

## Anti-Pattern: Assuming Cross-Session Binding

**Problem:** Expecting binding in one session to affect another:

```al
// WRONG: This won't work as expected
codeunit 50122 "DEMOGlobal Binding" // BAD EXAMPLE
{
    procedure EnableFeatureForAllUsers()
    var
        FeatureSubscriber: Codeunit "DEMOFeature Subscriber";
    begin
        // This only binds for the current session!
        // Other users' sessions are NOT affected
        BindSubscription(FeatureSubscriber);
    end;
}
```

**CORRECT:** Use setup table + OnAfterLogin pattern:

```al
// CORRECT: Each session binds on login based on setup
codeunit 50123 "DEMOSession Initializer"
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"System Initialization", 'OnAfterLogin', '', false, false)]
    local procedure OnAfterLogin()
    var
        Setup: Record "DEMOFeature Setup";
        FeatureSubscriber: Codeunit "DEMOFeature Subscriber";
    begin
        if Setup.Get() and Setup."Feature Enabled" then
            BindSubscription(FeatureSubscriber);
    end;
}
```

## Summary Table

| Pattern | Use Case | Binding Point |
|---------|----------|---------------|
| Page-Scoped | UI-specific logic | OnOpenPage / OnClosePage |
| Transaction-Scoped | Audit logging | Before/After specific operation |
| Feature Toggle | A/B testing, gradual rollout | OnAfterLogin based on setup |
| Test Isolation | Disable external calls in tests | Production code only |

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| Critical Logic | Business rules can be bypassed | Use StaticAutomatic |
| Missing Unbind | Resource leak, unexpected behavior | Always unbind explicitly |
| Cross-Session | Binding doesn't propagate | Use OnAfterLogin pattern |
