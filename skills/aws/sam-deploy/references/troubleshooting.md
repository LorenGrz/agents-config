# Troubleshooting

Read when: `sam build`, `sam deploy`, or the first request to the deployed API fails.

| Error | Cause | Fix |
|-------|-------|-----|
| `No changes to deploy. Stack X is up to date` | Lambda code unchanged from last build | Run `sam build` again — if still same hash, the code genuinely didn't change |
| `CAPABILITY_IAM` missing | Template creates IAM resources | Add `capabilities = "CAPABILITY_IAM"` to samconfig.toml |
| `Missing Authentication Token` from API Gateway | Request URL missing the stage prefix | Ensure all `href` values include the stage path (e.g. `/prod/`) |
| `Error: Running NodejsNpmBuilder:NpmTest` and fails | `test` script exits non-zero | Add `"test": "echo ok"` to package.json if no tests yet |
| `Uploaded artifact is too large` | Lambda ZIP > 50 MB zipped (direct upload) or > 250 MB unzipped, layers included | Point `CodeUri` at a folder that holds only runtime code (a build output, not the repo root); use Lambda Layers for deps |
| `Cannot resolve S3 bucket` | First deploy on fresh account | Run `sam deploy --guided` once to create the SAM managed bucket |
