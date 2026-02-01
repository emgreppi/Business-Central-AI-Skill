# Business Central Skills for Claude Code

A collection of Claude Code skills for Microsoft Dynamics 365 Business Central AL development.

## What are Skills?

Skills are structured knowledge files that teach Claude Code how to implement specific patterns and features. Each skill contains:

- Step-by-step procedures
- AL code templates with placeholders
- Best practices and common pitfalls
- References to official Microsoft documentation

## Available Skills

### API Development

| Skill | Description |
|-------|-------------|
| **consuming-bc-standard-api** | Consume Microsoft standard BC APIs (v2.0) - customers, vendors, items, salesOrders. No AL coding required. |
| **creating-bc-custom-api** | Create custom API pages (CRUD) and API queries (read-only joins) in AL. |
| **authenticating-with-oauth** | OAuth 2.0 Client Credentials and Authorization Code flows with token caching. |

### AL Patterns

| Skill | Description |
|-------|-------------|
| **controlling-al-access** | Control visibility with Access property, internalsVisibleTo, and multi-app scenarios. |
| **implementing-al-interfaces** | Dependency injection, polymorphism, and plugin architectures with AL interfaces. |
| **binding-event-subscribers** | Dynamic event subscriber activation with BindSubscription/UnbindSubscription. |

### Infrastructure

| Skill | Description |
|-------|-------------|
| **implementing-telemetry** | Custom telemetry with Feature Telemetry, Session.LogMessage, and KQL queries. |
| **optimizing-bc-performance** | BC SaaS performance patterns - SetLoadFields, ReadIsolation, async operations. |
| **handling-bc-files** | File attachments, XMLport, Azure Blob Storage, InStream/OutStream patterns. |

### UI & Integration

| Skill | Description |
|-------|-------------|
| **building-cue-rolecenters** | Cue tiles, Activities CardPart, FlowFields with drill-down navigation. |
| **integrating-azure-services** | Azure Functions and Logic Apps integration from AL. |

### Workflow

| Skill | Description |
|-------|-------------|
| **writing-git-commits** | Git commit message conventions with proper format and types. |

## Installation

### Using Tessl CLI

```bash
tessl install github:your-username/bc-skills
```

### Manual Installation

Copy the skill folders to your project's `.claude/skills/` directory.

## Usage

Skills are loaded automatically by Claude Code when relevant. You can also explicitly reference them:

```
"Use the creating-bc-custom-api skill to create an API page for the Customer table"
```

## Skill Structure

Each skill follows this structure:

```
skill-name/
├── SKILL.md          # Main skill file with procedures
├── tile.json         # Package manifest
└── references/       # Supporting files (templates, examples)
```

## Requirements

- Claude Code CLI or VS Code extension
- Business Central development environment (for AL skills)
- Azure subscription (for Azure integration skills)


## Resources

- [Claude Code Documentation](https://docs.anthropic.com/claude-code)
- [Business Central Developer Documentation](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/)
- [AL Language Reference](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-reference-overview)
