---
name: list-endpoint
description: Paginated GET list endpoints on a hexagonal Spring backend - two-step query to avoid N+1 and broken pagination, repository port with Pageable, query service, controller, response DTO, test. Use for "endpoint de listado", "agregar paginación", "filtrar por", "list endpoint", "paginated endpoint", "listar todos los X", "endpoint con filtros". Auto-triggers when a paginated or filtered query endpoint is requested or extended.
---

# Paginated list endpoint

## Two-step query (never one paginated query with fetch-joined children)

A join over children multiplies rows and breaks the page size. Instead:

```
step 1: ids with filters + Pageable   ->  Page<UUID>
step 2: full entities by those ids with JOIN FETCH of the children
```

```java
// Spring Data repository
@Query("SELECT x.id FROM XJpa x WHERE x.ownerId = :ownerId")
Page<UUID> findIdsByOwnerId(@Param("ownerId") UUID ownerId, Pageable pageable);

@Query("SELECT x FROM XJpa x LEFT JOIN FETCH x.items WHERE x.id IN :ids")
List<XJpa> findAllWithItemsByIdIn(@Param("ids") List<UUID> ids);

// Adapter: keep the page order of step 1
Page<UUID> ids = jpaRepo.findIdsByOwnerId(ownerId, pageable);
if (ids.isEmpty()) return Page.empty(pageable);
Map<UUID, XJpa> byId = jpaRepo.findAllWithItemsByIdIn(ids.getContent()).stream()
    .collect(Collectors.toMap(XJpa::getId, Function.identity()));
return ids.map(id -> mapper.toDomain(byId.get(id)));
```

## Layers

- **Repository port** (domain): `Page<X> findByOwnerId(UUID ownerId, Pageable pageable)` plus one method per filter combination that is really needed; no speculative filters.
- **Query service** (application): one class for reads; `findById` throws not-found, list methods return `Page<X>`.
- **Controller**: `@RequestParam` filters (optional ones `required = false`) and `Pageable`; map with `.map(XResponse::from)`. If the project wraps pages in an envelope, that happens in one place (advice or shared mapper), never per controller.
- **Response DTO**: an immutable record with a static `from(domain)`; expose only what the client needs.
- Bound the page size (`spring.data.web.pageable.max-page-size`) and whitelist sortable fields.

## Test

```java
when(queryService.findByOwnerId(eq(ownerId), any())).thenReturn(new PageImpl<>(List.of(entity)));
mockMvc.perform(get("/x-resources").param("ownerId", ownerId.toString()))
    .andExpect(status().isOk())
    .andExpect(jsonPath("$.content[0].id").value(entity.getId().toString()));
```

Use `eq()` for the known argument and `any()` for `Pageable` (adjust the JSON path to the project's response shape). Cover: empty page, a filter, the page-size bound.
