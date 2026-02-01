// =============================================================================
// API Page Template (CRUD Operations)
// =============================================================================
// Replace all <placeholders> with your actual values before use.
// See placeholder reference table in SKILL.md for descriptions.
// =============================================================================

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
                // System ID - Always include, never editable
                field(id; Rec.SystemId)
                {
                    Caption = 'ID';
                    Editable = false;
                }

                // Primary key field
                field(<keyFieldApiName>; Rec.<KeyField>)
                {
                    Caption = '<Key Field Caption>';
                }

                // Regular fields - add as needed
                field(<field1ApiName>; Rec.<Field1>)
                {
                    Caption = '<Field1 Caption>';
                }

                field(<field2ApiName>; Rec.<Field2>)
                {
                    Caption = '<Field2 Caption>';
                }

                // Calculated/FlowField - mark as not editable
                field(<calculatedFieldApiName>; Rec.<CalculatedField>)
                {
                    Caption = '<Calculated Field Caption>';
                    Editable = false;
                }

                // System timestamp - for delta sync
                field(lastModifiedDateTime; Rec.SystemModifiedAt)
                {
                    Caption = 'Last Modified';
                    Editable = false;
                }
            }

            // Navigation property for related lines (1-N relationship)
            // Uncomment and configure if you have a header-line structure
            /*
            part(<entityName>Lines; "<PREFIX> API <EntityName> Lines")
            {
                EntityName = '<entityName>Line';
                EntitySetName = '<entityName>Lines';
                SubPageLink = <ParentKeyField> = field(<KeyField>);
            }
            */
        }
    }

    // Optional: Set default values or execute business logic on insert
    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    begin
        // Example: Set document type for sales/purchase documents
        // Rec."Document Type" := Rec."Document Type"::Order;

        Rec.Insert(true);
        exit(false); // Return false to prevent double insert
    end;

    // Optional: Execute business logic on modify
    trigger OnModifyRecord(): Boolean
    begin
        Rec.Modify(true);
        exit(false); // Return false to prevent double modify
    end;

    // Optional: For read-committed isolation (Power BI compatibility)
    /*
    trigger OnOpenPage()
    begin
        Rec.ReadIsolation := IsolationLevel::ReadCommitted;
    end;
    */
}


// =============================================================================
// Subpage Template (Lines - for 1-N relationships)
// =============================================================================
// Use this when you have header-line structures (e.g., Order Header + Order Lines)
// =============================================================================

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
                field(id; Rec.SystemId)
                {
                    Caption = 'ID';
                    Editable = false;
                }

                // Parent reference field
                field(<parentKeyApiName>; Rec.<ParentKeyField>)
                {
                    Caption = '<Parent Key Caption>';
                }

                // Line number
                field(lineNo; Rec."Line No.")
                {
                    Caption = 'Line No.';
                }

                // Line-specific fields
                field(<lineField1ApiName>; Rec.<LineField1>)
                {
                    Caption = '<Line Field1 Caption>';
                }

                field(<lineField2ApiName>; Rec.<LineField2>)
                {
                    Caption = '<Line Field2 Caption>';
                }

                field(lastModifiedDateTime; Rec.SystemModifiedAt)
                {
                    Caption = 'Last Modified';
                    Editable = false;
                }
            }
        }
    }
}


// =============================================================================
// Read-Only API Page Template
// =============================================================================
// Use when you only need GET operations (no POST/PATCH/DELETE)
// =============================================================================

page <ID+2> "<PREFIX> API <EntityName> ReadOnly"
{
    APIGroup = '<group>';
    APIPublisher = '<publisher>';
    APIVersion = 'v2.0';
    EntityName = '<entityName>';
    EntitySetName = '<entitySetName>';
    PageType = API;
    SourceTable = <SourceTable>;
    ODataKeyFields = SystemId;

    // Disable all write operations
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field(id; Rec.SystemId) { Editable = false; }
                field(<keyFieldApiName>; Rec.<KeyField>) { }
                field(<field1ApiName>; Rec.<Field1>) { }
                // Add more fields as needed
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.ReadIsolation := IsolationLevel::ReadCommitted;
    end;
}
