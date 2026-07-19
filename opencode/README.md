# OpenCode CLI

The included standalone configuration defines both supported API identities:

| Model | Context | Output limit |
|---|---:|---:|
| `Qwen3.6-35B-A3B` | 185,000 | 8,192 |
| `Qwen3.6-27B` | 102,400 | 8,192 |

## Setup

Copy the configuration into the project where OpenCode will run:

```bash
cp opencode/opencode.json /path/to/project/.opencode.json
export VLLM_API_KEY='<the VLLM_API_KEY from the server .env>'
```

Then launch OpenCode:

```bash
opencode --dir /path/to/project
```

The 35B-A3B model is the static default for all three agents. Select either configured
model with OpenCode's model picker or explicitly at launch:

```bash
opencode --model vllm/Qwen3.6-27B --dir /path/to/project
```

OpenCode does not load or modify the Docker stack. It reads `VLLM_API_KEY` from
its environment. The selected OpenCode model name must match the model currently
served by vLLM.

The configured agents are:

| Agent | Purpose | Thinking | Permissions |
|---|---|---|---|
| `build` | Code edits, refactors, and tool loops | Disabled | Full, with safeguards |
| `general` | Conversational questions | Disabled | Read-only |
| `plan` | Architecture and planning | Enabled | Read-only plus safe shell commands |

The server endpoint is `http://localhost:8000/v1`. Use `opencode config validate` in
the target project to validate the copied configuration.
