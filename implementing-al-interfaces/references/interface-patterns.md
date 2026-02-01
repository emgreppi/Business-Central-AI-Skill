# Interface Patterns - Complete Examples

## Pattern 1: Email/Notification Provider

### Interface Definition

```al
interface "SBM INotification Provider"
{
    procedure SendNotification(Recipient: Text; Subject: Text; Body: Text): Boolean;
    procedure GetProviderName(): Text;
    procedure IsConfigured(): Boolean;
}
```

### Enum with Implementations

```al
enum 50110 "SBM Notification Provider" implements "SBM INotification Provider"
{
    Extensible = true;

    value(0; Email)
    {
        Caption = 'Email';
        Implementation = "SBM INotification Provider" = "SBM Email Notifier";
    }
    value(1; Teams)
    {
        Caption = 'Microsoft Teams';
        Implementation = "SBM INotification Provider" = "SBM Teams Notifier";
    }
    value(2; SMS)
    {
        Caption = 'SMS';
        Implementation = "SBM INotification Provider" = "SBM SMS Notifier";
    }
}
```

### Email Implementation

```al
codeunit 50111 "SBM Email Notifier" implements "SBM INotification Provider"
{
    var
        EmailMessage: Codeunit "Email Message";
        Email: Codeunit Email;

    procedure SendNotification(Recipient: Text; Subject: Text; Body: Text): Boolean
    begin
        EmailMessage.Create(Recipient, Subject, Body, true);
        exit(Email.Send(EmailMessage));
    end;

    procedure GetProviderName(): Text
    begin
        exit('Email');
    end;

    procedure IsConfigured(): Boolean
    var
        EmailAccount: Record "Email Account";
    begin
        exit(not EmailAccount.IsEmpty());
    end;
}
```

### Teams Implementation

```al
codeunit 50112 "SBM Teams Notifier" implements "SBM INotification Provider"
{
    var
        Setup: Record "SBM Notification Setup";

    procedure SendNotification(Recipient: Text; Subject: Text; Body: Text): Boolean
    var
        Client: HttpClient;
        Content: HttpContent;
        Response: HttpResponseMessage;
        JsonBody: JsonObject;
    begin
        if not Setup.Get() then
            exit(false);

        JsonBody.Add('title', Subject);
        JsonBody.Add('text', Body);

        Content.WriteFrom(Format(JsonBody));
        exit(Client.Post(Setup."Teams Webhook URL", Content, Response) and Response.IsSuccessStatusCode());
    end;

    procedure GetProviderName(): Text
    begin
        exit('Microsoft Teams');
    end;

    procedure IsConfigured(): Boolean
    begin
        if not Setup.Get() then
            exit(false);
        exit(Setup."Teams Webhook URL" <> '');
    end;
}
```

## Pattern 2: Data Export with Multiple Formats

### Interface

```al
interface "SBM IData Exporter"
{
    procedure ExportCustomers(var Customer: Record Customer): Text;
    procedure ExportItems(var Item: Record Item): Text;
    procedure GetFileExtension(): Text;
    procedure GetMimeType(): Text;
}
```

### Enum

```al
enum 50120 "SBM Export Format" implements "SBM IData Exporter"
{
    Extensible = true;

    value(0; CSV)
    {
        Caption = 'CSV';
        Implementation = "SBM IData Exporter" = "SBM CSV Exporter";
    }
    value(1; JSON)
    {
        Caption = 'JSON';
        Implementation = "SBM IData Exporter" = "SBM JSON Exporter";
    }
    value(2; XML)
    {
        Caption = 'XML';
        Implementation = "SBM IData Exporter" = "SBM XML Exporter";
    }
}
```

### CSV Exporter

```al
codeunit 50121 "SBM CSV Exporter" implements "SBM IData Exporter"
{
    procedure ExportCustomers(var Customer: Record Customer): Text
    var
        Builder: TextBuilder;
    begin
        Builder.AppendLine('No.,Name,City,Country');
        if Customer.FindSet() then
            repeat
                Builder.AppendLine(StrSubstNo('%1,%2,%3,%4',
                    Customer."No.",
                    EscapeCSV(Customer.Name),
                    EscapeCSV(Customer.City),
                    Customer."Country/Region Code"));
            until Customer.Next() = 0;
        exit(Builder.ToText());
    end;

    procedure ExportItems(var Item: Record Item): Text
    var
        Builder: TextBuilder;
    begin
        Builder.AppendLine('No.,Description,Unit Price,Inventory');
        if Item.FindSet() then
            repeat
                Builder.AppendLine(StrSubstNo('%1,%2,%3,%4',
                    Item."No.",
                    EscapeCSV(Item.Description),
                    Format(Item."Unit Price", 0, 9),
                    Item.Inventory));
            until Item.Next() = 0;
        exit(Builder.ToText());
    end;

    procedure GetFileExtension(): Text
    begin
        exit('.csv');
    end;

    procedure GetMimeType(): Text
    begin
        exit('text/csv');
    end;

    local procedure EscapeCSV(Value: Text): Text
    begin
        if Value.Contains(',') or Value.Contains('"') then
            exit('"' + Value.Replace('"', '""') + '"');
        exit(Value);
    end;
}
```

