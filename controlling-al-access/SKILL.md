---
name: controlling-al-access
description: Controls visibility of AL objects and fields using Access property (Public, Internal, Protected, Local), hides internal helpers from external apps, exposes public API surfaces, and configures internalsVisibleTo for multi-app scenarios. Use when making codeunits private, hiding staging tables, protecting fields from partners, or sharing internals between companion apps.
license: MIT
metadata:
  version: 1.0.0
---

# Skill: AL Access Modifiers

## Validation Gates

1. **After Step 1**: Internal objects compile, external apps get "not accessible" compile error
2. **After Step 2**: Field access levels work (test: Local field inaccessible outside table)
3. **Final**: `internalsVisibleTo` apps can access internal objects

**Note:** BC 2019 Wave 2+ (Runtime 4.0). Compile-time only - RecordRef/FieldRef bypass at runtime.

**Output:** Objects with correct Access property, app.json with internalsVisibleTo (if multi-app).

**Supported objects:** Codeunit, Table, Table field, Query, Enum, Interface, PermissionSet

## Procedure

### Step 1: Set Object Access

```al
// Internal table - hidden from external apps
table <ID> "<PREFIX> Internal Staging"
{
    Access = Internal;
    // ... fields
}

// Internal codeunit - helper not exposed to partners
codeunit <ID> "<PREFIX> Internal Helper"
{
    Access = Internal;
    // ... procedures
}
```

### Step 2: Set Field Access

```al
table <ID> "<PREFIX> Order Extension"
{
    Access = Public;
    fields
    {
        field(1; "Order No."; Code[20]) { Access = Public; }      // Stable API
        field(2; "Processing Flags"; Integer) { Access = Internal; } // Same app only
        field(3; "Extension Point"; Code[50]) { Access = Protected; } // Table extensions
        field(4; "Internal Counter"; Integer) { Access = Local; }    // This table only
    }
}
```

## Access Level Summary

| Level       | Same Table | Table Extension | Same App | Other Apps |
|-------------|------------|-----------------|----------|------------|
| `Local`     | ✓          |                 |          |            |
| `Protected` | ✓          | ✓               |          |            |
| `Internal`  | ✓          | ✓               | ✓        |            |
| `Public`    | ✓          | ✓               | ✓        | ✓          |

**Designer note:** Only `Public` fields appear in in-client Designer.

### Step 3: Configure internalsVisibleTo (Multi-App)

In `app.json` of the core app:

```json
{
    "internalsVisibleTo": [
        { "id": "<companion-app-guid>", "name": "Companion App", "publisher": "My Publisher" },
        { "id": "<test-app-guid>", "name": "Test App", "publisher": "My Publisher" }
    ]
}
```

**Use cases:** Core + Companion apps, Test apps accessing internals, Modular architecture.

## Important Notes

**⚠️ NOT a security boundary:** Access is compile-time only. RecordRef/FieldRef bypass at runtime. Use permission sets for data security.

## Design Patterns

### Public API + Internal Implementation

```al
codeunit <ID> "<PREFIX> Public API"
{
    Access = Public;
    procedure ProcessOperation(InputData: Text): Boolean
    begin
        exit(InternalProcessor.DoProcess(InputData));
    end;
    var
        InternalProcessor: Codeunit "<PREFIX> Internal Processor";
}

codeunit <ID+1> "<PREFIX> Internal Processor"
{
    Access = Internal;
    procedure DoProcess(InputData: Text): Boolean
    begin
        // Can be refactored freely - not exposed
    end;
}
```

### Secret Management

```al
codeunit <ID> "<PREFIX> Secret Manager"
{
    Access = Internal;
    [NonDebuggable]
    procedure GetClientSecret(): Text
    begin
        // Use IsolatedStorage with DataScope::Module
    end;
}
```

## Quick Reference

| Scenario | Recommended Access |
|----------|-------------------|
| Stable API for partners | `Public` |
| Helper codeunits | `Internal` |
| Staging/buffer tables | `Internal` |
| Fields for table extensions | `Protected` |
| Fields in table triggers only | `Local` |
| Secret management | `Internal` + `[NonDebuggable]` |

**Guidelines:** Default to Internal • Public = supported contract • Changing Public → Internal is breaking

**Limitations:** Cannot set on Pages, Reports, XMLports, Control add-ins.

## External Documentation

- [Access Property](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/properties/devenv-access-property)
- [Access Modifiers](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-using-access-modifiers)
- [internalsVisibleTo](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-json-files#appjson-file)
