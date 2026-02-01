---
name: implementing-al-interfaces
description: Defines AL interfaces and interface patterns with implementing codeunits, creates extensible enums to switch providers, and enables dependency injection for unit testing AL code with mocks. Use when building plugin architectures, adding loose coupling, replacing conditional logic with polymorphism, or creating Business Central extensions with swappable implementations.
license: MIT
metadata:
  version: 1.0.0
---

# Skill: AL Interfaces

## Validation Gates

1. **After Step 2**: Interface compiles, implementing codeunit compiles with all methods
2. **After Step 3**: Enum converts to interface, method calls work polymorphically
3. **Final**: Mock codeunit works in tests, `is`/`as` operators behave correctly (BC25+)

**Note:** BC16+ for basic interfaces. BC25+ for `is`/`as` operators and extensible interfaces.

**Output:** Interface declaration, implementing codeunits, extensible enum, and usage pattern.

## Procedure

### Step 1: Declare Interface

```al
interface "<PREFIX> I<ServiceType> Provider"
{
    procedure Execute<Operation>(InputData: <InputType>): <ReturnType>;
    procedure Cancel<Operation>(TransactionId: Text; InputData: <InputType>): <ReturnType>;
    procedure GetProviderName(): Text;
}
```

**Placeholder Reference:**
| Placeholder | Description | Example |
|-------------|-------------|---------|
| `<ServiceType>` | Type of service | `Payment`, `Shipping`, `Notification` |
| `<Provider1>`, `<Provider2>` | Provider implementations | `Stripe`, `DHL`, `Email` |
| `<Operation>` | Main operation name | `Payment`, `Shipment`, `Message` |
| `<InputType>` | Input parameter type | `Decimal`, `Record "Sales Header"` |
| `<ReturnType>` | Return value type | `Boolean`, `Text` |

### Step 2: Create Implementing Codeunits

```al
codeunit <ID> "<PREFIX> <Provider1> <ServiceType>" implements "<PREFIX> I<ServiceType> Provider"
{
    procedure Execute<Operation>(InputData: <InputType>): <ReturnType>
    begin
        exit(Call<Provider1>API(InputData));
    end;

    procedure Cancel<Operation>(TransactionId: Text; InputData: <InputType>): <ReturnType>
    begin
        exit(Call<Provider1>CancelAPI(TransactionId, InputData));
    end;

    procedure GetProviderName(): Text
    begin
        exit('<Provider1>');
    end;

    local procedure Call<Provider1>API(InputData: <InputType>): <ReturnType>
    begin
        // Provider-specific logic
    end;

    local procedure Call<Provider1>CancelAPI(TransactionId: Text; InputData: <InputType>): <ReturnType>
    begin
        // Provider-specific logic
    end;
}
```

Create additional codeunits for each provider (`<Provider2>`, `<Provider3>`, etc.) implementing the same interface.

### Step 3: Create Enum with Implements

```al
enum <ID> "<PREFIX> <ServiceType> Provider" implements "<PREFIX> I<ServiceType> Provider"
{
    Extensible = true;

    value(0; <Provider1>)
    {
        Implementation = "<PREFIX> I<ServiceType> Provider" = "<PREFIX> <Provider1> <ServiceType>";
    }
    value(1; <Provider2>)
    {
        Implementation = "<PREFIX> I<ServiceType> Provider" = "<PREFIX> <Provider2> <ServiceType>";
    }
}
```

### Step 4: Use Interface Polymorphically

```al
codeunit <ID> "<PREFIX> <ServiceType> Manager"
{
    procedure Process<Operation>(var SourceRecord: Record <SourceTable>): Boolean
    var
        ProviderType: Enum "<PREFIX> <ServiceType> Provider";
        IProvider: Interface "<PREFIX> I<ServiceType> Provider";
    begin
        ProviderType := SourceRecord."<PREFIX> <ServiceType> Provider";
        IProvider := ProviderType;  // Implicit conversion

        if IProvider.Execute<Operation>(SourceRecord.<InputField>) then begin
            SourceRecord."<PREFIX> <Operation> Processed" := true;
            SourceRecord.Modify();
            exit(true);
        end;
        exit(false);
    end;
}
```

## BC25+ Features: is/as Operators

```al
// Check if interface supports specific type, then convert
if IProvider is "<PREFIX> IAdvanced<ServiceType>" then begin
    IAdvanced := IProvider as "<PREFIX> IAdvanced<ServiceType>";
    exit(IAdvanced.Partial<Operation>(TransactionId, InputData, '<Reason>'));
end;
exit(IProvider.Cancel<Operation>(TransactionId, InputData));
```

**Multiple interfaces:** `codeunit <ID> "..." implements "I<ServiceType>", "IAdvanced<ServiceType>", "I<ServiceType>Status"`

## Dependency Injection for Testing

**Pattern:** Store interface as codeunit variable, inject via `Initialize(Provider)` procedure.

```al
codeunit <ID> "<PREFIX> <Entity> Processor"
{
    var
        ServiceProvider: Interface "<PREFIX> I<ServiceType> Provider";

    procedure Initialize(Provider: Interface "<PREFIX> I<ServiceType> Provider")
    begin
        ServiceProvider := Provider;
    end;

    procedure Process<Entity>(var SourceRecord: Record <SourceTable>): Boolean
    begin
        exit(ServiceProvider.Execute<Operation>(SourceRecord.<InputField>));
    end;
}
```

**Mock for tests:** Create codeunit implementing interface with configurable behavior (`SetShouldSucceed`, `GetCallCount`).

See `references/interface-patterns.md` for complete mock implementation example.

## Common Patterns

| Pattern | Description |
|---------|-------------|
| **Provider/Strategy** | Multiple implementations for same operation (payment, shipping) |
| **Factory** | `exit(ProviderType)` - enum implicitly converts to interface |
| **Decorator** | Wrap interface to add logging, validation, caching |

## Important Notes

**Best practices:** Small focused interfaces, `Extensible = true` for partner extensions, use enums for selection.

**Limitations:** Only procedures (no properties/events/variables), only codeunits implement, cannot serialize to records.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "does not implement interface" | Verify all interface methods exist with exact signatures |
| Enum doesn't convert to interface | Check `implements` clause on enum declaration |
| `is`/`as` operators not available | Requires BC25+ (2024 Wave 2) |

**Feedback loop:** Fix signature → Re-compile → Verify method calls work polymorphically.

## References

See `references/` folder for:
- `interface-patterns.md` - Additional code examples

## External Documentation

- [Microsoft: Interfaces in AL](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-interfaces-in-al)
- [Microsoft: Extensible Enums](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-extensible-enums)
