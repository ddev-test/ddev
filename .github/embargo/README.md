# Embargo Variables

Adapted from <https://github.com/orgs/community/discussions/44322#discussioncomment-11801819>.

Edit the files on the [`embargo` branch](https://github.com/ddev/ddev/tree/embargo/.github/embargo)
to skip tests in CI - works for both fork PRs and internal runs.

## Files

- `DDEV_EMBARGO_TESTS` - pipe-separated test names to skip, e.g. `TestFoo|TestBar` or `symfony-composer|symfony-cli`
- `DDEV_EMBARGO_PHP_VERSIONS` - comma-separated PHP versions to skip in `TestPHPConfig`, e.g. `8.4,8.5`

## How to update

1. Edit the file(s) directly on the `embargo` branch - no PR required
2. Include `[skip ci]` in the commit message to avoid triggering test workflows
3. To clear an embargo, empty the file

## How it works

Each CI run does `git fetch --depth=1 --no-tags https://github.com/ddev/ddev embargo:refs/embargo-tmp`,
reads the files via `git show`, then deletes the temporary ref. Values with unexpected characters are
silently ignored.

## Branch protection

The `embargo` branch has a GitHub Ruleset with **Restrict updates** and **Restrict
deletions** enabled, with the "Organization admin" role in the bypass list.
