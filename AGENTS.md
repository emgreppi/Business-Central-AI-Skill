# AGENTS.md - BC Skills Context

This repository contains Claude Code skills for Microsoft Dynamics 365 Business Central AL development.

## Purpose

These skills teach Claude Code how to implement specific patterns and features in Business Central extensions using the AL language.

## Available Skills

| Skill | Description |
|-------|-------------|
| **controlling-al-access** | Control visibility with Access property (Public, Internal, Protected, Local) |
| **consuming-bc-standard-api** | Consume Microsoft standard BC APIs (v2.0) - no AL coding required |
| **creating-bc-custom-api** | Create custom API pages (CRUD) and API queries (read-only joins) |
| **authenticating-with-oauth** | OAuth 2.0 Client Credentials and Authorization Code flows |
| **implementing-al-interfaces** | Dependency injection, polymorphism, plugin architectures |
| **implementing-telemetry** | Custom telemetry with Feature Telemetry and Session.LogMessage |
| **building-cue-rolecenters** | Cue tiles, Activities CardPart, FlowFields with drill-down |
| **handling-bc-files** | File attachments, XMLport, Azure Blob Storage patterns |
| **integrating-azure-services** | Azure Functions and Logic Apps integration from AL |
| **binding-event-subscribers** | Dynamic event subscriber activation with BindSubscription |
| **optimizing-bc-performance** | BC SaaS performance patterns and best practices |
| **writing-git-commits** | Git commit message conventions |

## How to Use

Each skill contains:
- `SKILL.md` - Main skill file with step-by-step procedures
- `references/` - Supporting files (templates, examples)

Load a skill when implementing that specific feature. The skill provides patterns, code templates, and best practices.

## Target Environment

- Microsoft Dynamics 365 Business Central (SaaS)
- AL Language (BC 21.0+)
- Visual Studio Code with AL Language extension

## License

MIT
