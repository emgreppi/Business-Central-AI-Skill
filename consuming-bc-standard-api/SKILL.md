---
name: consuming-bc-standard-api
description: Consumes Microsoft standard Business Central APIs (v2.0) for customers, vendors, items, salesOrders, and other built-in entities. No AL coding required. Use when integrating external systems with BC data, building Power Automate flows, or querying BC from Postman/scripts.
license: MIT
metadata:
  version: 1.0.0
---

# Skill: Consuming BC Standard APIs

## Key Concept

**Standard APIs** are maintained by Microsoft and expose common BC entities. No AL coding required - just authenticate and call the endpoints.

**For custom data or business logic**, use `al-custom-api` skill instead.

## Validation Gates

1. **After Step 1**: OAuth token acquired successfully
2. **After Step 2**: GET /companies returns company list
3. **Final**: CRUD operations work on target entity

## Available Entities (API v2.0)

| Entity | Endpoint | Operations |
|--------|----------|------------|
| Companies | `/companies` | GET |
| Customers | `/customers` | GET, POST, PATCH, DELETE |
| Vendors | `/vendors` | GET, POST, PATCH, DELETE |
| Items | `/items` | GET, POST, PATCH, DELETE |
| Sales Orders | `/salesOrders` | GET, POST, PATCH, DELETE |
| Sales Invoices | `/salesInvoices` | GET, POST, PATCH, DELETE |
| Purchase Orders | `/purchaseOrders` | GET, POST, PATCH, DELETE |
| Purchase Invoices | `/purchaseInvoices` | GET, POST, PATCH, DELETE |
| General Ledger Entries | `/generalLedgerEntries` | GET |
| Accounts | `/accounts` | GET |
| Dimensions | `/dimensions` | GET |
| Employees | `/employees` | GET, POST, PATCH, DELETE |
| Journal Lines | `/journalLines` | GET, POST, PATCH, DELETE |

**Full list:** [Microsoft API v2.0 Reference](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/api-reference/v2.0/)

## Procedure

### Step 1: Authenticate

**Prerequisite:** Azure AD App Registration with `Dynamics 365 Business Central` API permissions.

See `al-oauth-integration` skill for token acquisition patterns.

**Token endpoint:**
```
POST https://login.microsoftonline.com/<TenantID>/oauth2/v2.0/token

grant_type=client_credentials
client_id=<ClientID>
client_secret=<ClientSecret>
scope=https://api.businesscentral.dynamics.com/.default
```

### Step 2: Understand URL Structure

**Base URL pattern:**
```
https://api.businesscentral.dynamics.com/v2.0/<TenantID>/<Environment>/api/v2.0
```

**With company:**
```
https://api.businesscentral.dynamics.com/v2.0/<TenantID>/<Environment>/api/v2.0/companies(<CompanyID>)/<Entity>
```

### Placeholder Reference

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `<TenantID>` | Azure AD tenant ID (GUID) | `12345678-1234-1234-1234-123456789abc` |
| `<Environment>` | BC environment name | `Production`, `Sandbox` |
| `<CompanyID>` | Company SystemId (GUID) | `87654321-4321-4321-4321-cba987654321` |
| `<Entity>` | API entity name (camelCase plural) | `customers`, `salesOrders` |
| `<EntityID>` | Record SystemId (GUID) | `11111111-2222-3333-4444-555555555555` |

### Step 3: Common Operations

**GET all companies:**
```http
GET /api/v2.0/companies
Authorization: Bearer <token>
```

**GET all customers (with $select):**
```http
GET /api/v2.0/companies(<CompanyID>)/customers?$select=id,number,displayName,email
Authorization: Bearer <token>
```

**GET single customer:**
```http
GET /api/v2.0/companies(<CompanyID>)/customers(<EntityID>)
Authorization: Bearer <token>
```

**POST new customer:**
```http
POST /api/v2.0/companies(<CompanyID>)/customers
Authorization: Bearer <token>
Content-Type: application/json

{
  "displayName": "New Customer",
  "email": "customer@example.com",
  "currencyCode": "EUR"
}
```

**PATCH update customer:**
```http
PATCH /api/v2.0/companies(<CompanyID>)/customers(<EntityID>)
Authorization: Bearer <token>
Content-Type: application/json
If-Match: *

{
  "email": "updated@example.com"
}
```

**DELETE customer:**
```http
DELETE /api/v2.0/companies(<CompanyID>)/customers(<EntityID>)
Authorization: Bearer <token>
If-Match: *
```

### Step 4: OData Query Options

**$select** - Limit returned fields (ALWAYS use for performance):
```
?$select=id,number,displayName
```

**$filter** - Filter results:
```
?$filter=displayName eq 'Contoso'
?$filter=lastModifiedDateTime gt 2024-01-01T00:00:00Z
?$filter=contains(displayName,'Smith')
```

**$filter with IN operator (BC24+):**

Requires `$schemaversion=2.1` in URL:
```
?$schemaversion=2.1&$filter=number in ('10000', '20000', '30000')
```
Without `$schemaversion=2.1`, returns error `BadRequest_MethodNotImplemented`.

**$expand** - Include related entities:
```
?$expand=salesOrderLines
?$expand=customer($select=displayName,email)
```

**Filter inside $expand:**
```
?$expand=salesOrderLines($filter=lineType eq 'Item')
```
Note: Use parentheses `()` around the nested query options.

**Multi-level expand:**
```
?$expand=salesOrderLines($expand=item($expand=itemCategory))
```

**$orderby** - Sort results:
```
?$orderby=displayName
?$orderby=lastModifiedDateTime desc
```

**$count** - Get total count:
```
/salesOrders/$count
```
Returns integer count of matching records.

### Step 5: Handle Pagination

BC uses **server-driven paging** with `@odata.nextLink`:

```json
{
  "@odata.context": "...",
  "value": [...],
  "@odata.nextLink": "https://api.../customers?$skiptoken=..."
}
```

**Pattern:**
1. Make initial request
2. Process `value` array
3. If `@odata.nextLink` exists, request that URL
4. Repeat until no more `@odata.nextLink`

**Do NOT use `$top` + `$skip`** for paging - poor performance.

## Rate Limits

| Environment | Limit |
|-------------|-------|
| BC Online | 600 requests/minute |
| BC On-Premises | Configurable |

HTTP 429 = Too Many Requests → implement exponential backoff.

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| 401 | Invalid/expired token | Refresh OAuth token |
| 403 | Missing permissions | Check Azure AD API permissions |
| 404 | Entity not found | Verify CompanyID and EntityID |
| 400 | Invalid request | Check JSON body, field names (camelCase) |
| 429 | Rate limited | Implement backoff, reduce request frequency |

## Important Notes

- **Standard APIs are NOT extensible** - you cannot add custom fields
- **Use $select always** - tables may have extensions adding many fields
- **Field names are camelCase** - `displayName` not `Display Name`
- **SystemId is the key** - all entities use GUID as primary key
- **If-Match required** for PATCH/DELETE - use `*` or actual ETag

## References

See `references/` folder for:
- `http-examples.md` - Complete HTTP request examples for all standard entities (customers, vendors, items, sales orders, etc.)

## External Documentation

- [Microsoft: API v2.0 Reference](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/api-reference/v2.0/)
- [Microsoft: API Overview](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/api-reference/v2.0/api/dynamics-overview)
- [Microsoft: OData Query Options](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/webservices/odata-client-performance)
- [Microsoft: Authentication](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/webservices/web-services-authentication)
