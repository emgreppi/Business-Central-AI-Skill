// =============================================================================
// API Query Template (Read-Only, Join Multiple Tables)
// =============================================================================
// Replace all <placeholders> with your actual values before use.
// See placeholder reference table in SKILL.md for descriptions.
//
// API Query is READ-ONLY - use for:
// - Joining multiple tables (header + lines, master + details)
// - Reporting/analytics endpoints
// - Aggregated data views
// =============================================================================

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
            // System ID for the header record
            column(id; SystemId) { }

            // Header fields
            column(<headerKeyApiName>; <KeyField>) { }
            column(<headerField1ApiName>; <HeaderField1>) { }
            column(<headerField2ApiName>; <HeaderField2>) { }

            // Nested dataitem for related lines
            dataitem(<LineAlias>; <LineTable>)
            {
                // Join condition
                DataItemLink = <LinkField> = <HeaderAlias>.<KeyField>;

                // Join type: InnerJoin (only matching), LeftOuterJoin (all headers)
                SqlJoinType = InnerJoin;

                // Line fields
                column(lineNo; "Line No.") { }
                column(<lineField1ApiName>; <LineField1>) { }
                column(<lineField2ApiName>; <LineField2>) { }
            }
        }
    }
}


// =============================================================================
// Example: Sales Order Summary Query
// =============================================================================
// Joins Sales Header with Sales Lines for a flat reporting view
// =============================================================================

query <ID+1> "<PREFIX> API Sales Summary"
{
    QueryType = API;
    APIPublisher = '<publisher>';
    APIGroup = '<group>';
    APIVersion = 'v2.0';
    EntityName = 'salesSummary';
    EntitySetName = 'salesSummaries';

    elements
    {
        dataitem(SalesHeader; "Sales Header")
        {
            DataItemTableFilter = "Document Type" = const(Order);

            column(id; SystemId) { }
            column(documentType; "Document Type") { }
            column(number; "No.") { }
            column(customerNumber; "Sell-to Customer No.") { }
            column(customerName; "Sell-to Customer Name") { }
            column(orderDate; "Order Date") { }
            column(status; Status) { }

            dataitem(SalesLine; "Sales Line")
            {
                DataItemLink = "Document Type" = SalesHeader."Document Type",
                               "Document No." = SalesHeader."No.";
                SqlJoinType = LeftOuterJoin;

                column(lineNo; "Line No.") { }
                column(itemNo; "No.") { }
                column(description; Description) { }
                column(quantity; Quantity) { }
                column(unitPrice; "Unit Price") { }
                column(lineAmount; "Line Amount") { }
            }
        }
    }
}


// =============================================================================
// Example: Customer with Open Orders Query
// =============================================================================
// Joins Customer with their open Sales Orders
// =============================================================================

query <ID+2> "<PREFIX> API Customer Orders"
{
    QueryType = API;
    APIPublisher = '<publisher>';
    APIGroup = '<group>';
    APIVersion = 'v2.0';
    EntityName = 'customerOrder';
    EntitySetName = 'customerOrders';

    elements
    {
        dataitem(Customer; Customer)
        {
            column(customerId; SystemId) { }
            column(customerNumber; "No.") { }
            column(customerName; Name) { }
            column(email; "E-Mail") { }
            column(balance; Balance) { }

            dataitem(SalesHeader; "Sales Header")
            {
                DataItemLink = "Sell-to Customer No." = Customer."No.";
                DataItemTableFilter = "Document Type" = const(Order),
                                      Status = const(Open);
                SqlJoinType = LeftOuterJoin;

                column(orderNumber; "No.") { }
                column(orderDate; "Order Date") { }
                column(amount; "Amount Including VAT") { }
            }
        }
    }
}


// =============================================================================
// Example: Inventory Summary Query (Aggregation)
// =============================================================================
// Items with inventory levels across locations
// =============================================================================

query <ID+3> "<PREFIX> API Inventory Summary"
{
    QueryType = API;
    APIPublisher = '<publisher>';
    APIGroup = '<group>';
    APIVersion = 'v2.0';
    EntityName = 'inventorySummary';
    EntitySetName = 'inventorySummaries';

    elements
    {
        dataitem(Item; Item)
        {
            DataItemTableFilter = Type = const(Inventory);

            column(itemId; SystemId) { }
            column(itemNumber; "No.") { }
            column(description; Description) { }
            column(unitPrice; "Unit Price") { }
            column(inventory; Inventory) { }

            dataitem(ItemLedgerEntry; "Item Ledger Entry")
            {
                DataItemLink = "Item No." = Item."No.";
                SqlJoinType = LeftOuterJoin;

                column(locationCode; "Location Code") { }
                column(quantity; Quantity)
                {
                    Method = Sum;
                }
            }
        }
    }
}


// =============================================================================
// Notes on API Query
// =============================================================================
//
// 1. API Query is READ-ONLY - no POST/PATCH/DELETE operations
//
// 2. SqlJoinType options:
//    - InnerJoin: Only returns records that have matches in both tables
//    - LeftOuterJoin: Returns all header records, with null for unmatched lines
//
// 3. Column Method options (for aggregation):
//    - Sum: Sum of values
//    - Count: Count of records
//    - Average: Average of values
//    - Min: Minimum value
//    - Max: Maximum value
//
// 4. DataItemTableFilter: Static filter applied at compile time
//
// 5. Cannot use in UI (pages) - API only
//
// =============================================================================
