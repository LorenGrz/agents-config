## Java + Spring Boot conventions

- Java 21 and Spring Boot. Always build through the wrapper (`./mvnw` or `./gradlew`), never a global Maven/Gradle.
- Constructor injection only (no field injection); `record`s for DTOs and value objects; Bean Validation on request DTOs at the controller boundary.
- Package structure (by layer, by feature, hexagonal) is whatever the architecture ADR in `docs/decisions/` says; do not invent one here.
- Formatting is Spotless with google-java-format: run the format command, never hand-format.
- Tests: JUnit 5 + Mockito. `@WebMvcTest` for controllers, plain unit tests for domain and application code; mock at the boundary.
