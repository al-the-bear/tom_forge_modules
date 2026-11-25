# Tom Forge Modules

The libraries of the Tom construction kit: Tom Forge's side for building
IDEs and Webwork's side for building business applications, side by side.
Applications — Tom Forge itself (`tom_forge`), Webwork, new projects — depend
on these libraries only, never on another top-level project.

The layers:

1. `tom_ai` with `tom_modules`: the framework and the business models and UI
   modules, free of Forge.
2. **`tom_forge_modules`** (this repository): the kit itself (`tom_forge_core`,
   `tom_editors_shared`, `tom_forge_kit`, `tom_forge_shared_ui`, the panel
   shell `tom_forge_shell`), the editors and their plugins, the adapters, the
   views, the terminal, the quest workbench, the agentic views, the hosts, the
   full-desktop umbrella `tom_forge_ui`, the kit's examples, and every
   component that follows the kit's contracts.
3. Applications on top.

The packages, their layers within this repository and the contracts between
them: [`_agent_guidelines/platform_architecture.md`](_agent_guidelines/platform_architecture.md);
the placement rule: [`_agent_guidelines/index.md`](_agent_guidelines/index.md).

## License

Every package in this repository is licensed BSD-3-Clause — see
[LICENSE](LICENSE), which each package carries byte-identically.
