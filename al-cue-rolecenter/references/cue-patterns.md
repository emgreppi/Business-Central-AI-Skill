# Cue and Role Center Patterns

## Complete Example: Sales Order Status Cues

### 1. Cue Table

```al
namespace MyCompany.MyApp.Tables;

using Microsoft.Sales.Document;

/// <summary>
/// Cue table for order statistics displayed in RoleCenter Activities.
/// Contains FlowFields that calculate counts of orders by status.
/// </summary>
table 50100 "MC Order Cue"
{
    Caption = 'Order Cue';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
            DataClassification = SystemMetadata;
        }

        field(10; "New Orders"; Integer)
        {
            CalcFormula = count("Sales Header" where(
                "Document Type" = const(Order),
                "MC From Integration" = const(true),
                "MC Order Status" = const(New)));
            Caption = 'New Orders';
            ToolTip = 'Number of new orders not yet processed';
            Editable = false;
            FieldClass = FlowField;
        }

        field(15; "In Progress Orders"; Integer)
        {
            CalcFormula = count("Sales Header" where(
                "Document Type" = const(Order),
                "MC From Integration" = const(true),
                "MC Order Status" = const(In_Progress)));
            Caption = 'In Progress Orders';
            ToolTip = 'Number of orders currently being processed';
            Editable = false;
            FieldClass = FlowField;
        }

        field(20; "Ready Orders"; Integer)
        {
            CalcFormula = count("Sales Header" where(
                "Document Type" = const(Order),
                "MC From Integration" = const(true),
                "MC Order Status" = const(Ready)));
            Caption = 'Ready Orders';
            ToolTip = 'Number of orders ready for shipment';
            Editable = false;
            FieldClass = FlowField;
        }

        field(30; "Shipped Orders"; Integer)
        {
            CalcFormula = count("Sales Header" where(
                "Document Type" = const(Order),
                "MC From Integration" = const(true),
                "MC Order Status" = const(Shipped)));
            Caption = 'Shipped Orders';
            ToolTip = 'Number of orders that have been shipped';
            Editable = false;
            FieldClass = FlowField;
        }

        field(40; "Error Orders"; Integer)
        {
            CalcFormula = count("Sales Header" where(
                "Document Type" = const(Order),
                "MC From Integration" = const(true),
                "MC Order Status" = const(Error)));
            Caption = 'Error Orders';
            ToolTip = 'Number of orders with errors that need attention';
            Editable = false;
            FieldClass = FlowField;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }
}
```

### 2. Activities Page (CardPart)

```al
namespace MyCompany.MyApp.Pages;

using MyCompany.MyApp.Tables;
using Microsoft.Sales.Document;

/// <summary>
/// Activities CardPart displaying order statistics.
/// Shows cues for orders by status from integration.
/// </summary>
page 50100 "MC Order Activities"
{
    Caption = 'Integration Orders';
    PageType = CardPart;
    RefreshOnActivate = true;
    SourceTable = "MC Order Cue";

    layout
    {
        area(content)
        {
            cuegroup(OrderStatus)
            {
                Caption = 'Order Status';

                field("New Orders"; Rec."New Orders")
                {
                    ApplicationArea = All;
                    DrillDownPageID = "Sales Order List";
                    ToolTip = 'Number of new orders not yet processed';
                    // Default style (blue)

                    trigger OnDrillDown()
                    var
                        SalesHeader: Record "Sales Header";
                    begin
                        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
                        SalesHeader.SetRange("MC From Integration", true);
                        SalesHeader.SetRange("MC Order Status", SalesHeader."MC Order Status"::New);
                        Page.Run(Page::"Sales Order List", SalesHeader);
                    end;
                }

                field("In Progress Orders"; Rec."In Progress Orders")
                {
                    ApplicationArea = All;
                    DrillDownPageID = "Sales Order List";
                    ToolTip = 'Number of orders currently being processed';
                    Style = Attention;  // Yellow - needs attention

                    trigger OnDrillDown()
                    var
                        SalesHeader: Record "Sales Header";
                    begin
                        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
                        SalesHeader.SetRange("MC From Integration", true);
                        SalesHeader.SetRange("MC Order Status", SalesHeader."MC Order Status"::In_Progress);
                        Page.Run(Page::"Sales Order List", SalesHeader);
                    end;
                }

                field("Ready Orders"; Rec."Ready Orders")
                {
                    ApplicationArea = All;
                    DrillDownPageID = "Sales Order List";
                    ToolTip = 'Number of orders ready for shipment';
                    Style = Favorable;  // Green - positive

                    trigger OnDrillDown()
                    var
                        SalesHeader: Record "Sales Header";
                    begin
                        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
                        SalesHeader.SetRange("MC From Integration", true);
                        SalesHeader.SetRange("MC Order Status", SalesHeader."MC Order Status"::Ready);
                        Page.Run(Page::"Sales Order List", SalesHeader);
                    end;
                }

                field("Shipped Orders"; Rec."Shipped Orders")
                {
                    ApplicationArea = All;
                    DrillDownPageID = "Sales Order List";
                    ToolTip = 'Number of orders that have been shipped';
                    Style = Subordinate;  // Gray - historical

                    trigger OnDrillDown()
                    var
                        SalesHeader: Record "Sales Header";
                    begin
                        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
                        SalesHeader.SetRange("MC From Integration", true);
                        SalesHeader.SetRange("MC Order Status", SalesHeader."MC Order Status"::Shipped);
                        Page.Run(Page::"Sales Order List", SalesHeader);
                    end;
                }

                field("Error Orders"; Rec."Error Orders")
                {
                    ApplicationArea = All;
                    DrillDownPageID = "Sales Order List";
                    ToolTip = 'Number of orders with errors that need attention';
                    Style = Unfavorable;  // Red - errors

                    trigger OnDrillDown()
                    var
                        SalesHeader: Record "Sales Header";
                    begin
                        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
                        SalesHeader.SetRange("MC From Integration", true);
                        SalesHeader.SetRange("MC Order Status", SalesHeader."MC Order Status"::Error);
                        Page.Run(Page::"Sales Order List", SalesHeader);
                    end;
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.Reset();
        if not Rec.Get() then begin
            Rec.Init();
            Rec.Insert();
        end;
    end;
}
```

