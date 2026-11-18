# Architecture - {{PROJECT}}

<!--
Update this file in the same PR whenever architecture, modules, data model, external services,
env vars or deploy change (AGENTS.md "Documentation rules"). Fill each section as the project
grows; delete a guidance comment once real content replaces it.
-->

## Overview

<!-- 3-5 sentences: what the system does, the main components, and how they fit together. -->

## Modules / boundaries

<!-- One entry per module/package/service: its responsibility and what it must not do. -->

## Data model

<!-- Main entities/tables and how they relate. Link the real schema/migrations/types instead of
     duplicating them. -->

## Key flows

<!-- The 2-4 flows a new session most needs to understand (e.g. request lifecycle, a core
     user journey, a background job). One short paragraph each, naming the files involved. -->

## External services

<!-- Third-party APIs, cloud resources, SaaS dependencies - what each is used for and where
     the integration lives in the code. -->

## Env vars

<!-- Point at the real source (.env.example) instead of duplicating values; note here only
     what's not obvious from the variable name. -->

## Deploy

<!-- Where this runs (platform, region, account), how a deploy is triggered, and anything
     manual a new session needs to know before touching it. -->
