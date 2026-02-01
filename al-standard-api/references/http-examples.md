# HTTP Examples for BC Standard APIs

Common HTTP request examples for Microsoft standard Business Central APIs.

---

## Authentication Header

All requests require OAuth 2.0 Bearer token:

```http
Authorization: Bearer <access_token>
```

See `al-oauth-integration` skill for token acquisition.

---

## Get Companies

```http
GET https://api.businesscentral.dynamics.com/v2.0/<TenantID>/<Environment>/api/v2.0/companies
Authorization: Bearer <token>
```

**Response:**
```json
{
  "value": [
    {
      "id": "12345678-1234-1234-1234-123456789abc",
      "systemVersion": "...",
      "name": "CRONUS International Ltd.",
      "displayName": "CRONUS International Ltd.",
      "businessProfileId": ""
    }
  ]
}
```

---

## Customers

### GET All Customers (with $select)

```http
GET https://api.businesscentral.dynamics.com/v2.0/<TenantID>/<Environment>/api/v2.0/companies(<CompanyID>)/customers?$select=id,number,displayName,email
Authorization: Bearer <token>
```

### GET Single Customer

```http
GET https://api.businesscentral.dynamics.com/v2.0/<TenantID>/<Environment>/api/v2.0/companies(<CompanyID>)/customers(<CustomerID>)
Authorization: Bearer <token>
```

### POST Create Customer

```http
POST https://api.businesscentral.dynamics.com/v2.0/<TenantID>/<Environment>/api/v2.0/companies(<CompanyID>)/customers
Authorization: Bearer <token>
Content-Type: application/json

{
  "displayName": "New Customer Ltd.",
  "email": "customer@example.com",
  "currencyCode": "EUR",
  "paymentTermsId": "00000000-0000-0000-0000-000000000000"
}
```

### PATCH Update Customer

```http
PATCH https://api.businesscentral.dynamics.com/v2.0/<TenantID>/<Environment>/api/v2.0/companies(<CompanyID>)/customers(<CustomerID>)
Authorization: Bearer <token>
Content-Type: application/json
If-Match: *

{
  "email": "updated@example.com",
  "phoneNumber": "+39 02 1234567"
}
```

### DELETE Customer

```http
DELETE https://api.businesscentral.dynamics.com/v2.0/<TenantID>/<Environment>/api/v2.0/companies(<CompanyID>)/customers(<CustomerID>)
Authorization: Bearer <token>
If-Match: *
```

---

## Vendors

### GET All Vendors

```http
GET https://api.businesscentral.dynamics.com/v2.0/<TenantID>/<Environment>/api/v2.0/companies(<CompanyID>)/vendors?$select=id,number,displayName,email,currencyCode
Authorization: Bearer <token>
```

### POST Create Vendor

```http
POST https://api.businesscentral.dynamics.com/v2.0/<TenantID>/<Environment>/api/v2.0/companies(<CompanyID>)/vendors
Authorization: Bearer <token>
Content-Type: application/json

{
  "displayName": "New Vendor S.r.l.",
  "email": "vendor@example.com",
  "currencyCode": "EUR"
}
```

---

## Items

### GET All Items

```http
GET https://api.businesscentral.dynamics.com/v2.0/<TenantID>/<Environment>/api/v2.0/companies(<CompanyID>)/items?$select=id,number,displayName,unitPrice,inventory
Authorization: Bearer <token>
```

### GET Items with Filter

```http
GET https://api.businesscentral.dynamics.com/v2.0/<TenantID>/<Environment>/api/v2.0/companies(<CompanyID>)/items?$filter=inventory gt 0&$select=number,displayName,inventory
Authorization: Bearer <token>
```

### POST Create Item

```http
POST https://api.businesscentral.dynamics.com/v2.0/<TenantID>/<Environment>/api/v2.0/companies(<CompanyID>)/items
Authorization: Bearer <token>
Content-Type: application/json

{
  "number": "ITEM-001",
  "displayName": "New Product",
  "type": "Inventory",
  "unitPrice": 99.00,
  "baseUnitOfMeasureCode": "PCS"
}
```

---

## Sales Orders

