## Kotlin + Spring Boot conventions

- Kotlin on the JVM (Java 21) and Spring Boot, built through the wrapper (`./gradlew`), never a global Gradle.
- Immutable by default (`val`, data classes); no `!!` outside tests; constructor injection only; Bean Validation on request DTOs at the controller boundary.
- Package structure (by layer, by feature, hexagonal) is whatever the architecture ADR in `docs/decisions/` says; do not invent one here.
- Formatting is Spotless with ktlint: run the format command, never hand-format.
- Tests: JUnit 5 with `kotlin-test`, MockK or Mockito. `@WebMvcTest` for controllers, plain unit tests for domain and application code.