### JSON Exporter

```al
codeunit 50122 "SBM JSON Exporter" implements "SBM IData Exporter"
{
    procedure ExportCustomers(var Customer: Record Customer): Text
    var
        JArray: JsonArray;
        JObject: JsonObject;
    begin
        if Customer.FindSet() then
            repeat
                Clear(JObject);
                JObject.Add('no', Customer."No.");
                JObject.Add('name', Customer.Name);
                JObject.Add('city', Customer.City);
                JObject.Add('country', Customer."Country/Region Code");
                JArray.Add(JObject);
            until Customer.Next() = 0;
        exit(Format(JArray));
    end;

    procedure ExportItems(var Item: Record Item): Text
    var
        JArray: JsonArray;
        JObject: JsonObject;
    begin
        if Item.FindSet() then
            repeat
                Clear(JObject);
                JObject.Add('no', Item."No.");
                JObject.Add('description', Item.Description);
                JObject.Add('unitPrice', Item."Unit Price");
                JObject.Add('inventory', Item.Inventory);
                JArray.Add(JObject);
            until Item.Next() = 0;
        exit(Format(JArray));
    end;

    procedure GetFileExtension(): Text
    begin
        exit('.json');
    end;

    procedure GetMimeType(): Text
    begin
        exit('application/json');
    end;
}
```

## Pattern 3: Validation Chain (Multiple Interfaces)

### Interfaces

```al
interface "SBM IOrder Validator"
{
    procedure Validate(SalesHeader: Record "Sales Header"): Boolean;
    procedure GetErrorMessage(): Text;
    procedure GetValidatorName(): Text;
}

interface "SBM IValidation Logger"
{
    procedure LogValidation(OrderNo: Code[20]; ValidatorName: Text; Success: Boolean; ErrorMsg: Text);
}
```

### Validator with Both Interfaces

```al
codeunit 50130 "SBM Credit Limit Validator" implements "SBM IOrder Validator", "SBM IValidation Logger"
{
    var
        LastError: Text;

    // IOrder Validator
    procedure Validate(SalesHeader: Record "Sales Header"): Boolean
    var
        Customer: Record Customer;
    begin
        LastError := '';

        if not Customer.Get(SalesHeader."Sell-to Customer No.") then begin
            LastError := 'Customer not found';
            LogValidation(SalesHeader."No.", GetValidatorName(), false, LastError);
            exit(false);
        end;

        Customer.CalcFields("Balance (LCY)");
        if Customer."Balance (LCY)" + SalesHeader."Amount Including VAT" > Customer."Credit Limit (LCY)" then begin
            LastError := StrSubstNo('Credit limit exceeded. Balance: %1, Order: %2, Limit: %3',
                Customer."Balance (LCY)",
                SalesHeader."Amount Including VAT",
                Customer."Credit Limit (LCY)");
            LogValidation(SalesHeader."No.", GetValidatorName(), false, LastError);
            exit(false);
        end;

        LogValidation(SalesHeader."No.", GetValidatorName(), true, '');
        exit(true);
    end;

    procedure GetErrorMessage(): Text
    begin
        exit(LastError);
    end;

    procedure GetValidatorName(): Text
    begin
        exit('Credit Limit Check');
    end;

    // IValidation Logger
    procedure LogValidation(OrderNo: Code[20]; ValidatorName: Text; Success: Boolean; ErrorMsg: Text)
    var
        ValidationLog: Record "SBM Validation Log";
    begin
        ValidationLog.Init();
        ValidationLog."Entry No." := 0;  // AutoIncrement
        ValidationLog."Order No." := OrderNo;
        ValidationLog."Validator Name" := ValidatorName;
        ValidationLog.Success := Success;
        ValidationLog."Error Message" := CopyStr(ErrorMsg, 1, 250);
        ValidationLog."Created At" := CurrentDateTime;
        ValidationLog.Insert(true);
    end;
}
```

### Using is/as Operators (BC25+)

```al
codeunit 50140 "SBM Validation Runner"
{
    procedure RunValidators(SalesHeader: Record "Sales Header"): Boolean
    var
        Validators: List of [Interface "SBM IOrder Validator"];
        Validator: Interface "SBM IOrder Validator";
        Logger: Interface "SBM IValidation Logger";
        AllPassed: Boolean;
    begin
        LoadValidators(Validators);
        AllPassed := true;

        foreach Validator in Validators do begin
            if not Validator.Validate(SalesHeader) then begin
                AllPassed := false;

                // Check if validator also implements logging
                if Validator is "SBM IValidation Logger" then begin
                    Logger := Validator as "SBM IValidation Logger";
                    // Logger already logged in Validate, but could do additional logging
                end;
            end;
        end;

        exit(AllPassed);
    end;

    local procedure LoadValidators(var Validators: List of [Interface "SBM IOrder Validator"])
    var
        CreditValidator: Codeunit "SBM Credit Limit Validator";
        StockValidator: Codeunit "SBM Stock Availability Validator";
        AddressValidator: Codeunit "SBM Address Validator";
    begin
        Validators.Add(CreditValidator);
        Validators.Add(StockValidator);
        Validators.Add(AddressValidator);
    end;
}
```