### GET Sales Orders with Lines ($expand)

```http
GET https://api.businesscentral.dynamics.com/v2.0/<TenantID>/<Environment>/api/v2.0/companies(<CompanyID>)/salesOrders?$expand=salesOrderLines&$select=id,number,orderDate,status
Authorization: Bearer <token>
```

### GET Open Sales Orders

```http
GET https://api.businesscentral.dynamics.com/v2.0/<TenantID>/<Environment>/api/v2.0/companies(<CompanyID>)/salesOrders?$filter=status eq 'Open'&$select=number,customerNumber,orderDate,totalAmountIncludingTax
Authorization: Bearer <token>
```

### POST Create Sales Order with Lines (Deep Insert)

```http
POST https://api.businesscentral.dynamics.com/v2.0/<TenantID>/<Environment>/api/v2.0/companies(<CompanyID>)/salesOrders
Authorization: Bearer <token>
Content-Type: application/json

{
  "customerNumber": "10000",
  "orderDate": "2026-02-01",
  "salesOrderLines": [
    {
      "lineType": "Item",
      "itemId": "11111111-1111-1111-1111-111111111111",
      "quantity": 5,
      "unitPrice": 100.00
    },
    {
      "lineType": "Item",
      "itemId": "22222222-2222-2222-2222-222222222222",
      "quantity": 2,
      "unitPrice": 250.00
    }
  ]
}
```

---

## Sales Invoices

### GET Posted Sales Invoices

```http
GET https://api.businesscentral.dynamics.com/v2.0/<TenantID>/<Environment>/api/v2.0/companies(<CompanyID>)/salesInvoices?$filter=status eq 'Paid'&$select=number,customerName,totalAmountIncludingTax,dueDate
Authorization: Bearer <token>
```

---

## Purchase Orders

### GET Purchase Orders

```http
GET https://api.businesscentral.dynamics.com/v2.0/<TenantID>/<Environment>/api/v2.0/companies(<CompanyID>)/purchaseOrders?$select=id,number,vendorNumber,orderDate,status
Authorization: Bearer <token>
```

---

## OData Query Options

### $filter Examples

```http
# Equal
?$filter=status eq 'Open'

# Not equal
?$filter=status ne 'Released'

# Greater than (dates)
?$filter=orderDate gt 2026-01-01

# Contains (string)
?$filter=contains(displayName,'Smith')

# Multiple conditions
?$filter=status eq 'Open' and totalAmountIncludingTax gt 1000

# In operator
?$filter=status in ('Open','Released')
```

### $select Examples

```http
# Specific fields only
?$select=id,number,displayName,email
```

### $expand Examples

```http
# Include related entity
?$expand=salesOrderLines

# Expand with nested select
?$expand=customer($select=displayName,email)

# Expand with nested filter
?$expand=salesOrderLines($filter=quantity gt 5)
```

### $orderby Examples

```http
# Ascending
?$orderby=displayName

# Descending
?$orderby=lastModifiedDateTime desc
```

---

## Pagination (@odata.nextLink)

BC uses server-driven paging. Response includes `@odata.nextLink` for next page:

```json
{
  "@odata.context": "...",
  "value": [...],
  "@odata.nextLink": "https://api.../customers?$skiptoken=..."
}
```

**Pattern:**
1. Request initial URL
2. Process `value` array
3. If `@odata.nextLink` exists, request that URL
4. Repeat until no `@odata.nextLink`

---

## HTTP Status Codes

| Code | Meaning | Action |
|------|---------|--------|
| 200 | OK (GET, PATCH) | Success |
| 201 | Created (POST) | Success |
| 204 | No Content (DELETE) | Success |
| 400 | Bad Request | Check JSON body, field names |
| 401 | Unauthorized | Refresh OAuth token |
| 403 | Forbidden | Check API permissions |
| 404 | Not Found | Verify IDs, entity name |
| 429 | Too Many Requests | Implement backoff (600 req/min limit) |

---

## References

- [Microsoft: API v2.0 Reference](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/api-reference/v2.0/)
- [Microsoft: OData Query Options](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/webservices/odata-client-performance)
