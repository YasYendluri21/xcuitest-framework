# BluDelivery — XCUITest framework

A UI automation framework for an iOS app, built the way one should be: page objects, a
synchronization layer with no sleeps in it, launch-argument state seeding, and a Python tooling
layer that turns `.xcresult` bundles into something CI can use.

**Swift** (XCUITest, SwiftUI) · **Python** (runner, result parsing, reporting) · **XcodeGen** · **GitHub Actions**

```
11 tests · 0 failures · iPhone 16 Pro, iOS 18.6
```

---

## Running it

```bash
brew install xcodegen
xcodegen generate
python3 tools/runner.py
```

The app under test is included — a small SwiftUI water-delivery app with login, cart, delivery
tiers, tipping, and a checkout that can be made to fail on demand. It exists so the suite has
something real to drive: every async step is genuinely async, so a test that doesn't synchronize
properly actually fails.

```bash
python3 tools/runner.py --only LoginTests          # one class
python3 tools/runner.py --device "iPhone SE (3rd generation)"
python3 tools/runner.py --shard 1/3                # CI
```

---

## The synchronization layer

This is the part that decides whether an XCUITest suite is trustworthy.

XCUITest gives you two tools and neither is sufficient. Queries are lazy — `app.buttons["x"]`
doesn't touch the app until you ask it something — but when you do ask, it answers **now**, with no
retry. And `waitForExistence(timeout:)` only covers existence: an element can exist while being
off-screen, disabled, or mid-animation.

So `Wait` is built on `XCTNSPredicateExpectation`, which polls, and expresses the condition that
actually matters:

```swift
Wait.hittable(submitButton)        // exists AND can receive a touch
Wait.disappears(spinner)
Wait.label(total, equals: "$19.28") // polls — the total recalculates after a round trip
```

**`Thread.sleep` appears nowhere in this repository.** A fixed sleep is slow when the app is fast,
flaky when it's slow, and it hides latency regressions entirely.

Failures report what was actually observed rather than just timing out:

```
Timed out after 10s waiting for “checkout.placeOrder” to be hittable.
  exists: true, hittable: false
```

That second line is usually the whole diagnosis — the element is there, something is covering it.

---

## Page objects

Screens expose **actions and queries, never raw elements**. A test that reaches into
`app.buttons[...]` has defeated the point, so the base `Screen` protocol routes every interaction
through helpers that wait first:

```swift
let checkout = ProductListScreen(app: app)
    .awaitDisplayed()
    .add("SPRING-40")
    .awaitCartCount(1)
    .openCart()
    .checkout()

checkout.selectUltra().tip(10).awaitTotal("$19.28")
```

Two details worth calling out:

**`type(_:into:)` clears before typing.** `typeText` appends, so a field with existing content
silently concatenates — one of the quieter sources of wrong-value bugs in UI suites.

**Navigation returns the next screen type.** `openCart()` returns a `CartScreen`, already waited
for. The compiler then prevents calling a checkout method while you're on the cart.

---

## Identifiers are shared between targets

`AccessibilityIdentifiers.swift` is compiled into **both** the app and the test bundle:

```yaml
BluDeliveryUITests:
  sources:
    - path: BluDeliveryUITests
    - path: BluDelivery/Support/AccessibilityIdentifiers.swift
```

So a renamed identifier is a **compile error in the tests**, not a query that silently stops
matching at runtime. It's the highest-value convention in an XCUITest suite and it costs one line
of project config.

---

## State comes from launch arguments, not the UI

```swift
app = AppLauncher().withSeededCart().failingCheckout().launch()
```

A test for the checkout total shouldn't fail because the login screen changed. Seeding state at
launch keeps each test's failure surface to the thing it's actually testing — and it makes the
error path reachable deterministically instead of hoping a sandbox gateway misbehaves.

The same mechanism disables animations under test, so the suite isn't waiting on transitions.

---

## Two SwiftUI accessibility traps this suite found

Both were real failures during development, and both are worth knowing:

**A container with an identifier swallows its children.** Putting `.accessibilityIdentifier` on the
product row made SwiftUI treat the whole row as one accessibility element — the Add button inside
it became invisible to XCUITest *and* to VoiceOver. The fix is `.accessibilityElement(children:
.contain)`, which keeps the row addressable while leaving its children reachable.

**The same applies to any grouping view.** The order-confirmation `VStack` had the identical
problem. If an element is in the view but not in `app.debugDescription`, this is almost always why.

Note what the second one means: the test suite caught a real VoiceOver defect, not just a test
problem.

---

## The Python layer

`xcodebuild` prints a readable log and writes a result bundle. Neither is usable by anything
downstream, which is why most teams end up regex-parsing console output.

`tools/xcresult.py` reads the bundle through `xcrun xcresulttool` and flattens it into dataclasses.
`tools/runner.py` uses that to:

- resolve a simulator **by name** — names are ambiguous across runtimes, so passing one straight to
  `xcodebuild` fails with an unhelpful error; this resolves to a UDID first
- shard across parallel simulator clones for CI
- write a Markdown summary and a JSON artefact, and exit non-zero on failure
- flag tests slower than a threshold, which is how a suite's runtime stays honest

It handles **both** xcresulttool APIs — the Xcode 16 `test-results` tree and the legacy object
graph, which also disagree on vocabulary ("Passed" versus "Success"). A test tool that breaks on an
Xcode upgrade is worse than no tool.

---

## CI

[`.github/workflows/ui-tests.yml`](.github/workflows/ui-tests.yml) runs the suite on every push
across two device classes — iPhone 16 Pro and iPhone SE. Two devices rather than two shards,
deliberately: a layout failure on a small screen is a real bug that sharding would never surface.
The Markdown report goes to the job summary; the `.xcresult` is uploaded on failure.

---

## Layout

```
project.yml                     XcodeGen manifest — the .xcodeproj is a build artifact
BluDelivery/                    The app under test (SwiftUI)
  Support/AccessibilityIdentifiers.swift   Compiled into both targets
BluDeliveryUITests/
  Framework/Wait.swift          Synchronization — predicate-based, no sleeps
  Framework/App.swift           Launch-argument state seeding
  Framework/BaseTestCase.swift  Shared setup, failure attachments, xcresult activities
  Screens/                      Page objects
  Tests/                        Login, checkout flows, accessibility
tools/
  runner.py                     Build, run, shard, report
  xcresult.py                   Result-bundle parsing, both xcresulttool APIs
```
