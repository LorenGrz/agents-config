---
paths:
  - "**/*.java"
---

# Java / Spring Boot

Language and framework rules only. The package structure comes from the project's architecture ADR.

## Language

- Java 21: `record` for DTOs and value objects, `sealed` interfaces with pattern-matching `switch` for closed variants, `var` only when the type is obvious.
- Do not return `null` for absence: `Optional` at API edges (never as a field or parameter). Prefer immutability (`final` fields, `List.copyOf`).
- Never catch `Exception`/`Throwable` broadly; keep the cause when wrapping.

## Spring

- Constructor injection only (single constructor, no `@Autowired`); no field injection.
- `@Transactional` on application-level methods, never on controllers or repositories; `readOnly = true` for reads.
- Validate at the boundary: `@Valid` on request DTOs with Bean Validation constraints; never rely on JPA entity annotations as the only check.
- Controllers bind, delegate to one use-case/service call and map to a DTO. Never expose JPA entities in responses.
- Typed, validated configuration with `@ConfigurationProperties`, not scattered `@Value`.
- One `@RestControllerAdvice` maps domain exceptions to status codes with a consistent error body.

## Tests

- JUnit 5 with Mockito and AssertJ. `@WebMvcTest` for controllers, plain unit tests for domain logic, `@DataJpaTest` or Testcontainers for persistence.
- Name tests `should <expected> when <condition>`. Never hit the network or a shared database.
- Run through the wrapper: `./mvnw test` or `./gradlew test`.
