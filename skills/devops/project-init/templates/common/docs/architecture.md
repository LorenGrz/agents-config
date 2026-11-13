# Architecture - {{PROJECT}}

<!--
Update this file whenever architecture, modules, data model, external services, env vars,
or deploy change - in the same PR as the code change (see AGENTS.md "Documentation rules").
This is a skeleton: fill each section in as the project grows, delete the guidance comments
once real content replaces them.
-->

## Overview

<!-- 3-5 sentences: what the system does, the main components, and how they fit together. -->

## Modules / boundaries

<!-- One entry per module/package/service: its responsibility and what it must not do.
     Table or list, whichever reads clearer for this stack. -->

## Data model

<!-- Main entities/tables and how they relate. Link to the actual schema/migrations/types
     instead of duplicating them if the project already has one. -->

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
