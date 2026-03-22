# Skill Triggers


All agents — including the orchestrator itself — MUST use the Skill tool to get specialized guidance when the task matches a known skill.
When delegating to workers, the orchestrator MUST also suggest relevant skills based on task type.

## How to Suggest

In the delegation prompt, include:
```
**Suggested skills:** skill-a, skill-b
```

Workers decide whether to invoke — these are recommendations, not mandates.

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

### Research & Analysis (Gemini worker)

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

1. **Match by intent, not keywords** — a task saying "make it faster" triggers performance skills, not speed-related skills
2. **Max 3 skills per delegation** — more than 3 creates noise; pick the most relevant
3. **Don't suggest skills the worker can't use** — Gemini workers cannot code, so never suggest coding skills to them
4. **Compound tasks get compound skills** — "add API endpoint with tests" → `api-endpoint-builder` + `test-driven-development`
5. **When unsure, skip** — no skill is better than a wrong skill
