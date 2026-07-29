# Writing Good Tests

**Read this before adding or changing any test.** It supplements the TDD cycle; it does not permit implementation before a failing test.

## Start with a production break

Name the realistic production break the test must catch before writing it. Choose an existing observable seam and state how the break changes user-visible behavior.

Expected values must be independent of the implementation under test: use a literal or a hand-checked fixture. Never compute the expected value with the production helper or implementation being tested.

## Test behavior, not source text

Do not assert that generated source contains text. With controlled input, run the script or command and assert its output, persisted side effect, and/or exit code. Human-facing prose does not need automated tests.

## Mock only at real boundaries

First understand the real dependency and its side effects. Mock only slow or external boundaries; do not assert mock calls as the behavior under test. If the mock setup becomes complex, prefer an integration test using real collaborating components.

Never add a cleanup method or other public API solely for tests; put test cleanup in test utilities.

## Mutation Check

Before considering a test useful, ask whether at least one test fails if a realistic constant, argument, branch, side effect, or validation is mutated. If not, strengthen the observable behavior assertion.

## TDD order is non-negotiable

Writing production code and then adding tests is still tests-after: it answers what the implementation does, not what it should do. Delete prewritten production code, choose the seam, write the failing behavior test, watch RED, then implement the minimum to reach GREEN.
