---
description: "Investigate a question against primary sources, and write it up"
argument-hint: '<the question to research>'
---

# Research

Answer `$ARGUMENTS` from primary sources and leave the findings in the doc canon, so the next session reads the answer instead of re-deriving it. Reading and writing up only — the design that uses the answer is `/feature_plan`. Pass the question: `/research "does Solid Queue support recurring jobs natively"`.

1. Delegate it if you can. A subagent (or a background agent, if your tool has them) does the reading while this session keeps working. No subagents available → do it inline and say so.

2. Primary sources only: official documentation for the version this app pins, the library's own source in the bundle, the RFC or spec, the first-party API reference. A blog post is a pointer to a source, never the source. Follow every claim back to the thing that owns it.

   ```bash
   bundle show <gem>          # read the gem's own source
   bundle list | grep -i <name>
   ```

3. Separate what the source says from what you infer from it. An inference is labelled as one.

4. Write one markdown file. Cite the source for each claim — a URL, or a file and line in the bundle.

   | The question was about | Where the write-up goes |
   |---|---|
   | A feature being designed | `docs/plans/YYYY-MM-DD-<slug>-research.md`, referenced from the design doc |
   | How this system currently works | The existing doc in `docs/system/` that owns the subject |
   | A procedure someone will repeat | `docs/sop/<slug>.md` |

   `grep` the doc canon first. A doc that already covers the ground gets extended, not duplicated. Do not invent a directory: the canon is `docs/rules`, `docs/plans`, `docs/adr`, `docs/system`, `docs/sop`, `docs/qa`.

5. Add the file to `.llm/README.md` between the marker block for its directory, one line: the link plus the question it answers.

6. Report the answer in two or three lines, with the file path and the strongest source. Say explicitly what you could not establish — an open question named is worth more than a confident guess. Then name what runs next: `/feature_plan` to design on top of the answer, `/update_docs` if the finding contradicts a doc that already exists.
