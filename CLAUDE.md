# Feedback Pipeline Instructions

When triggered with client feedback, follow these steps:

1. Read the feedback JSON provided
2. Create a new branch: feedback/row-<rowIndex>
3. Make the changes the client requested
4. Commit with message: fix: feedback #<rowIndex> - <brief description>
5. Push the branch
6. Open a GitHub PR using: gh pr create --base main --fill
7. Run: node ~/willbickel-ai/feedback-pipeline/mark-processed.js --row <rowIndex>

Rules:
- Never push directly to main
- Only change what was asked
- One PR per feedback row
