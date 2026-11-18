---
paths:
  - "**/*.kt"
  - "**/*.kts"
---

# Kotlin / Spring Boot

Reference implementation: `~/projects/booklibre/backend` (layered, domain-centred).

## Layers and responsibilities

- **domain/** — entities + ALL business logic + ALL validation. Methods named in business language. Throw `BusinessException` / `ConflictException` / `NotFoundException` from here; never return null for a rule violation. Validation and construction go through `companion object` factories (`Libro.crear`, `LibroFiltros.desdeRequest`) that validate before building. Polymorphism = `abstract class` + subtypes overriding only the varying rule. Value/data carriers = `data class`.
- **services/** — orchestrators only. `@Service`, constructor-injected repositories, `@Transactional` on writes (`readOnly = true` on reads). Load from repo → `orElseThrow { NotFoundException(...) }` → delegate to domain methods → save. Handle only what comes back from the repository: missing rows, cross-aggregate conflicts (repo existence queries), batching, locks. No business rule lives in the service.
- **controllers/** — `@RestController`, `@RequestMapping("/api/...")`. Thin: bind `@RequestParam` / `@PathVariable` / `@Valid @RequestBody` DTO, call one service method, map the result to a DTO with a mapper extension before returning. `@Transactional(readOnly = true)` on GET.
- **dtos/** — request and response `data class`es; `PagedResponse<T>` for pages.
- **mappers/** — extension functions `Domain.toDTO(...)`. All serialisation mapping lives here — never in the domain, never inline in the controller body. Overload for simple vs service-enriched shapes.
- **exceptions/** — `open class BusinessException(msg)`, `ConflictException : BusinessException`, `NotFoundException`, `Forbidden/Unauthorized`; a `@RestControllerAdvice` maps them to status codes.
- **repository/** split by store (jpa / mongo / redis). **readmodels/** for query projections.

## Language

- `val` by default; immutable collection types in signatures.
- No `!!`; model absence with `?` and handle it.
- `when` exhaustively over enums / sealed types.
- Compiler stays strict (`-Xjsr305=strict`).

## Tests — Kotest `DescribeSpec`, `IsolationMode.InstancePerTest`

- **domain/*Spec.kt** — pure unit tests. `describe`/`it`, `shouldBe`, `assertThrows<BusinessException>`. One `it` per rule and per validation branch.
- **services/*Spec.kt** — in-memory fake repositories (`testing/inmemory/`). Cover happy path, `NotFound`, and conflict paths. `*SpringSpec.kt` for the Spring-context variant.
- **controllers/*Test.kt** — `@WebMvcTest(XController::class)`, `@MockBean` the service, `MockMvc`, `@WithMockUser`, JsonPath. Assert HTTP status + serialised shape only.
- New behaviour ships with a test at the layer that owns it. `./gradlew test` (Jacoco report runs `finalizedBy`).
