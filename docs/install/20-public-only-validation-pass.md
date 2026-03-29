# Public-Only Validation Pass

Run this after applying the latest public cleanup or gap-closure patch.

## Validation flow

From the repo root:

```sh
./scripts/phases/phase-15-apply.ksh
./scripts/phases/phase-15-verify.ksh
./scripts/phases/phase-16-apply.ksh
./scripts/phases/phase-16-verify.ksh
./maint/final-public-validation-pass.ksh
```

## Expected result

The repo should pass without:

- private hostname references
- tracked operator input files containing real values
- missing phase 15 or 16 public-safe assets
- malformed generated examples
