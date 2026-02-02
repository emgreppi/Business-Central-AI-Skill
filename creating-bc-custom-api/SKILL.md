---
name: creating-bc-custom-api
description: Creates custom API pages (CRUD) and API queries (read-only joins) in AL for Business Central. Use when exposing custom tables, adding business logic to APIs, creating reporting endpoints, or joining multiple tables for external consumption.
license: MIT
metadata:
  version: 1.0.0
---

# Skill: Creating BC Custom APIs

## Key Concept

| Type | Object | Operations | Use Case |
|------|--------|------------|----------|
| **API Page** | `PageType = API` | CRUD (Read-Write) | Expose single table |
| **API Query** | `QueryType = API` | Read-only | Join multiple tables |

**For consuming Microsoft standard APIs**, use `al-standard-api` skill instead.

## Validation Gates

1. **After Step 2**: API page compiles, GET returns 200 with fields
2. **After Step 3**: Subpage works, navigation property expands correctly
3. **Final**: All CRUD operations work (GET 200, POST 201, PATCH 200, DELETE 204)

**Note:** OData UI endpoints deprecated BC30 (2027). Always use API pages.

## Placeholder Reference

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `<ID>` | Object ID from app.json idRanges | `50100` |
| `<PREFIX>` | Company prefix from app.json | `SL`, `ABC` |
| `<SourceTable>` | Source table name | `"Rental Machine"` |
| `<entityName>` | Singular entity name (camelCase) | `rentalMachine` |
| `<entitySetName>` | Plural entity name (camelCase) | `rentalMachines` |
| `<publisher>` | APIPublisher value | `contoso` |
| `<group>` | APIGroup value | `rental` |
| `<KeyField>` | Primary key field | `"No."` |
| `<Field1>`, `<Field2>` | Table fields to expose | `"Description"`, `"Status"` |

## Procedure

### Step 1: Decide API Type

**Use API Page when:**
- Need CRUD operations (Create, Read, Update, Delete)
- Exposing a single table
- Need to execute business logic on insert/modify

**Use API Query when:**
- Read-only access sufficient
- Need to join multiple tables
- Reporting/analytics endpoint

### Step 2: Create API Page (CRUD)

```al
page <ID> "<PREFIX> API <EntityName>"
{
    APIGroup = '<group>';
    APIPublisher = '<publisher>';
    APIVersion = 'v2.0';
    EntityName = '<entityName>';
    EntitySetName = '<entitySetName>';
    EntityCaption = '<Entity Display Name>';
    EntitySetCaption = '<Entities Display Name>';
    PageType = API;
    SourceTable = <SourceTable>;
    DelayedInsert = true;
    ODataKeyFields = SystemId;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field(id; Rec.SystemId)
                {
                    Caption = 'ID';
                    Editable = false;
                }
                field(<fieldApiName1>; Rec.<KeyField>)
                {
                    Caption = '<Field1 Caption>';
                }
                field(<fieldApiName2>; Rec.<Field1>)
                {
                    Caption = '<Field2 Caption>';
                }
                field(<fieldApiName3>; Rec.<Field2>)
                {
                    Caption = '<Field3 Caption>';
                    Editable = false;  // Calculated fields
                }
                field(lastModifiedDateTime; Rec.SystemModifiedAt)
                {
                    Caption = 'Last Modified';
                    Editable = false;
                }
            }
        }
    }

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    begin
        // Optional: Set default values or execute business logic
        Rec.Insert(true);
        exit(false);  // Return false to prevent double insert
    end;
}
```

### Step 3: Add Navigation Property (Lines/Details)

For header-line relationships, add a `part` to the parent API page:

```al
layout
{
    area(Content)
    {
        repeater(General)
        {
            // ... header fields ...
        }
        part(<entityName>Lines; "<PREFIX> API <EntityName> Lines")
        {
            EntityName = '<entityName>Line';
            EntitySetName = '<entityName>Lines';
            SubPageLink = <ParentKeyField> = field(<KeyField>);
        }
    }
}
```

**Subpage (Lines):**

```al
page <ID+1> "<PREFIX> API <EntityName> Lines"
{
    APIGroup = '<group>';
    APIPublisher = '<publisher>';
    APIVersion = 'v2.0';
    EntityName = '<entityName>Line';
    EntitySetName = '<entityName>Lines';
    PageType = API;
    SourceTable = <LineSourceTable>;
    DelayedInsert = true;
    ODataKeyFields = SystemId;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field(id; Rec.SystemId) { Editable = false; }
                field(<parentKeyApiName>; Rec.<ParentKeyField>) { }
                field(lineNo; Rec."Line No.") { }
                // ... other line fields ...
            }
        }
    }
}
```

