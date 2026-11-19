# Tom Forge Platform Secrets

Forge's secret storage in the platform keychain (`PlatformSecretStorage`, over
`flutter_secure_storage`) for the panel shell (`tom_forge_shell`).

`forgePlatformSecretComponents` is it as `ForgeShellComponents`: a shell over a
folder on disk keeps its secrets in the keychain, any other in memory.

Part of Tom Forge; the layers are in `tom_forge/_copilot_guidelines/platform_architecture.md`.

## License

BSD-3-Clause; see [LICENSE](LICENSE).
