# OAuth 2.0 Patterns for Business Central

## Client Credentials Flow (Service-to-Service)

### Complete Implementation with SecretText (BC23+)

```al
codeunit 50100 "API OAuth Token Manager"
{
    Access = Internal;

    var
        Setup: Record "API Setup";
        TokenCacheLbl: Label 'API_ACCESS_TOKEN', Locked = true;
        TokenExpiryLbl: Label 'API_TOKEN_EXPIRY', Locked = true;

    [NonDebuggable]
    procedure GetAccessToken(): SecretText
    var
        OAuth2: Codeunit OAuth2;
        AccessToken: SecretText;
        Scopes: List of [Text];
        ErrorText: Text;
    begin
        Setup.Get();
        Setup.TestField(Enabled);
        Setup.TestField("Client ID");
        Setup.TestField("Auth URL");
        Setup.TestField(Scope);

        // Check if cached token is still valid
        if IsCachedTokenValid() then
            exit(GetCachedToken());

        // Build scopes list
        Scopes.Add(Setup.Scope);

        // Acquire token using Client Credentials flow
        if not OAuth2.AcquireTokenWithClientCredentials(
            Setup."Client ID",
            GetClientSecret(),
            Setup."Auth URL",
            '',  // RedirectURL not needed for client credentials
            Scopes,
            AccessToken)
        then begin
            ErrorText := GetLastErrorText();
            if ErrorText = '' then
                ErrorText := 'Unknown error during token acquisition';
            Error('OAuth token acquisition failed: %1', ErrorText);
        end;

        // Cache the token
        CacheToken(AccessToken);

        exit(AccessToken);
    end;

    [NonDebuggable]
    local procedure GetClientSecret(): SecretText
    var
        Secret: SecretText;
    begin
        if not IsolatedStorage.Get('ClientSecret', DataScope::Company, Secret) then
            Error('Client secret not configured. Please set it in the setup page.');
        exit(Secret);
    end;

    [NonDebuggable]
    local procedure IsCachedTokenValid(): Boolean
    var
        ExpiryText: Text;
        ExpiryDT: DateTime;
    begin
        if not IsolatedStorage.Contains(TokenCacheLbl, DataScope::Company) then
            exit(false);

        if not IsolatedStorage.Get(TokenExpiryLbl, DataScope::Company, ExpiryText) then
            exit(false);

        if not Evaluate(ExpiryDT, ExpiryText) then
            exit(false);

        // Token valid if expiry is in the future
        exit(ExpiryDT > CurrentDateTime());
    end;

    [NonDebuggable]
    local procedure GetCachedToken(): SecretText
    var
        Token: SecretText;
    begin
        IsolatedStorage.Get(TokenCacheLbl, DataScope::Company, Token);
        exit(Token);
    end;

    [NonDebuggable]
    local procedure CacheToken(Token: SecretText)
    var
        ExpiryDT: DateTime;
    begin
        // Cache token for 59 minutes (default expiry is 60 minutes)
        ExpiryDT := CurrentDateTime() + (59 * 60 * 1000);

        IsolatedStorage.Set(TokenCacheLbl, Token, DataScope::Company);
        IsolatedStorage.Set(TokenExpiryLbl, Format(ExpiryDT, 0, 9), DataScope::Company);
    end;

    procedure ClearTokenCache()
    begin
        if IsolatedStorage.Contains(TokenCacheLbl, DataScope::Company) then
            IsolatedStorage.Delete(TokenCacheLbl, DataScope::Company);
        if IsolatedStorage.Contains(TokenExpiryLbl, DataScope::Company) then
            IsolatedStorage.Delete(TokenExpiryLbl, DataScope::Company);
    end;
}
```

## Authorization Code Flow (User-Delegated)

### For scenarios requiring user consent