### Step 4: Create API Query (Read-Only Joins)

```al
query <ID> "<PREFIX> API <QueryName>"
{
    QueryType = API;
    APIPublisher = '<publisher>';
    APIGroup = '<group>';
    APIVersion = 'v2.0';
    EntityName = '<entityName>';
    EntitySetName = '<entitySetName>';

    elements
    {
        dataitem(<HeaderAlias>; <HeaderTable>)
        {
            column(id; SystemId) { }
            column(<headerField1>; <KeyField>) { }
            column(<headerField2>; <Field1>) { }

            dataitem(<LineAlias>; <LineTable>)
            {
                DataItemLink = <LinkField> = <HeaderAlias>.<KeyField>;
                SqlJoinType = InnerJoin;  // or LeftOuterJoin

                column(lineNo; "Line No.") { }
                column(<lineField1>; <LineField1>) { }
                column(<lineField2>; <LineField2>) { }
            }
        }
    }
}
```

## Required Properties

| Property | Required | Description |
|----------|----------|-------------|
| `APIPublisher` | Yes | Your company/publisher name |
| `APIGroup` | Yes | Logical grouping |
| `APIVersion` | Yes | `v2.0` recommended, `beta` for development |
| `EntityName` | Yes | Singular, camelCase |
| `EntitySetName` | Yes | Plural, camelCase |
| `ODataKeyFields` | Yes | Always use `SystemId` |
| `PageType`/`QueryType` | Yes | `API` |
| `DelayedInsert` | Recommended | `true` for API pages |

## API URL Structure

**Custom API endpoint:**
```
https://api.businesscentral.dynamics.com/v2.0/<TenantID>/<Environment>/api/<publisher>/<group>/<version>/companies(<CompanyID>)/<entitySetName>
```

**Example:**
```
https://api.businesscentral.dynamics.com/v2.0/contoso.com/Production/api/contoso/rental/v2.0/companies(xxx)/rentalMachines
```

## Schema Version 2.0 (BC v24+)

Starting BC v24, enum values are returned as XML-encoded names instead of captions:

- `Open` becomes `Open`
- `Return Order` becomes `Return_x0020_Order`

**Solutions:**
1. Add `?$schemaversion=1.0` to requests for old behavior
2. Handle XML encoding in client code

## Best Practices

1. **Always use `ODataKeyFields = SystemId`** - stable across renames
2. **Use `EntityCaption`/`EntitySetCaption`** - for localization at `/entityDefinitions`
3. **camelCase for API names** - `rentalMachine` not `RentalMachine`
4. **Alphanumeric only** - no special characters in field names
5. **Version your APIs** - `v1.0`, `v2.0`, or `beta`
6. **Include `SystemModifiedAt`** - enables delta sync with `$filter`
7. **`DelayedInsert = true`** - prevents partial record creation

## CRUD Control

Make API read-only:

```al
page <ID> "<PREFIX> API Read Only"
{
    PageType = API;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
}
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| 400 | Invalid field name | Check camelCase, no spaces |
| 404 | Entity not found | Verify `ODataKeyFields = SystemId`, entity names |
| 500 | Server error | Check `OnInsertRecord` trigger, BC event log |
| API not visible | Not published | Restart service tier, check compilation |

**Feedback loop:** Fix issue → Recompile → Test GET first → Then test POST/PATCH/DELETE.

## References

See `references/` folder for:
- `api-page-template.al` - Complete AL template for API Page (CRUD), Subpage (Lines), and Read-Only API
- `api-query-template.al` - Complete AL template for API Query with join examples

## External Documentation

- [Microsoft: Developing Custom API](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-develop-custom-api)
- [Microsoft: API Page Type](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-api-pagetype)
- [Microsoft: API Query Type](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-api-querytype)
- [GitHub: APIV2 Examples](https://github.com/microsoft/ALAppExtensions/tree/main/Apps/W1/APIV2/app/src/pages)
- [Kauffmann: Schema Version 2.0](https://www.kauffmann.nl/2024/08/22/custom-apis-and-schemaversion-2-0/)
