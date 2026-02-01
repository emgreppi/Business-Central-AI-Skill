---
name: building-cue-rolecenters
description: Builds Cue tiles and Activities CardPart pages for Business Central Role Centers, creates FlowField tables with CalcFormula counts, and implements drill-down navigation. Use when adding KPI dashboards, displaying record statistics, creating status indicators, or extending existing Role Centers with custom activity tiles.
license: MIT
metadata:
  version: 1.0.0
---

# Skill: AL Cue and Role Center Activities

## Validation Gates

1. **After Step 1**: Cue table compiles, FlowFields calculate correct counts
2. **After Step 2**: Activities page displays tiles, OnDrillDown navigates correctly
3. **Final**: Page extension adds part to Role Center, styles render as expected

**Prerequisites:** Identify source tables, filter criteria, and target Role Center (e.g., Order Processor 9006, Accountant 9027).

**Architecture:** Role Center Page → Activities CardPart (CueGroups) → Cue Table (FlowFields with CalcFormula counts)

## Procedure

### Step 1: Create Cue Table

The Cue Table contains **FlowFields** that calculate counts from source records.

**Key patterns:**
- Single Primary Key field (Code[10])
- FlowFields with `CalcFormula = count(...)`
- Editable = false on all FlowFields
- FieldClass = FlowField

```al
table <ID> "<PREFIX> <Area> Cue"
{
    Caption = '<Area> Cue';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
            DataClassification = SystemMetadata;
        }

        field(10; "<Status1> <Records>"; Integer)
        {
            CalcFormula = count("<Source Table>" where(
                "<FilterField1>" = const(<Value1>),
                "<StatusField>" = const(<Status1>)));
            Caption = '<Status1> <Records>';
            ToolTip = 'Number of <records> with status <Status1>';
            Editable = false;
            FieldClass = FlowField;
        }

        field(20; "<Status2> <Records>"; Integer)
        {
            CalcFormula = count("<Source Table>" where(
                "<FilterField1>" = const(<Value1>),
                "<StatusField>" = const(<Status2>)));
            Caption = '<Status2> <Records>';
            ToolTip = 'Number of <records> with status <Status2>';
            Editable = false;
            FieldClass = FlowField;
        }
        // Add more cue fields as needed...
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

### Step 2: Create Activities Page (CardPart)

The Activities page displays the cue tiles and handles drill-down navigation.

**Key patterns:**
- PageType = CardPart
- RefreshOnActivate = true (updates counts when user returns to RC)
- CueGroup for tile grouping
- OnDrillDown triggers for navigation
- Style property for visual emphasis

```al
page <ID> "<PREFIX> <Area> Activities"
{
    Caption = '<Area>';
    PageType = CardPart;
    RefreshOnActivate = true;
    SourceTable = "<PREFIX> <Area> Cue";

    layout
    {
        area(content)
        {
            cuegroup(<GroupName>)
            {
                Caption = '<Group Title>';

                field("<Field1>"; Rec."<Field1>")
                {
                    ApplicationArea = All;
                    DrillDownPageID = "<Target List Page>";
                    ToolTip = '<Tooltip>';

                    trigger OnDrillDown()
                    var
                        SourceRec: Record "<Source Table>";
                    begin
                        SourceRec.SetRange("<FilterField1>", <Value1>);
                        SourceRec.SetRange("<StatusField>", <StatusValue>);
                        Page.Run(Page::"<Target List Page>", SourceRec);
                    end;
                }

                field("<Field2>"; Rec."<Field2>")
                {
                    ApplicationArea = All;
                    DrillDownPageID = "<Target List Page>";
                    ToolTip = '<Tooltip>';
                    Style = Attention;  // Yellow highlight

                    trigger OnDrillDown()
                    // ... similar pattern
                }

                field("<Field3>"; Rec."<Field3>")
                {
                    ApplicationArea = All;
                    Style = Favorable;  // Green highlight
                    // ...
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

### Step 3: Extend Role Center

Add your Activities page to an existing Role Center.

**Key patterns:**
- Find the correct anchor control (use F12 to explore Base App RC)
- Use `addafter` or `addbefore` for positioning
- Add actions to Sections and/or Creation areas

```al
pageextension <ID> "<PREFIX> <RoleCenterName> Ext" extends "<RoleCenterPageName>"
{
    layout
    {
        addafter(<ExistingControlName>)
        {
            part("<PREFIX> <Area> Activities"; "<PREFIX> <Area> Activities")
            {
                ApplicationArea = All;
                Caption = '<Area>';
            }
        }
    }

    actions
    {
        addlast(Sections)
        {
            group(<PREFIX><Area>Section)
            {
                Caption = '<Area>';
                Image = Setup;

                action(<PREFIX><Action1>)
                {
                    Caption = '<Action Title>';
                    ApplicationArea = All;
                    ToolTip = '<Tooltip>';
                    RunObject = Page "<Target Page>";
                }
            }
        }
    }
}
```

## Quick Reference

**Cue Styles:** `Attention` (yellow), `Favorable` (green), `Unfavorable` (red), `Subordinate` (gray), `Ambiguous` (orange)

**Common Role Centers:** Order Processor (9006), Accountant (9027), Business Manager (9022), Sales Manager (9005), Purchasing Agent (9007)

**Best Practices:** Efficient CalcFormula filters • OnDrillDown must match CalcFormula filters • Single record table (Primary Key = '') • RefreshOnActivate = true

## References

See `references/` folder for:
- `cue-patterns.md` - Complete code examples

## External Documentation

- [Microsoft: Cues and Action Tiles](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-cues-action-tiles)
- [Microsoft: Role Center Design](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-designing-role-centers)