## Pattern 4: Document Handler (System Application Style)

This pattern is used in the System Application for Email, Document Sharing, etc.

### Base Interface

```al
interface "SBM IDocument Handler"
{
    procedure CanHandle(RecordVariant: Variant): Boolean;
    procedure GetDocumentName(RecordVariant: Variant): Text;
    procedure GeneratePDF(RecordVariant: Variant; var TempBlob: Codeunit "Temp Blob"): Boolean;
}
```

### Handler Registry Pattern

```al
codeunit 50150 "SBM Document Handler Registry"
{
    var
        Handlers: List of [Interface "SBM IDocument Handler"];

    procedure RegisterHandler(Handler: Interface "SBM IDocument Handler")
    begin
        Handlers.Add(Handler);
    end;

    procedure FindHandler(RecordVariant: Variant; var Handler: Interface "SBM IDocument Handler"): Boolean
    var
        CurrentHandler: Interface "SBM IDocument Handler";
    begin
        foreach CurrentHandler in Handlers do
            if CurrentHandler.CanHandle(RecordVariant) then begin
                Handler := CurrentHandler;
                exit(true);
            end;
        exit(false);
    end;

    procedure GenerateDocument(RecordVariant: Variant; var TempBlob: Codeunit "Temp Blob"): Boolean
    var
        Handler: Interface "SBM IDocument Handler";
    begin
        if not FindHandler(RecordVariant, Handler) then
            exit(false);
        exit(Handler.GeneratePDF(RecordVariant, TempBlob));
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"SBM Document Handler Registry", 'OnRegisterHandlers', '', false, false)]
    local procedure OnRegisterHandlers()
    var
        SalesHandler: Codeunit "SBM Sales Document Handler";
        PurchHandler: Codeunit "SBM Purchase Document Handler";
    begin
        RegisterHandler(SalesHandler);
        RegisterHandler(PurchHandler);
    end;

    [IntegrationEvent(false, false)]
    local procedure OnRegisterHandlers()
    begin
    end;
}
```

### Sales Document Handler

```al
codeunit 50151 "SBM Sales Document Handler" implements "SBM IDocument Handler"
{
    procedure CanHandle(RecordVariant: Variant): Boolean
    var
        RecRef: RecordRef;
    begin
        if not RecordVariant.IsRecord then
            exit(false);

        RecRef.GetTable(RecordVariant);
        exit(RecRef.Number in [Database::"Sales Header", Database::"Sales Invoice Header"]);
    end;

    procedure GetDocumentName(RecordVariant: Variant): Text
    var
        SalesHeader: Record "Sales Header";
        SalesInvHeader: Record "Sales Invoice Header";
        RecRef: RecordRef;
    begin
        RecRef.GetTable(RecordVariant);

        case RecRef.Number of
            Database::"Sales Header":
                begin
                    RecRef.SetTable(SalesHeader);
                    exit(StrSubstNo('Sales %1 %2', SalesHeader."Document Type", SalesHeader."No."));
                end;
            Database::"Sales Invoice Header":
                begin
                    RecRef.SetTable(SalesInvHeader);
                    exit(StrSubstNo('Invoice %1', SalesInvHeader."No."));
                end;
        end;
    end;

    procedure GeneratePDF(RecordVariant: Variant; var TempBlob: Codeunit "Temp Blob"): Boolean
    var
        SalesHeader: Record "Sales Header";
        ReportSelections: Record "Report Selections";
        RecRef: RecordRef;
    begin
        RecRef.GetTable(RecordVariant);

        if RecRef.Number = Database::"Sales Header" then begin
            RecRef.SetTable(SalesHeader);
            // Generate PDF using report selections
            exit(GenerateSalesOrderPDF(SalesHeader, TempBlob));
        end;

        exit(false);
    end;

    local procedure GenerateSalesOrderPDF(SalesHeader: Record "Sales Header"; var TempBlob: Codeunit "Temp Blob"): Boolean
    begin
        // Implementation to generate PDF
        exit(true);
    end;
}
```

## Key Takeaways

1. **Enum + Interface**: Most common pattern, provides runtime selection
2. **Multiple Interfaces**: One codeunit can implement several interfaces
3. **is/as Operators**: Check capabilities at runtime (BC25+)
4. **Registry Pattern**: Collect implementations dynamically via events
5. **Dependency Injection**: Pass interface instead of concrete codeunit for testability