```al
codeunit 50101 "API OAuth Auth Code Manager"
{
    Access = Internal;

    var
        Setup: Record "API Setup";

    [NonDebuggable]
    procedure GetAccessToken(): SecretText
    var
        OAuth2: Codeunit OAuth2;
        AccessToken: SecretText;
        AuthCode: Text;
        Scopes: List of [Text];
    begin
        Setup.Get();
        Setup.TestField(Enabled);

        Scopes.Add(Setup.Scope);

        // This will prompt user for consent if needed
        if not OAuth2.AcquireTokenByAuthorizationCode(
            Setup."Client ID",
            GetClientSecret(),
            Setup."Auth URL",
            Setup."Redirect URL",
            Scopes,
            Enum::"Prompt Interaction"::"Select Account",
            AccessToken,
            AuthCode)
        then
            Error('Failed to acquire token: %1', GetLastErrorText());

        exit(AccessToken);
    end;

    [NonDebuggable]
    local procedure GetClientSecret(): SecretText
    var
        Secret: SecretText;
    begin
        IsolatedStorage.Get('ClientSecret', DataScope::Company, Secret);
        exit(Secret);
    end;
}
```

## HTTP Client with Automatic Token Handling

```al
codeunit 50102 "API HTTP Client"
{
    Access = Internal;

    var
        TokenManager: Codeunit "API OAuth Token Manager";
        MaxRetries: Integer;

    trigger OnRun()
    begin
        MaxRetries := 1;
    end;

    [NonDebuggable]
    procedure Get(Url: Text; var ResponseBody: Text; var StatusCode: Integer): Boolean
    begin
        exit(SendRequest('GET', Url, '', ResponseBody, StatusCode));
    end;

    [NonDebuggable]
    procedure Post(Url: Text; RequestBody: Text; var ResponseBody: Text; var StatusCode: Integer): Boolean
    begin
        exit(SendRequest('POST', Url, RequestBody, ResponseBody, StatusCode));
    end;

    [NonDebuggable]
    procedure Put(Url: Text; RequestBody: Text; var ResponseBody: Text; var StatusCode: Integer): Boolean
    begin
        exit(SendRequest('PUT', Url, RequestBody, ResponseBody, StatusCode));
    end;

    [NonDebuggable]
    procedure Patch(Url: Text; RequestBody: Text; var ResponseBody: Text; var StatusCode: Integer): Boolean
    begin
        exit(SendRequest('PATCH', Url, RequestBody, ResponseBody, StatusCode));
    end;

    [NonDebuggable]
    procedure Delete(Url: Text; var ResponseBody: Text; var StatusCode: Integer): Boolean
    begin
        exit(SendRequest('DELETE', Url, '', ResponseBody, StatusCode));
    end;

    [NonDebuggable]
    local procedure SendRequest(
        Method: Text;
        Url: Text;
        RequestBody: Text;
        var ResponseBody: Text;
        var StatusCode: Integer): Boolean
    var
        Retry: Integer;
    begin
        for Retry := 0 to MaxRetries do begin
            if TrySendRequest(Method, Url, RequestBody, ResponseBody, StatusCode) then begin
                if StatusCode <> 401 then
                    exit(StatusCode in [200, 201, 202, 204]);

                // 401 - clear cache and retry
                TokenManager.ClearTokenCache();
            end;
        end;
        exit(false);
    end;

    [NonDebuggable]
    [TryFunction]
    local procedure TrySendRequest(
        Method: Text;
        Url: Text;
        RequestBody: Text;
        var ResponseBody: Text;
        var StatusCode: Integer)
    var
        Client: HttpClient;
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        Headers: HttpHeaders;
        Content: HttpContent;
        ContentHeaders: HttpHeaders;
        AccessToken: SecretText;
    begin
        AccessToken := TokenManager.GetAccessToken();

        Request.Method := Method;
        Request.SetRequestUri(Url);

        // Add Authorization header
        Request.GetHeaders(Headers);
        Headers.Add('Authorization', SecretStrSubstNo('Bearer %1', AccessToken));

        // Add body for POST/PUT/PATCH
        if RequestBody <> '' then begin
            Content.WriteFrom(RequestBody);
            Content.GetHeaders(ContentHeaders);
            if ContentHeaders.Contains('Content-Type') then
                ContentHeaders.Remove('Content-Type');
            ContentHeaders.Add('Content-Type', 'application/json');
            Request.Content := Content;
        end;

        Client.Send(Request, Response);

        StatusCode := Response.HttpStatusCode();
        Response.Content.ReadAs(ResponseBody);
    end;
}
```

## Setup Table Pattern

