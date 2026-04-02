# Public-Only Validation Pass

This page is kept as a compatibility note.

The older label, "public-only validation pass", was broader than the script's actual scope.

Use the current document instead:

- [Targeted public hardening validation pass](20-targeted-public-hardening-validation-pass.md)

Use the current entrypoint instead:

```sh
./maint/validate-public-hardening-surface.ksh
```

The legacy command remains available as a compatibility wrapper:

```sh
./maint/final-public-validation-pass.ksh
```
