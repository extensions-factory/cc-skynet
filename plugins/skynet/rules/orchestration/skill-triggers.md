# Skill Triggers

<!-- @hook:PreToolUse:Agent -->
Use skills to sharpen execution, not to add ceremony.

## Core Rule

- Check for a relevant known skill when the task clearly matches one.
- If a worker is being delegated a specialized task, optionally suggest 1-2 skills that materially improve the outcome.
- If no clearly relevant skill exists, skip skill suggestions.

## How to Suggest

In a delegation prompt, use:

```markdown
**Suggested skills:** skill-a, skill-b
```

Suggestions are optional guidance, not mandatory steps.

## Trigger Map

### Code Implementation

| When task involves | Suggest skills |
|---|---|
| New feature end-to-end | `full-stack-orchestration-full-stack-feature`, `clean-code` |
| Backend API / endpoint | `api-endpoint-builder`, `api-design-principles` |
| Frontend UI component | `react-best-practices`, `tailwind-patterns` |
| Database schema / query | `database-design`, `sql-optimization-patterns` |
| TypeScript-heavy logic | `typescript-expert`, `typescript-advanced-types` |
| Node.js backend | `nodejs-best-practices`, `nodejs-backend-patterns` |

### Code Quality

| When task involves | Suggest skills |
|---|---|
| Refactoring | `code-refactoring-refactor-clean`, `simplify` |
| Writing tests | `test-driven-development`, `javascript-testing-patterns` |
| Bug fixing | `bug-hunter`, `systematic-debugging` |
| Code review | `code-reviewer`, `code-review-checklist` |
| Performance issue | `performance-optimizer`, `performance-profiling` |
| Security concern | `security-audit`, `cc-skill-security-review` |

### DevOps & Infrastructure

| When task involves | Suggest skills |
|---|---|
| Docker setup | `docker-expert` |
| CI/CD pipeline | `github-actions-templates`, `cicd-automation-workflow-automate` |
| Deployment | `deployment-engineer`, `vercel-deployment` |
| Kubernetes | `kubernetes-architect`, `kubernetes-deployment` |
| Terraform / IaC | `terraform-specialist`, `terraform-infrastructure` |

### Research & Analysis

| When task involves | Suggest skills |
|---|---|
| Tech comparison | `deep-research` |
| Architecture decision | `architecture-decision-records`, `software-architecture` |
| API/SDK docs | `api-documentation`, `documentation` |
| Security research | `web-security-testing`, `vulnerability-scanner` |
| SEO analysis | `seo-audit`, `seo-keyword-strategist` |

### Project-Specific (Skynet)

| When task involves | Suggest skills |
|---|---|
| Slack bot features | `slack-bot-builder` |
| Agent orchestration | `multi-agent-patterns`, `agent-orchestration-multi-agent-optimize` |
| Slash commands | `slack-bot-builder`, `api-endpoint-builder` |
| MCP integration | `mcp-builder` |

## Rules

1. Match by intent, not keywords.
2. Suggest at most 2 skills by default. Use 3 only for genuinely compound tasks.
3. Do not suggest skills the target worker cannot use.
4. If skill availability is unknown, prefer skipping over guessing.
5. Skills should reduce ambiguity or improve quality. If they do neither, omit them.
<!-- @end:PreToolUse:Agent -->
