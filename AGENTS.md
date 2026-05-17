# AI Agents

A collection of 41 specialized AI subagents for use with Claude Code: 37 are
sourced from [contains-studio/agents](https://github.com/contains-studio/agents),
plus 4 project-specific agents tailored to `presto_app` (the `presto`
department). Each agent is a focused expert that Claude Code activates
automatically based on the context of your request, or that you can invoke
explicitly by name.

## Install all agents to your Claude Code directory

```bash
./scripts/install.sh --tool claude-code
```

This copies every agent into `~/.claude/agents/`. Restart Claude Code afterward
to activate them.

### Or manually copy a category if you only want one division

```bash
cp engineering/*.md ~/.claude/agents/
```

### Or install a single department with the installer

```bash
./scripts/install.sh --tool claude-code engineering
```

Run `./scripts/install.sh --help` for all options, `--list` to see every agent,
and `--dry-run` to preview without writing files.

## Activating an agent

Once installed, describe the work and Claude Code routes to the right agent,
or name it directly:

> "Hey Claude, activate Frontend Developer mode and help me build a React component"

## Departments

| Department | Agents |
|------------|--------|
| `engineering` | rapid-prototyper, frontend-developer, backend-architect, mobile-app-builder, ai-engineer, devops-automator, test-writer-fixer |
| `design` | ui-designer, ux-researcher, brand-guardian, visual-storyteller, whimsy-injector |
| `marketing` | content-creator, growth-hacker, twitter-engager, tiktok-strategist, instagram-curator, reddit-community-builder, app-store-optimizer |
| `product` | feedback-synthesizer, sprint-prioritizer, trend-researcher |
| `project-management` | project-shipper, experiment-tracker, studio-producer |
| `studio-operations` | analytics-reporter, finance-tracker, infrastructure-maintainer, legal-compliance-checker, support-responder |
| `testing` | api-tester, performance-benchmarker, test-results-analyzer, tool-evaluator, workflow-optimizer |
| `bonus` | studio-coach, joker |
| `presto` | flutter-developer, firebase-specialist, ai-integration-expert, realtime-messaging-expert |

## Project-specific agents (`presto`)

These 4 agents are written specifically for `presto_app` (Flutter + Firebase
marketplace with messaging and AI features):

- **flutter-developer** — Flutter/Dart UI, widgets, state, responsive layouts.
- **firebase-specialist** — Firestore rules, indexes, Cloud Functions, Auth, App Check.
- **ai-integration-expert** — OpenAI integration, speech-to-text, prompt engineering, the micro-IA flows.
- **realtime-messaging-expert** — conversations, presence, push notifications.
