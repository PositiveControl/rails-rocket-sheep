---
description: "Interview a design in rounds until nothing is silently assumed"
argument-hint: '<the plan, decision, or question to sharpen>'
---

# Grill

Interview the user relentlessly about `$ARGUMENTS` until you both reach the same understanding of it. Sharpening only — the design doc is `/feature_plan`, the implementation plan is `/task_plan`, and a question that needs its own session is `/segue`. Pass the thing to sharpen: `/grill "returns for auction items"`.

Use it before a gate, not instead of one. G1 and G2 are still the user's approval.

1. Map the subject as a **design tree**: every decision branches into the decisions that hang off it.

2. Compute the **frontier**: every decision whose prerequisites are already settled, meaning the questions you can ask *now* without guessing at answers you have not heard yet.

3. Ask the whole frontier in one round, numbered, each with your recommended answer:

   ```
   ❓ **Q1** — **<question title>**: <question body, including the options if there are options>

   ➡️ <your recommended answer>

   ---

   ❓ **Q2** — **<question title>**: <question body>

   ➡️ <your recommended answer>
   ```

4. **Wait for the answers.** A question whose answer depends on another question still open in this round belongs to a *later* round, not this one.

5. Recompute the frontier from what the answers settled, and ask the next round. Settled decisions push the frontier outward and unblock what depended on them.

6. Facts are yours to find; decisions are the user's. A frontier question that needs a fact from the repo, the schema, the tracker, or a dependency is one you go and answer yourself — read the code, run the query, use a subagent if your tool has them. Do not block the rest of the round on it: only the questions downstream of that fact wait.

7. Done when the frontier is empty: every branch visited, nothing left silently assumed. Summarise the settled decisions and the rejected alternatives, in the shape the next command needs:

   | Started from | Findings go to |
   |---|---|
   | A feature not yet designed | **Approach** and **Rejected alternatives** in the design doc `/feature_plan` writes |
   | An issue about to be planned | **Background/Context** and **Flagged decisions** in the task file `/task_plan` writes |
   | A question inside implementation | The task file's notes, or `/segue` if it needs its own session |

8. Do not act on the outcome. Say what runs next and stop:

   ```
   Shared understanding reached. Next: /feature_plan "<subject>"   (or /task_plan <issue> if the issue already exists)
   ```
