# Local Copilot Instructions

## Workflow

- Prefer `mise run <task>` over ad-hoc commands.
- Use non-interactive output defaults: `PAGER=cat`, `GIT_PAGER=cat`.
- Keep changes minimal and contract-aligned.

## Validation

- Run the narrowest `mise` task that validates your change.
- Before merge, run full validation (`mise run validate`) in the target repository.

## Environment

- Respect XDG paths and avoid writing hidden state outside XDG directories.
- Keep local cloud and cluster defaults aligned with dotfiles (`AWS_PROFILE`, `KUBECONFIG`).
