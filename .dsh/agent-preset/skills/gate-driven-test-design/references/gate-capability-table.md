# Gate Capability Table

> 逐字照搬自 `gdd-spec-prompt.md`。这是静态字典，价值在准确完整，不要改写。

## Gate Capability Table

| Gate                 | Proves                                                                                                                                   |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `e2e gate`           | A real user path or external invocation path can complete from entry point to visible result.                                            |
| `smoke gate`         | A runnable target can start, be accessed, and satisfy the minimum healthy path.                                                          |
| `release gate`       | Release candidate inputs, compatibility, versioning, and release constraints are satisfied.                                              |
| `observability gate` | New behavior can be observed, diagnosed, alerted, or rolled back through metrics, logs, traces, alerts, or rollback signals.             |
| `integration gate`   | Modules, components, services, or storage layers collaborate correctly in a controlled environment.                                      |
| `contract gate`      | API, event, CLI, SDK, or public interface producer and consumer boundaries remain stable.                                                |
| `schema gate`        | Data, message, or document structure matches field, hierarchy, and structural expectations.                                              |
| `config gate`        | Environment values, runtime config, feature flags, or deployment config are complete and consistent.                                     |
| `migration gate`     | Persistent data or state changes can apply safely and remain compatible with existing data.                                              |
| `unit gate`          | A function, class, module, or pure logic unit handles inputs, outputs, branches, and errors correctly.                                   |
| `fixture gate`       | Representative examples, fixtures, or snapshots produce stable expected behavior.                                                        |
| `property gate`      | Invariants, boundary properties, or input-class rules hold beyond a single example.                                                      |
| `type-check gate`    | Static type relationships, parameter shapes, return shapes, and exhaustiveness constraints prove a concrete feature-risk constraint.     |
| `lint gate`          | Static rules, forbidden patterns, dependency boundaries, naming, or dead-code constraints prove a concrete feature-risk constraint.      |
| `build gate`         | Build, packaging, or asset processing proves a build-consumed declaration or registration needed for a concrete feature-risk constraint. |

## Level Perspective Table

| Gate level | Perspective                                 | Common Gates                                                                        | Project facts to inspect                                                                                                                                    | Candidate expansion explains                                                                                                       |
| ---------- | ------------------------------------------- | ----------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| L4         | Visible behavior and operability            | `e2e gate`, `smoke gate`, `release gate`, `observability gate`                      | User paths, page/API entry points, e2e specs, smoke scripts, release docs, observability conventions                                                        | How real users or external callers complete the path, what they see, and which minimal runtime or release signals prove usability. |
| L3         | System collaboration and boundary contracts | `integration gate`, `contract gate`, `schema gate`, `config gate`, `migration gate` | Module collaboration, service calls, storage reads/writes, API contracts, data structures, runtime config, state migrations                                 | Which boundaries collaborate, which contracts and schemas stay stable, and which config or state changes are necessary.            |
| L2         | Logic rules and branches                    | `unit gate`, `fixture gate`, `property gate`                                        | Domain rules, function behavior, error branches, boundary cases, fixtures, existing unit tests                                                              | Which inputs, outputs, branches, errors, boundary cases, fixtures, and invariants define correct logic.                            |
| L1         | Feature-specific static constraints         | `type-check gate`, `lint gate`, `schema gate`, `build gate`                         | Type declarations, public schemas, generated client shapes, registries, config maps, dependency boundaries, forbidden patterns, build-consumed declarations | Which static gate proves a concrete risk constraint that protects a higher-level behavior, boundary, or rule.                      |
