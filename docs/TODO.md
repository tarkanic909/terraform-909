# TODO

## Refactor `interlink_neighbors` to a list of objects with `name` field

Currently `interlink_neighbors` in `nodes.tf` is a hardcoded map:

```hcl
interlink_neighbors = {
  "lab-router1" = "lab-router2"
  "lab-router2" = "lab-router1"
}
```

This does not scale — adding a third router requires manual updates and the structure
carries no metadata. Refactor to a list of objects:

```hcl
interlink_neighbors = [
  { name = "lab-router1", neighbor = "lab-router2" },
  { name = "lab-router2", neighbor = "lab-router1" },
]
```

Then derive the lookup map from it:

```hcl
interlink_neighbors_map = {
  for n in local.interlink_neighbors : n.name => n.neighbor
}
```

Update all references in `nodes.tf` and `output.tf` to use `interlink_neighbors_map`.

**Effort:** ~30 minutes

---

## Migrate Terraform state to GitLab-managed remote backend

**Why:** State is currently stored locally (`terraform.tfstate`). This means:
- State is lost if the disk fails or the project directory is deleted.
- No state locking — running `terraform apply` from two terminals simultaneously corrupts state.
- Not portable — working from a different machine requires manually copying the state file.

**Effort:** ~30 minutes

---

### Steps

#### 1. Get the GitLab project ID

Open the project page at `https://gitlab.com/lab-909/terraform` and copy the numeric
project ID shown below the project name (e.g. `12345678`).

#### 2. Create a GitLab personal access token

Go to `https://gitlab.com/-/user_settings/personal_access_tokens` and create a token
with the `api` scope. Save it — you will need it as an environment variable.

#### 3. Add the backend block to `main.tf`

```hcl
terraform {
  required_version = "~> 1.14"

  backend "http" {
    address        = "https://gitlab.com/api/v4/projects/<PROJECT_ID>/terraform/state/lab-909"
    lock_address   = "https://gitlab.com/api/v4/projects/<PROJECT_ID>/terraform/state/lab-909/lock"
    unlock_address = "https://gitlab.com/api/v4/projects/<PROJECT_ID>/terraform/state/lab-909/lock"
    lock_method    = "POST"
    unlock_method  = "DELETE"
    username       = "<GITLAB_USERNAME>"
    # password is read from TF_HTTP_PASSWORD env var — do not hardcode it here
  }

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.9.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}
```

Replace `<PROJECT_ID>` and `<GITLAB_USERNAME>` with real values.

#### 4. Export the token before running Terraform

```bash
export TF_HTTP_PASSWORD="<YOUR_GITLAB_TOKEN>"
```

Add this to your shell profile (`~/.bashrc` or `~/.zshrc`) or a local `.envrc`
(gitignored) so you don't have to set it manually every time.

#### 5. Migrate existing local state

```bash
terraform init -migrate-state
```

Terraform will detect the new backend, prompt to copy the existing local state to
GitLab, and confirm before doing so. After migration, `terraform.tfstate` on disk is
no longer the source of truth.

#### 6. Verify

```bash
terraform state list
```

Should return all existing resources pulled from the remote state.

---

### Notes

- The GitLab HTTP backend supports state locking via the `lock_address` / `unlock_address`
  fields — concurrent `apply` runs will be blocked automatically.
- State is stored encrypted at rest on GitLab infrastructure.
- The state URL pattern above creates a state named `lab-909`. You can create multiple
  named states (e.g. per environment) by changing the last path segment.
- If you ever want to move back to local state: `terraform init -migrate-state` after
  removing the `backend` block.
