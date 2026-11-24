# The fluffy-linux forks: which exist, their description and their
# upstream property, from var.repos (repos.auto.tfvars.json).  The git side
# (the mirror, branches, tags, the default branch fluffy/<tag>, the
# release tarball) stays mkmirror.sh's.  A new fork: add it to
# repos.auto.tfvars.json and apply, then run mkmirror.sh.
#
# Three guards against losing a repository: prevent_destroy (a plan that
# would destroy one fails), archive_on_destroy (a destroy would archive,
# not delete), and Terraform's token (github-terraform-token: admin:org and
# repo, deliberately without delete_repo, so GitHub refuses a delete).  To
# stop managing a repository without touching it, use a removed block with
# destroy = false.

variable "repos" {
  description = <<-EOT
    Every fluffy-linux fork, by repository name: upstream, its git
    upstream (becomes the upstream property, which the mirror sync
    follows), or source, where an import that isn't git comes from
    (Fossil, release tarballs, the Translation Project).
  EOT
  type = map(object({
    upstream = optional(string)
    source   = optional(string)
  }))
  validation {
    condition     = alltrue([for r in var.repos : (r.upstream == null) != (r.source == null)])
    error_message = "Each repo needs exactly one of upstream or source."
  }
}

resource "github_repository" "fork" {
  for_each    = var.repos
  name        = each.key
  description = "Modified version of ${coalesce(each.value.upstream, each.value.source)}"
  visibility  = "public"

  has_issues    = false
  has_projects  = false
  has_wiki      = false
  has_downloads = false

  archive_on_destroy = true

  lifecycle {
    prevent_destroy = true
  }
}

resource "github_repository_custom_property" "upstream" {
  for_each       = { for name, r in var.repos : name => r if r.upstream != null }
  repository     = github_repository.fork[each.key].name
  property_name  = "upstream"
  property_type  = "url"
  property_value = [each.value.upstream]
}

# The organization's own repositories (not forks): their settings, under
# the same guards.
resource "github_repository" "own" {
  for_each = {
    fluffy = "Fluffy Linux"
    infra  = "The infrastructure behind Fluffy"
  }
  name        = each.key
  description = each.value
  visibility  = "public"

  has_issues    = false
  has_projects  = false
  has_wiki      = false
  has_downloads = false

  archive_on_destroy = true

  lifecycle {
    prevent_destroy = true
  }
}

# No GitHub Actions anywhere in the organization: CI is Buildkite, and
# forks must not run upstream workflows.
resource "github_actions_organization_permissions" "org" {
  enabled_repositories = "none"
}

# Pull requests are off too, but the provider can't set that yet (GitHub
# added the setting in February 2026): ../scripts/no-pull-requests does,
# for every repository here, after an apply.
