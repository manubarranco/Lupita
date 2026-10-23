# Lessons

What went wrong once, so it does not go wrong twice.

| ID | Lesson | Where it bit us |
|---|---|---|
| L01 | Log every import that falls back to heuristics | Two weeks of silent bad imports before D002 was enforced |
| L02 | Never round quantities before scaling | Scaling a half batch turned 7 g of salt into 5 g (D003, E1-S3) |
| L03 | Two editors on one recipe means conflicts nobody can resolve | Prototype of shared editing; led to D005 and Q05 |
| L04 | Test imports against saved pages, not live sites | Sites changed under the test suite; see EXP-01 fixtures |
