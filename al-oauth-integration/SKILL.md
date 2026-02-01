---
name: authenticating-with-oauth
description: Generates access tokens, handles token refresh, and manages bearer authentication for external APIs in BC. Use when implementing OAuth Client Credentials flow, Authorization Code flow, or API authentication with token caching.
license: MIT
metadata:
  version: 1.0.0
---

# Skill: AL OAuth Integration

## Validation Gates

1. **After Step 4**: `GetAccessToken()` returns valid token in sandbox
2. **After Step 5**: API call succeeds, 401 triggers auto-retry
3. **Final**: Token caching works (check `Token Expiry` field), telemetry logs operations

**Note:** `SecretText.Unwrap()` blocked in SaaS. Use `Text` + `[NonDebuggable]`.

## Procedure

### Step 1: Identify OAuth Flow
Ask user:
- Is this service-to-service (no user context)? → **Client Credentials**
- Does it require user consent/context? → **Authorization Code**

### Step 2: Create Setup Table
Create a setup table with these fields:

```al
table <ID> "<PREFIX> OAuth Setup"
{
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10]) { }
        field(10; "Client ID"; Text[100]) { }
        field(11; "Tenant ID"; Text[100]) { }
        field(12; "Token Endpoint"; Text[250]) { }
        field(13; Scope; Text[250]) { }
        field(20; "Token Expiry"; DateTime) { Editable = false; }
        field(21; Enabled; Boolean) { }
    }

    keys
    {
        key(PK; "Primary Key") { Clustered = true; }
    }
}
```

### Step 3: Implement Secret Storage
Use **Isolated Storage** for client_secret. Pattern works for SaaS and OnPrem:

```al
codeunit <ID> "<PREFIX> OAuth Secrets Mgt"
{
    Access = Internal;

    var
        SecretKeyLbl: Label 'OAuthClientSecret', Locked = true;

    [NonDebuggable]
    procedure SetClientSecret(SecretValue: Text)
    begin
        if SecretValue = '' then
            IsolatedStorage.Delete(SecretKeyLbl, DataScope::Company)
        else
            IsolatedStorage.Set(SecretKeyLbl, SecretValue, DataScope::Company);
    end;

    [NonDebuggable]
    procedure GetClientSecret(): Text
    var
        SecretValue: Text;
    begin
        if IsolatedStorage.Get(SecretKeyLbl, DataScope::Company, SecretValue) then
            exit(SecretValue);
        exit('');
    end;

    procedure HasClientSecret(): Boolean
    begin
        exit(IsolatedStorage.Contains(SecretKeyLbl, DataScope::Company));
    end;
}
```

### Step 4: Implement Token Acquisition
Use **Codeunit 501 "OAuth2"** (system codeunit):

```al
codeunit <ID> "<PREFIX> OAuth Token Mgt"
{
    Access = Internal;

    var
        Setup: Record "<PREFIX> OAuth Setup";
        SecretsMgt: Codeunit "<PREFIX> OAuth Secrets Mgt";

    [NonDebuggable]
    procedure GetAccessToken(): SecretText
    var
        OAuth2: Codeunit OAuth2;
        AccessToken: SecretText;
        Scopes: List of [Text];
    begin
        Setup.Get();
        Setup.TestField(Enabled);
        Setup.TestField("Client ID");
        Setup.TestField("Token Endpoint");

        if IsTokenValid() then
            exit(GetCachedToken());

        Scopes.Add(Setup.Scope);

        if not OAuth2.AcquireTokenWithClientCredentials(
            Setup."Client ID",
            SecretsMgt.GetClientSecret(),
            Setup."Token Endpoint",
            '',
            Scopes,
            AccessToken)
        then
            Error('Failed to acquire OAuth token: %1', GetLastErrorText());

        CacheToken(AccessToken);
        exit(AccessToken);
    end;

    local procedure IsTokenValid(): Boolean
    begin
        exit((Setup."Token Expiry" <> 0DT) and (Setup."Token Expiry" > CurrentDateTime()));
    end;

    local procedure CacheToken(Token: SecretText)
    begin
        Setup."Token Expiry" := CurrentDateTime() + (3540 * 1000);
        Setup.Modify();
    end;

    local procedure GetCachedToken(): SecretText
    begin
        // Implement: Isolated Storage or Session variable
    end;
}
```

### Step 5: Implement HTTP Client with OAuth
Create HTTP client that automatically adds Bearer token:

```al
codeunit <ID> "<PREFIX> OAuth HTTP Client"
{
    Access = Internal;

    var
        TokenMgt: Codeunit "<PREFIX> OAuth Token Mgt";

    [NonDebuggable]
    procedure SendRequest(Method: Text; Url: Text; RequestBody: Text; var ResponseBody: Text; var HttpStatusCode: Integer): Boolean
    var
        Client: HttpClient;
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        Headers: HttpHeaders;
        Content: HttpContent;
        AccessToken: SecretText;
    begin
        AccessToken := TokenMgt.GetAccessToken();
        Request.Method := Method;
        Request.SetRequestUri(Url);
        Request.GetHeaders(Headers);
        Headers.Add('Authorization', SecretStrSubstNo('Bearer %1', AccessToken));
        Headers.Add('Content-Type', 'application/json');

        if RequestBody <> '' then begin
            Content.WriteFrom(RequestBody);
            Request.Content := Content;
        end;

        if not Client.Send(Request, Response) then begin
            HttpStatusCode := 0;
            exit(false);
        end;

        HttpStatusCode := Response.HttpStatusCode();
        Response.Content.ReadAs(ResponseBody);

        // Auto-retry on 401 (token expired)
        if HttpStatusCode = 401 then begin
            AccessToken := TokenMgt.GetAccessToken();
            Headers.Remove('Authorization');
            Headers.Add('Authorization', SecretStrSubstNo('Bearer %1', AccessToken));
            if Client.Send(Request, Response) then begin
                HttpStatusCode := Response.HttpStatusCode();
                Response.Content.ReadAs(ResponseBody);
            end;
        end;

        exit(Response.IsSuccessStatusCode());
    end;
}
```

## Security Essentials

- `[NonDebuggable]` on all procedures handling secrets
- `Access = Internal` on secret management codeunits
- `DataScope::Company` for OAuth credentials
- Cache token for `(expires_in - 60s)` to avoid mid-request expiry

## Troubleshooting OAuth Errors

| Error | Fix |
|-------|-----|
| Token request fails | Verify Client ID, Secret, Token Endpoint, Scope |
| 401 on API call | Token expired → auto-retry should refresh |
| 403 Forbidden | Check Azure AD permissions/API scopes |
| AADSTS700016 | App not found in tenant → verify Tenant ID |

**Feedback loop:** Fix credentials → Re-run Step 3 checkpoint → Confirm token acquired before API calls.

## References

See `references/` folder for:
- `oauth-patterns.md` - Complete code patterns
- `token-management.md` - Token caching strategies
- `azure-setup.md` - Azure AD App Registration guide
- `troubleshooting.md` - Common errors and solutions

## External Documentation

- [Microsoft: OAuth authentication for BC Web Services](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/webservices/authenticate-web-services-using-oauth)
- [Microsoft: S2S Authentication](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/automation-apis-using-s2s-authentication)
- [Codeunit 501 OAuth2](https://learn.microsoft.com/en-us/dynamics365/business-central/application/system-application/codeunit/system.security.authentication.oauth2)
