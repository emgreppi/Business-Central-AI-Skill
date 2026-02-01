---
name: binding-event-subscribers
description: Turns event subscribers on and off dynamically using BindSubscription() and UnbindSubscription() with EventSubscriberInstance = Manual for conditional event handling. Use when disabling subscribers during batch jobs, enabling page-scoped validation, implementing feature toggles via setup, turning off event handlers for performance, or controlling dynamic event execution at runtime.
license: MIT
metadata:
  version: 1.0.0
---

# Skill: AL Event Binding

## Validation Gates

1. **After Step 1**: Manual codeunit compiles, subscribers don't fire without binding
2. **After Step 2**: BindSubscription activates subscriber, events fire correctly
3. **Final**: UnbindSubscription deactivates, no events fire after unbind

**Note:** Default to `StaticAutomatic`. Use Manual only for conditional/performance scenarios. Binding is session-specific.

## Procedure

### Step 1: Create Manual Subscriber Codeunit

```al
codeunit <ID> "<PREFIX> <Entity> Subscribers"
{
    EventSubscriberInstance = Manual;

    [EventSubscriber(ObjectType::Table, Database::<SourceTable>, 'OnAfterValidateEvent', '<FieldName>', false, false)]
    local procedure OnValidate<FieldName>(var Rec: Record <SourceTable>)
    begin
        // Your validation logic here
        if StrLen(Rec.<FieldName>) < 3 then
            Error('<FieldName> must be at least 3 characters');
    end;
}
```

### Step 2: Bind in Context (Page/Codeunit)

```al
pageextension <ID> "<PREFIX> <Entity> Card Ext" extends "<SourcePageName>"
{
    var
        EntitySubscribers: Codeunit "<PREFIX> <Entity> Subscribers";

    trigger OnOpenPage()
    begin
        BindSubscription(EntitySubscribers);
    end;

    trigger OnClosePage()
    begin
        UnbindSubscription(EntitySubscribers);
    end;
}
```

## Common Patterns

### Conditional via Setup

```al
procedure ProcessDocument(var SourceRecord: Record <SourceTable>)
var
    AdvancedValidation: Codeunit "<PREFIX> Advanced Validation";
    Setup: Record "<PREFIX> Setup";
begin
    if Setup.Get() and Setup."Enable Advanced Validation" then
        BindSubscription(AdvancedValidation);

    Codeunit.Run(Codeunit::<ProcessingCodeunit>, SourceRecord);
    // Auto-unbinds when procedure ends
end;
```

### Batch Job Optimization

UI subscribers bound only in pages, not in job queue codeunits:
- Page: `OnOpenPage` → `BindSubscription(UINotifications)`
- Job Queue: No binding → no UI overhead

## Important Notes

**Binding behavior:**
- Session-specific (Session A binding doesn't affect Session B)
- Auto-dissolves when codeunit instance goes out of scope
- Cannot call Bind/Unbind on `StaticAutomatic` codeunits (runtime error)

**Stale metadata:** Recompiling bound codeunit shows error "subscriber is stale" - only during development, not production.

**⚠️** Do NOT use Manual for critical business logic that must never be missed.

## External Documentation

- [EventSubscriberInstance Property](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/properties/devenv-eventsubscriberinstance-property)
- [BindSubscription Method](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/methods-auto/session/session-bindsubscription-method)