```al
table 50100 "API Setup"
{
    Caption = 'API Setup';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
        }
        field(10; "Client ID"; Text[100])
        {
            Caption = 'Client ID';
        }
        field(11; "Auth URL"; Text[250])
        {
            Caption = 'Authorization URL';

            trigger OnValidate()
            begin
                // Ensure HTTPS
                if ("Auth URL" <> '') and (StrPos(LowerCase("Auth URL"), 'https://') <> 1) then
                    FieldError("Auth URL", 'must start with https://');
            end;
        }
        field(12; Scope; Text[250])
        {
            Caption = 'Scope';
        }
        field(13; "Redirect URL"; Text[250])
        {
            Caption = 'Redirect URL';
        }
        field(14; "API Base URL"; Text[250])
        {
            Caption = 'API Base URL';

            trigger OnValidate()
            begin
                // Remove trailing slash
                if ("API Base URL" <> '') and ("API Base URL"[StrLen("API Base URL")] = '/') then
                    "API Base URL" := CopyStr("API Base URL", 1, StrLen("API Base URL") - 1);
            end;
        }
        field(20; Enabled; Boolean)
        {
            Caption = 'Enabled';
        }
        field(21; "Has Client Secret"; Boolean)
        {
            Caption = 'Has Client Secret';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = exist("Isolated Storage Entry" where("Key" = const('ClientSecret')));
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    procedure SetClientSecret(Secret: SecretText)
    begin
        if Secret.IsEmpty() then begin
            if IsolatedStorage.Contains('ClientSecret', DataScope::Company) then
                IsolatedStorage.Delete('ClientSecret', DataScope::Company);
        end else
            IsolatedStorage.Set('ClientSecret', Secret, DataScope::Company);
    end;

    procedure HasClientSecretSet(): Boolean
    begin
        exit(IsolatedStorage.Contains('ClientSecret', DataScope::Company));
    end;
}
```

## Setup Page with Password Field

```al
page 50100 "API Setup"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "API Setup";
    Caption = 'API Setup';
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field(Enabled; Rec.Enabled)
                {
                    ApplicationArea = All;
                }
                field("API Base URL"; Rec."API Base URL")
                {
                    ApplicationArea = All;
                }
            }
            group(OAuth)
            {
                Caption = 'OAuth 2.0 Configuration';

                field("Client ID"; Rec."Client ID")
                {
                    ApplicationArea = All;
                }
                field(ClientSecret; ClientSecretText)
                {
                    ApplicationArea = All;
                    Caption = 'Client Secret';
                    ExtendedDatatype = Masked;

                    trigger OnValidate()
                    begin
                        Rec.SetClientSecret(ClientSecretText);
                    end;
                }
                field("Has Client Secret"; Rec.HasClientSecretSet())
                {
                    ApplicationArea = All;
                    Caption = 'Client Secret Set';
                    Editable = false;
                }
                field("Auth URL"; Rec."Auth URL")
                {
                    ApplicationArea = All;
                }
                field(Scope; Rec.Scope)
                {
                    ApplicationArea = All;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(TestConnection)
            {
                ApplicationArea = All;
                Caption = 'Test Connection';
                Image = TestReport;

                trigger OnAction()
                var
                    TokenMgt: Codeunit "API OAuth Token Manager";
                    Token: SecretText;
                begin
                    Token := TokenMgt.GetAccessToken();
                    Message('Connection successful! Token acquired.');
                end;
            }
            action(ClearTokenCache)
            {
                ApplicationArea = All;
                Caption = 'Clear Token Cache';
                Image = ClearLog;

                trigger OnAction()
                var
                    TokenMgt: Codeunit "API OAuth Token Manager";
                begin
                    TokenMgt.ClearTokenCache();
                    Message('Token cache cleared.');
                end;
            }
        }
    }

    var
        ClientSecretText: SecretText;

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

## Common OAuth Endpoints

### Azure AD / Entra ID
```
Token Endpoint: https://login.microsoftonline.com/{tenant-id}/oauth2/v2.0/token
Scope: https://api.businesscentral.dynamics.com/.default
```

### Generic OAuth 2.0
```
Token Endpoint: https://provider.com/oauth/token
Scope: varies by provider
```

## Error Handling

Common errors and solutions:

| Error | Cause | Solution |
|-------|-------|----------|
| `AADSTS7000215` | Invalid client secret | Verify secret, check expiry |
| `AADSTS700016` | App not found | Verify client ID and tenant |
| `AADSTS65001` | User consent required | Use Authorization Code flow |
| `AADSTS50126` | Invalid credentials | Verify credentials |
| `invalid_scope` | Wrong scope format | Check API documentation |