### 3. Role Center Page Extension

```al
namespace MyCompany.MyApp.PageExtensions;

using MyCompany.MyApp.Pages;
using Microsoft.Sales.RoleCenters;

/// <summary>
/// Extends Order Processor Role Center with integration activities and actions
/// </summary>
pageextension 50100 "MC Order Processor RC Ext" extends "Order Processor Role Center"
{
    layout
    {
        // Add after the standard activities control
        // Use F12 in VS Code to find control names in Base App
        addafter(Control1901851508)
        {
            part("MC Order Activities"; "MC Order Activities")
            {
                ApplicationArea = All;
                Caption = 'Integration';
            }
        }
    }

    actions
    {
        // Add to the navigation menu (Sections)
        addlast(Sections)
        {
            group(MCIntegrationSection)
            {
                Caption = 'Integration';
                Image = Setup;

                action(MCSetupSection)
                {
                    Caption = 'Integration Setup';
                    ApplicationArea = All;
                    ToolTip = 'Configure integration settings';
                    RunObject = Page "MC Integration Setup";
                }

                action(MCOrdersSection)
                {
                    Caption = 'Integration Orders';
                    ApplicationArea = All;
                    ToolTip = 'View orders from integration';
                    RunObject = Page "Sales Order List";
                    RunPageView = where("Document Type" = const(Order),
                                        "MC From Integration" = const(true));
                }
            }
        }

        // Add to the quick actions area (Creation)
        addlast(Creation)
        {
            group(MCIntegration)
            {
                Caption = 'Integration';

                action(MCSetup)
                {
                    Caption = 'Integration Setup';
                    ApplicationArea = All;
                    ToolTip = 'Configure integration settings';
                    Image = Setup;
                    RunObject = Page "MC Integration Setup";
                }

                action(MCOrders)
                {
                    Caption = 'Integration Orders';
                    ApplicationArea = All;
                    ToolTip = 'View orders from integration';
                    Image = Document;
                    RunObject = Page "Sales Order List";
                    RunPageView = where("Document Type" = const(Order),
                                        "MC From Integration" = const(true));
                }

                action(MCApiLog)
                {
                    Caption = 'API Log';
                    ApplicationArea = All;
                    ToolTip = 'View API call history';
                    Image = Log;
                    RunObject = Page "MC API Log";
                }
            }
        }
    }
}
```

## Multiple CueGroups Example

```al
layout
{
    area(content)
    {
        cuegroup(Orders)
        {
            Caption = 'Orders';

            field("Open Orders"; Rec."Open Orders")
            {
                ApplicationArea = All;
                // ...
            }
            field("Pending Orders"; Rec."Pending Orders")
            {
                ApplicationArea = All;
                // ...
            }
        }

        cuegroup(Shipments)
        {
            Caption = 'Shipments';

            field("Ready to Ship"; Rec."Ready to Ship")
            {
                ApplicationArea = All;
                Style = Favorable;
                // ...
            }
            field("Delayed"; Rec."Delayed")
            {
                ApplicationArea = All;
                Style = Unfavorable;
                // ...
            }
        }

        cuegroup(Issues)
        {
            Caption = 'Issues';
            ShowCaption = false;  // Hide group caption

            field("Errors Today"; Rec."Errors Today")
            {
                ApplicationArea = All;
                Style = Unfavorable;
                // ...
            }
        }
    }
}
```

## CalcFormula Patterns

### Count with Multiple Filters

```al
CalcFormula = count("Sales Header" where(
    "Document Type" = const(Order),
    "Sell-to Customer No." = field("Customer Filter"),  // Table relation filter
    "Status" = const(Open),
    "Order Date" = field("Date Filter")));  // Date filter
```

### Count with Range Filter

```al
CalcFormula = count("Sales Header" where(
    "Document Type" = const(Order),
    "Order Date" = filter(>=%1)));  // Dynamic date filter
```

### Sum Instead of Count

```al
field(50; "Total Amount"; Decimal)
{
    CalcFormula = sum("Sales Line".Amount where(
        "Document Type" = const(Order),
        "Document No." = field("Order No. Filter")));
    FieldClass = FlowField;
    Editable = false;
}
```

## Finding Role Center Control Names

To find the correct control name for `addafter` or `addbefore`:

1. Open VS Code with AL project
2. Press `F12` (Go to Definition) on the Role Center page name
3. Navigate to the Base App source
4. Find the control names in the `layout` section

Common control names in Order Processor Role Center (Page 9006):
- `Control1901851508` - Activities area
- `Control1905767507` - User Tasks
- `Control1902613707` - Approval Requests
