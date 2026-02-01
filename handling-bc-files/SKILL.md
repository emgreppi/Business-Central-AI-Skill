---
name: handling-bc-files
description: Uploads and downloads files using InStream/OutStream, attaches documents to records via Table 1173, imports and exports CSV/XML with XMLport, and stores blobs in Azure Storage. Use when adding file attachments to sales orders, importing data from CSV, exporting reports to files, or connecting to Azure Blob Storage.
license: MIT
metadata:
  version: 1.0.0
---

# Skill: AL File Handling

## Validation Gates

1. **After Step 1**: `UploadIntoStream` opens file dialog, InStream contains data
2. **After Step 2**: Attachment saved to Document Attachment or custom table
3. **Final**: XMLport imports/exports successfully, Azure Blob upload returns `IsSuccessful()`

**Note:** ALWAYS `CalcFields(BlobField)` before `CreateInStream`. Web Client allows only ONE `DownloadFromStream` per request.

## Procedure

### Step 1: Upload/Download Files

```al
// Upload
if UploadIntoStream('Select file', '', 'All Files (*.*)|*.*', FileName, InStr) then
    // Process InStr

// Download - MUST CalcFields first for Blob
CalcFields("File Content");
if "File Content".HasValue() then begin
    "File Content".CreateInStream(InStr);
    DownloadFromStream(InStr, '', '', '', FileName);
end;
```

### Step 2: Document Attachments

**Standard (Table 1173):**
```al
// Replace <SourceTable> and field names with your record
DocumentAttachment.Init();
DocumentAttachment.Validate("Table ID", Database::<SourceTable>);
DocumentAttachment.Validate("No.", <Record>."<KeyField>");
DocumentAttachment.Validate("Document Type", <Record>."<TypeField>");  // If applicable
DocumentAttachment.InsertFromStream(InStr, FileName);
```

**Custom Blob field:**
```al
Rec."File Content".CreateOutStream(OutStr);
CopyStream(OutStr, InStr);
Rec.Modify();
```

### Step 3: XMLport Import/Export

```al
xmlport <ID> "<PREFIX> Import Data"
{
    Direction = Import;
    Format = VariableText;
    FieldDelimiter = '"';
    FieldSeparator = ';';
    TextEncoding = UTF8;

    schema
    {
        textelement(Root)
        {
            tableelement(TempImport; "<PREFIX> Import Buffer")
            {
                UseTemporary = true;
                AutoSave = false;
                fieldelement(ItemNo; TempImport."Item No.") { }
                fieldelement(Description; TempImport.Description) { }
                trigger OnAfterInsertRecord()
                begin
                    ProcessLine(TempImport);
                end;
            }
        }
    }
}
```

**Key properties:** `Direction` (Import/Export/Both), `Format` (Xml/VariableText/FixedText), `TextEncoding` (UTF8/UTF16)

### Step 4: Azure Blob Storage (Optional)

```al
var
    ABSBlobClient: Codeunit "ABS Blob Client";
    StorageServiceAuthorization: Codeunit "Storage Service Authorization";
    Authorization: Interface "Storage Service Authorization";
begin
    Authorization := StorageServiceAuthorization.CreateSAS(GetSASToken());
    ABSBlobClient.Initialize(AccountName, ContainerName, Authorization);

    // Upload
    TempBlob.CreateInStream(InStr);
    ABSOperationResponse := ABSBlobClient.PutBlobBlockBlobStream(BlobName, InStr);

    // Download
    ABSOperationResponse := ABSBlobClient.GetBlobAsStream(BlobName, InStr);
end;
```

**Requires:** Azure Storage Account + SAS Token in Isolated Storage.

## Persistent Blob (Cross-Session)

```al
// Store (returns GUID key)
BlobKey := PersistentBlob.Create();
PersistentBlob.CreateOutStream(OutStr);
OutStr.WriteText(Data);

// Retrieve
PersistentBlob.CreateInStream(BlobKey, InStr);
InStr.ReadText(Data);
PersistentBlob.Delete(BlobKey); // Clean up
```

**⚠️** NOT for permanent storage - causes locking issues.

## JSON/XML Quick Reference

```al
// JSON
JsonObj.Add('key', 'value');
JsonObj.WriteTo(JsonText);
JsonObj.ReadFrom(JsonText);
if JsonObj.Get('key', JsonTok) then MyText := JsonTok.AsValue().AsText();

// XML
XmlDoc := XmlDocument.Create();
XmlDoc.Add(XmlElement.Create('Root'));
XmlDocument.ReadFrom(XmlText, XmlDoc);
XmlDoc.SelectSingleNode('//Child', XmlNode);
```

## External Documentation

- [InStream/OutStream](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/methods-auto/instream/instream-data-type)
- [XMLport Properties](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/properties/devenv-xmlport-properties)
- [Azure Blob Services](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-develop-connect-apps)
