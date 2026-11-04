---
name: spring-testing
description: Testing conventions for Spring Boot services and controllers - Mockito unit tests for application services, @WebMvcTest for controllers, domain helpers, naming, coverage gap analysis. Use for "escribir tests", "agregar tests", "cubrir con tests", "cobertura", "tests del servicio/controller", "write tests", "add tests", "WebMvcTest", "what tests are missing".
---

# Spring testing

## Application service: unit test with mocked ports

```java
@ExtendWith(MockitoExtension.class)
class CreateXServiceTest {
  @Mock XRepository repository;
  @Mock DependencyLookup lookup;
  @InjectMocks CreateXService service;

  @Test
  void create_throwsNotFound_whenDependencyMissing() {
    when(lookup.findById(any())).thenReturn(Optional.empty());
    assertThatExceptionOfType(NotFoundException.class)
        .isThrownBy(() -> service.create(new CreateXCommand(UUID.randomUUID(), "name")));
  }

  @Test
  void create_savesAndReturns_whenDependencyExists() {
    when(lookup.findById(any())).thenReturn(Optional.of(snapshot()));
    when(repository.save(any())).thenAnswer(i -> i.getArgument(0));
    X result = service.create(new CreateXCommand(UUID.randomUUID(), "name"));
    assertThat(result.getStatus()).isEqualTo(XStatus.DRAFT);
    verify(repository).save(any());
  }
}
```

(Kotlin: same shape with MockK or Mockito-Kotlin and backtick names.)

## Naming

`method_throwsType_whenCondition` for errors, `method_result_whenCondition` for behavior.

## Domain helpers inside the test

Build aggregates in the initial state with `create()`; for any other state use `restore()` so the test does not replay the transition flow. Do not use `restore()` paths in service tests (it belongs to mapper and model tests).

## Controller: `@WebMvcTest`

```java
@WebMvcTest(XController.class)
@AutoConfigureMockMvc(addFilters = false)
@Import({ ExceptionHandlerAdvice.class })      // the project's @RestControllerAdvice
class XControllerTest {
  @Autowired MockMvc mockMvc;
  @MockitoBean CreateXService createService;    // @MockitoBean (Spring Boot 3.4+/4), not @MockBean
  @MockitoBean QueryXService queryService;
}
```

If controllers authorize through a service, mock it and clear the `SecurityContext` in `@AfterEach`. Assert HTTP status and the serialized shape only. Error bodies: assert the project's error code and field errors for validation failures.

## Coverage gap analysis (per service)

- [ ] not-found for every external dependency that is looked up
- [ ] invalid state transition (illegal state) and invalid input (illegal argument)
- [ ] null/blank input when it applies
- [ ] full happy path: final state plus `verify(repository).save(...)`
- [ ] side-effect ports receive the instance returned by `save()`, not the pre-save one

## Do not

- Use `@MockBean` where `@MockitoBean` exists.
- Replace the database with an in-memory fake in service tests; mock the port.
- Write integration tests around adapters that are still stubs.
- Assert exact timestamps; assert not-null or a bound (`isBefore(now.plusSeconds(1))`).
