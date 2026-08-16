# Seeded fault

This branch exists to be red. **Do not merge it.**

A test suite that has only ever been green proves that the code passes the tests.
It does not prove the tests would notice if the code were wrong. So the original
defect was put back — both halves of it, verbatim — and the suites were run again.

## What was reverted

Two independent code paths turned "we have no rating" into **Level 1**: the lowest
score on the scale, shown to a recruiter as a real judgement about a candidate who
may never have been asked about that skill.

**`api/app/domain/assessments/rating.rb`**

```ruby
def coerce_level(raw)
  raw.to_i.clamp(1, 5)
end
```

`nil.to_i` is `0`, and `0.clamp(1, 5)` is `1`. The expression reads like defensive
input validation. It manufactures a score.

**`web/src/utils/constants.ts`**

```ts
const n = parseInt((level as string).replace(/\D/g, ""), 10);
return isNaN(n) ? 1 : n;
```

The same invention, made independently on the client — so fixing one side alone
would have left the fabricated Level 1 on screen.

## Result

| Suite | Before | With the fault seeded |
|---|---|---|
| RSpec | 62 examples, 0 failures | **62 examples, 14 failures** |
| Vitest | 48 tests, 0 failures | **19 failed, 29 passed, 2 uncaught exceptions** |

Verbatim output: [`rspec.txt`](rspec.txt), [`vitest.txt`](vitest.txt).

Three things are worth reading in that output rather than just counting it.

**The failures name the defect.** They do not read as `expected 1, got nil`. They
read as *"refuses to invent a level from nil"*, *"does not invent a rating from a
non-numeric level (the model returned prose where a level belongs)"*. A test whose
name describes the bug tells the next person what broke without opening the file.

**Coverage is layered, not duplicated.** The domain object fails on all nine bad
inputs — `nil`, `0`, `-1`, `99`, `2.5`, `""`, `"abc"`, `[]`, `{}`. The generator
fails separately on five, through the real service, so the guarantee is checked
where it is relied on and not only where it is implemented.

**The client half fails louder than expected.** Vitest reports two uncaught
exceptions on top of the assertion failures:

```
TypeError: Cannot read properties of null (reading 'replace')
 ❯ Module.parseLevel src/utils/constants.ts:11:40
 ❯ SkillPortfolioCard src/components/portfolio/SkillPortfolioCard.tsx:27:19
```

That is the crash that would have shipped if the API fix had merged without the
frontend one. `parseLevel(null)` throws, and the portfolio page white-screens. The
suite located it in the component that would have taken the page down.
