**.llm doc structure**
.llm directory hold all critical info engineer need for full system context

```
.llm
- /tasks: Each task has its own markdown file following the task_template.md structure. This document is used for task planning and execution.
- README.md: Index of all documentation we have so people know what and where to find things

.docs
- /qa: Documents for QA testing of features, e.g. docs/qa/BATCH_STATUS.md
- /system: Document the current state of the system (project strucutre, tech stack, database schema, etc.)
- /sop: Standard Operating Procedures for common tasks (e.g. how to add a schema migration, conventions, tools to use, testing, etc.)
```

# When asked to initialize documentation, 
  - Deep scan codebase, front + backend, get full context
  - Generate system + architecture docs (store in /docs/system):
    - project architecture (project goal, structure, tech stack, integration points)
    - database schema (tables, fields, relationships)
    - Critical or complex components → separate files in /system
  - Update .llm/README.md with links to all docs — living index of all .llm documentation, anyone look at file, see where it came from
  - Consolidate docs hard. No overlap between files. Most basic version = project_architecture.md only, expand from there.

# When asked to update the documentation
  - Read README.md first — know what docs exist
  - Update relevant system/architecture docs, or SOP (in /docs/sop) for mistakes made
  - Always end: update README.md with index of all documentation files