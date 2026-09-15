# ArkTS and HarmonyOS Application Performance Optimization Guide

This guide consolidates the optimization practices in the course slides `IMG_4034.PNG` through `IMG_4053.PNG`, read in filename order. It is intended for both engineers and coding agents that are improving an existing HarmonyOS application or establishing conventions for a new ArkTS codebase.

The examples preserve the intent of the slides while correcting obvious presentation-only issues such as `setTimeOut` casing, invoking a function before passing it to `setTimeout`, inconsistent generic types, and incomplete cleanup. API import paths can differ by HarmonyOS SDK/API level, so confirm them against the repository's configured SDK before applying an example.

## How to use this guide

Do not apply every technique mechanically. First identify the application's actual bottleneck, choose the smallest relevant change, and measure the result on representative devices.

For an existing repository:

1. Record a baseline for startup time, first-frame time, frame loss/jank, response latency, CPU time, and memory.
2. Search for the risk patterns listed in the repository audit section.
3. Apply one focused optimization at a time.
4. Verify correctness, lifecycle cleanup, thread safety, and visual behavior.
5. Re-run the same measurements and retain only changes with a meaningful benefit.
6. Add only the repository-relevant, verified rules to `AGENTS.md`; do not copy this entire guide into it.

For a new repository, use the checklist near the end as a default design review. Treat cache sizes, worker counts, frame rates, preload targets, and deferral delays as values to tune rather than universal constants.

## 1. Use concurrency to improve startup and responsiveness

### 1.1 Parallelize independent startup work with TaskPool

Source: `IMG_4034.PNG`

A common startup problem occurs on a page with several tabs. The first tab is rendered, but opening the second tab then triggers network loading and parsing, so the second tab appears slowly. Independent expensive work can be submitted to `TaskPool` before the user needs its result.

Use this pattern when work:

- is independent of the UI thread;
- is CPU-heavy, blocking, or expensive enough to delay rendering;
- can be expressed using transferable or sendable inputs and outputs; and
- does not mutate ArkUI component state from the background task.

The following is a cleaned-up version of the slide's pattern. `http.request()` is an application-provided placeholder; use the repository's actual networking layer and observe the concurrency restrictions of that API.

```ts
import taskpool from '@ohos.taskpool';
import { BusinessError } from '@kit.BasicServicesKit';

@Concurrent
function getInfoFromHttp(): string[] {
  // Load and/or parse data without touching ArkUI component state.
  return http.request();
}

@Entry
@Component
struct HomePage {
  @State private secondTabItems: string[] = [];

  aboutToAppear(): void {
    // Start work early so the second tab can be ready before it is selected.
    this.requestByTaskPool();
  }

  private requestByTaskPool(): void {
    const task: taskpool.Task = new taskpool.Task(getInfoFromHttp);

    try {
      taskpool.execute(task, taskpool.Priority.HIGH)
        .then((result: object) => {
          // This continuation may update UI-owned state after validation/casting.
          this.secondTabItems = result as string[];
        })
        .catch((error: BusinessError) => {
          logger.error(TAG, `TaskPool execution failed: ${error.toString()}`);
        });
    } catch (error) {
      logger.error(TAG, `Task submission failed: ${(error as BusinessError).toString()}`);
    }
  }
}
```

Practical rules:

- Submit only work likely to be needed. Cancel or ignore stale results when the page disappears or the request key changes.
- Do not capture a component instance, UI object, or other non-transferable state in a concurrent function. Pass explicit data.
- Use high priority sparingly. Marking every task high priority defeats prioritization and can contend with first-frame work.
- Keep result application on the UI side small. Parsing a large payload in the completion callback simply moves the bottleneck back to the main thread.
- Handle both synchronous submission failures and asynchronous task failures.

### 1.2 Move costly work off the UI thread

Source: `IMG_4035.PNG`

The UI thread is responsible for rendering and interaction. Time-consuming operations on it block frame production and increase frame loss. The slides recommend `TaskPool` or `Worker` background threads for work such as:

- video decompression or decoding;
- large network-response processing;
- data transformation, parsing, or filtering; and
- other sustained computation that does not require UI access.

Choose the concurrency mechanism by workload shape:

- Use `TaskPool` for independent, task-oriented work where the system can schedule and reuse worker resources.
- Use `Worker` for a long-lived background execution context, ordered message processing, or work that benefits from retaining worker-local state.

The course measurements illustrate the possible impact. In five test cases, frame-loss rates without a worker were approximately `66.20%`, `66.50%`, `50%`, `65.50%`, and `57%`; with a worker they were approximately `13%`, `7.47%`, `3.10%`, `0.80%`, and `0.90%`. These figures demonstrate direction, not a guarantee: device, build mode, workload, and measurement method determine the actual result.

Threading is not free. Avoid moving tiny operations to a worker when serialization, copying, scheduling, and synchronization cost more than the work itself. Batch small units where appropriate and measure end-to-end latency.

### 1.3 Defer unavoidable main-thread work until after the first frame

Source: `IMG_4036.PNG`

If an operation must execute on the main thread, prefer an asynchronous API or delay nonessential initialization so it does not block first-frame drawing. The slide uses Web engine initialization as the example.

Avoid synchronous initialization in the critical startup path:

```ts
private initWeb(): void {
  webview.WebviewController.initializeWebEngine();
}

aboutToAppear(): void {
  // Avoid doing this directly when it delays the first frame.
  this.initWeb();
}
```

Defer it correctly by passing a callback rather than calling the function immediately:

```ts
private initWeb(): void {
  webview.WebviewController.initializeWebEngine();
}

aboutToAppear(): void {
  // A short deferral allows first-frame work to proceed first.
  setTimeout(() => this.initWeb(), 10);
}
```

Use deferral only for work that is not required for the first visible state. A timer changes scheduling; it does not make expensive work cheaper. Too many deferred tasks can create a post-startup stall, so stagger, prioritize, or move heavy work to a background thread instead.

### 1.4 Use Sendable objects for efficient cross-concurrency transfer

Source: `IMG_4037.PNG`

ArkTS `Sendable` objects can be passed by reference between concurrent instances. Compared with serializing an ordinary object, this can reduce transfer overhead and preserve class methods. Sendable data must obey the platform's sendability and thread-safety restrictions.

Ordinary object, typically copied or serialized for cross-thread communication:

```ts
class Book {
  recordId_: string = '';
  title_: string = '';
  content_: string = '';
  authorList_: Array<string> | null = null;

  setTitle(title: string): void {
    this.title_ = title;
  }
}
```

Sendable form:

```ts
import { collections } from '@kit.ArkTS';

@Sendable
class Book {
  recordId_: string = '';
  title_: string = '';
  content_: string = '';
  authorList_: collections.Array<string> = new collections.Array<string>();

  setTitle(title: string): void {
    this.title_ = title;
  }
}
```

Do not treat reference transfer as permission for unsynchronized mutation. Define ownership clearly, prefer immutable payloads where possible, and avoid concurrent writes to shared data.

## 2. Preload and stage content to improve startup and response time

### 2.1 Optimize Web components with preconnect, prefetch, and prerendering

Source: `IMG_4038.PNG`

Web-heavy pages can hide network and engine startup latency by doing likely future work early. The slide lists these techniques:

- initialize the Web engine ahead of first use;
- pre-resolve DNS;
- preconnect to a likely origin;
- prefetch the next page; and
- prerender content that is very likely to be shown.

#### Preconnect

Initialize the Web engine before requesting a preconnection. The URL should be an origin the application is likely to load soon.

```ts
import webview from '@ohos.web.webview';

function prepareWebOrigin(): void {
  webview.WebviewController.initializeWebEngine();
  webview.WebviewController.prepareForPageLoad(
    'https://www.example.com',
    true,
    2
  );
}
```

The boolean and socket-count arguments must be selected according to the SDK contract and actual traffic pattern. Excessive speculative connections consume sockets, memory, radio time, and power.

#### Prefetch a likely next page

```ts
import webview from '@ohos.web.webview';

@Component
struct ArticlePage {
  private controller: webview.WebviewController =
    new webview.WebviewController();

  build() {
    Column() {
      Web({
        src: 'https://www.example.com',
        controller: this.controller
      })
        .onPageEnd(() => {
          // Prefetch only when this navigation is sufficiently likely.
          this.controller.prefetchPage(
            'https://www.example.com/nextpage'
          );
        })

      Button('Next page')
        .onClick(() => {
          this.controller.loadUrl(
            'https://www.example.com/nextpage'
          );
        })
    }
  }
}
```

Guard against repeated prefetches from repeated `onPageEnd` events. Respect metered-network, privacy, authentication, and stale-content constraints.

#### Prerender using a prepared node

The slide demonstrates constructing a node ahead of time and exposing its `FrameNode` through a `NodeController`, then mounting it with `NodeContainer` when needed.

```ts
export class NWebNodeController extends NodeController {
  private rootNode: BuilderNode<Data[]> | null = null;

  // Build rootNode ahead of the moment it becomes visible.
  prepare(uiContext: UIContext, data: Data[]): void {
    this.rootNode = new BuilderNode<Data[]>(uiContext);
    this.rootNode.build(wrappedWebBuilder, data);
    this.rebuild();
  }

  makeNode(_uiContext: UIContext): FrameNode | null {
    if (this.rootNode) {
      return this.rootNode.getFrameNode();
    }
    // Returning null detaches the dynamic component from the bound node.
    return null;
  }
}

@Builder
function buildReadMeSheet(controller: NWebNodeController): void {
  Column() {
    NodeContainer(controller)
      .width('100%')
      .height('100%')
  }
  .width('100%')
  .height('100%')
}
```

Prerender only high-confidence destinations. It trades response latency for earlier CPU, network, and memory use.

### 2.2 Show a skeleton with conditional rendering

Source: `IMG_4039.PNG`

When a destination has a complex layout and data is not ready, building the entire final page can delay navigation response. Render a lightweight skeleton first, then replace it with the business layout after initialization.

```ts
@Component
struct ProductPage {
  @State private isInitialized: boolean = false;

  build() {
    if (!this.isInitialized) {
      SkeletonComponent()
    } else {
      BusinessComponent()
    }
  }
}
```

Two mechanisms are relevant:

- Conditional rendering (`if`/`else`) creates the active branch and removes the inactive branch. It saves resources when the hidden subtree is expensive and not needed.
- Visibility control uses `Visibility.Visible`, `Visibility.Hidden`, or `Visibility.None`. It can retain a subtree and its state for faster redisplay, but may keep more nodes and memory alive. `Hidden` preserves layout space; `None` does not participate in display/layout.

Choose based on the real interaction pattern. A frequently toggled tab may benefit from retained components; a rare, large destination may be better constructed conditionally.

### 2.3 Use LazyForEach for large scrolling data

Source: `IMG_4040.PNG`

For scrolling lists, prefer `LazyForEach` with component reuse and a suitable item cache over `Scroll` plus `ForEach`. `ForEach` eagerly creates an item node for every record, while `LazyForEach` creates items as they approach the visible region through an `IDataSource`.

Conceptual signatures from the slides:

```ts
ForEach(
  arr: any[],
  itemGenerator: (item: any, index?: number) => void,
  keyGenerator?: (item: any, index?: number) => string
)

LazyForEach(
  dataSource: IDataSource,
  itemGenerator: (item: any) => void,
  keyGenerator?: (item: any) => string
)
```

Example:

```ts
List() {
  LazyForEach(
    this.messages,
    (message: ChatModel) => {
      ListItem() {
        ChatView({ chatItem: message })
      }
    },
    (message: ChatModel) => message.id
  )
}
```

Keys must be stable and unique for the lifetime of an item. Index-based keys are unsafe when records can be inserted, removed, or reordered because they cause identity confusion and unnecessary rebuilds.

### 2.4 Tune cachedCount for lazy containers

Source: `IMG_4041.PNG`

Use `cachedCount` with `List`, `Swiper`, `Grid`, and `WaterFlow` to create a controlled number of off-screen items before they become visible.

```ts
List() {
  LazyForEach(
    this.chatList,
    (message: ChatModel) => {
      ListItem() {
        ChatView({ chatItem: message })
      }
    },
    (message: ChatModel) => message.user.userId
  )
}
.backgroundColor(Color.White)
.listDirection(Axis.Vertical)
.cachedCount(
  this.listCacheEnabled ? Constants.CACHED_COUNT : 0
)
```

`cachedCount` is a tradeoff:

- Too low: fast scrolling can expose item creation and cause jank.
- Too high: startup work and memory increase because more off-screen nodes are prepared.

Tune it using item complexity, viewport size, typical scroll velocity, device class, and memory measurements. Pair it with `LazyForEach` and `@Reusable`; caching alone does not eliminate construction cost.

## 3. Reuse components instead of repeatedly creating and destroying them

Sources: `IMG_4042.PNG`, `IMG_4043.PNG`, `IMG_4044.PNG`, and `IMG_4045.PNG`

### 3.1 Reuse lifecycle and cache model

The component reuse mechanism works as follows:

1. When a custom component marked `@Reusable` would be destroyed, it enters the reuse cache owned by its parent instead.
2. The cache is conceptually a `Map` of arrays keyed by `reuseId`. Components with the same `reuseId` are stored together. The default `reuseId` is the custom component name.
3. When a compatible component is required, the framework obtains one from the pool instead of constructing a new one.
4. The framework invokes `aboutToReuse` recursively on the reused custom component tree. Refresh all item-specific data there.

Without reuse, scrolling can destroy `ListItem N-2` and construct `ListItem N+4`. With reuse, `N-2` is recycled into the pool and becomes `N+4`. Cached items immediately outside the viewport are separate from the reuse pool: caching keeps nearby nodes ready, while reuse repurposes nodes that would otherwise be destroyed.

The slide's runtime diagram also emphasizes recursive refresh: a reused `ListItem` calls `aboutToReuse()` for itself and reusable descendants such as child components A, B, and C. Every nested reusable component must therefore reset all item-dependent state.

### 3.2 Implement a reusable item

```ts
@Reusable
@Component
struct GoodItem {
  @State private img: Resource = $r('app.media.photo61');
  @State private webImg: string = '';
  @State private heightValue: number = 0;
  @State private introduction: string = '';
  @State private price: string = '';
  @State private quantity: string = '';

  aboutToReuse(params: Record<string, Object>): void {
    this.webImg = params.webImg as string;
    this.img = params.img as Resource;
    this.heightValue = params.heightValue as number;
    this.introduction = params.introduction as string;
    this.price = params.price as string;
    this.quantity = params.quantity as string;
  }

  build() {
    // Build the item from the fields reset above.
  }
}
```

Reuse safety checklist:

- Reset every data-dependent field, not only the visibly changed field.
- Clear transient state such as selection, animation progress, error badges, and loading flags.
- Cancel or invalidate asynchronous work started for the previous item. Before applying a result, compare a stable item ID or request token.
- Remove item-specific listeners or subscriptions that are not automatically replaced.
- Use distinct `reuseId` values when layouts are structurally incompatible; do not reuse merely because two items share a base type.
- Keep `aboutToReuse` lightweight because it is called while scrolling or otherwise creating visible content.

### 3.3 Recommended reuse scenarios

The slides identify three high-value scenarios:

- Large scrolling lists: repeated creation/destruction of many item views causes jank. Reusing existing views improves scroll smoothness.
- Dynamic layout updates: when data or user actions frequently change layout, reuse avoids unnecessary view construction, destruction, and repeated layout computation.
- Map rendering: markers or data-item views are frequently added and removed. Reuse lets the app update content instead of rebuilding every view.

## 4. Optimize state management and precisely control refresh scope

### 4.1 Prefer references over deep copies when semantics allow

Source: `IMG_4046.PNG`

`@Prop` uses a deep copy, whereas `@Link` and `@ObjectLink` pass references. When the behavior required from `@Prop` and `@ObjectLink` is equivalent, the slide recommends `@ObjectLink` to accelerate object creation and reduce memory overhead.

| Property | `@State` + `@Prop` | `@State` + `@Link` | `@State` + `@Observed` + `@ObjectLink` |
|---|---|---|---|
| Accepted values | Object, class, string, number, boolean, enum, and arrays of those types | Object, class, string, number, boolean, enum, and arrays of those types | Instances of an `@Observed` class, or class instances extending `Date` or `Array` |
| Observes nested properties of a complex object | No | No | Yes |
| Binding direction | Parent to child | Two-way between parent and child | Two-way between parent and child |
| Parent changes propagate to child | Yes | Yes | Yes |
| Child changes propagate to parent | No | Yes | Yes for object properties; the linked variable itself cannot be replaced |
| Memory cost in the slide's comparison | High | Low | Low |
| Complex-object behavior | Deep copy | Shared address | Shared address |

Examples:

```ts
@Observed
class UserProfile {
  name: string = '';
  score: number = 0;
}

@Component
struct ProfileEditor {
  @ObjectLink profile: UserProfile;

  build() {
    Button('Increase score')
      .onClick(() => {
        // Mutate an observed property; do not replace `profile` itself here.
        this.profile.score += 1;
      })
  }
}
```

Use `@Prop` when a child intentionally needs snapshot-like, one-way data. Use `@Link` when the child must edit a primitive or replace a linked value. Use `@ObjectLink` for shared observed-object properties. Reference semantics can introduce accidental coupling, so choose based on ownership and mutation rules, not performance alone.

### 4.2 Use AttributeModifier to isolate attribute refreshes

Source: `IMG_4047.PNG`

When many visual attributes are expressed directly in a component controlled by an `@State` variable, a change to one property can cause redundant refresh work across all attributes. The calendar scenario in the slide uses `AttributeModifier` so a font-size change updates the relevant text attributes through a dedicated modifier.

Broad state-driven attribute refresh:

```ts
@State private fontSize: number = 30;

Text(this.videoDescription)
  .textAlign(TextAlign.Center)
  .fontStyle(FontStyle.Normal)
  .fontColor(Color.Pink)
  .id('videoName')
  .margin({ left: 10 })
  .fontWeight(30)
  .fontSize(this.fontSize)
```

Focused modifier:

```ts
export class MyTextModifier implements AttributeModifier<TextAttribute> {
  private fontSize: number = 30;

  setFontSize(fontSize: number): MyTextModifier {
    this.fontSize = fontSize;
    return this;
  }

  applyNormalAttribute(instance: TextAttribute): void {
    instance
      .fontSize(this.fontSize)
      .textAlign(TextAlign.Center)
      .fontStyle(FontStyle.Normal)
      .fontColor(Color.Pink)
      .id('videoName')
      .margin({ left: 10 })
      .fontWeight(30);
  }
}

@Reusable
@Component
struct CalendarCell {
  private attribute: MyTextModifier = new MyTextModifier();
  private videoDescription: string = '';

  aboutToReuse(params: Record<string, Object>): void {
    this.videoDescription = params.videoDescription as string;
    this.attribute.setFontSize(params.fontSize as number);
  }

  build() {
    Text(this.videoDescription)
      .attributeModifier(this.attribute)
  }
}
```

Use this technique where profiling shows attribute refresh overhead across many repeated elements. A modifier still needs correct invalidation and lifecycle handling; it is not a blanket substitute for state.

### 4.3 Do not pass expensive function results as reusable-component parameters

Source: `IMG_4048.PNG`

Passing a function or method result as a reusable component's input causes that function to run when the component is constructed or reused. If the function is expensive, every recycled item repeats the cost.

Avoid:

```ts
List() {
  LazyForEach(
    this.data,
    (item: string) => {
      ListItem() {
        // count() runs again whenever an item is constructed or reused.
        ChildComponent({ desc: item, sum: this.count() })
      }
      .width('100%')
      .height(100)
    },
    (item: string) => item
  )
}
```

Compute stable shared data once, then pass the value:

```ts
@State private sum: number = 0;

aboutToAppear(): void {
  this.sum = this.count();
}

build() {
  List() {
    LazyForEach(
      this.data,
      (item: string) => {
        ListItem() {
          ChildComponent({ desc: item, sum: this.sum })
        }
        .width('100%')
        .height(100)
      },
      (item: string) => item
    )
  }
}
```

If the value depends on the item, precompute it when the data model is loaded or memoize it by stable item ID. Invalidate the cache when its inputs change.

### 4.4 Use DisplaySync to distribute high-load updates across frames

Source: `IMG_4049.PNG`

In a high-load scene, `DisplaySync` can coordinate updates with frame callbacks. Instead of refreshing an entire complex component tree in one frame, process a bounded portion per frame to balance load and reduce frame loss. The slide uses a large calendar as the example.

```ts
import displaySync from '@ohos.graphics.displaySync';

@Component
struct LargeCalendar {
  private displaySync?: displaySync.DisplaySync;
  private nextCell: number = 0;

  aboutToAppear(): void {
    this.displaySync = displaySync.create();

    const range: ExpectedFrameRateRange = {
      expected: 120,
      min: 60,
      max: 120
    };

    this.displaySync.setExpectedFrameRateRange(range);
    this.displaySync.on('frame', () => {
      // Update only a measured, bounded batch in each frame.
      this.updateNextCalendarBatch();
    });
    this.displaySync.start();
  }

  aboutToDisappear(): void {
    this.displaySync?.stop();
    this.displaySync?.off('frame');
    this.displaySync = undefined;
  }

  private updateNextCalendarBatch(): void {
    // Keep this work below the available frame budget.
    // Advance nextCell and stop DisplaySync when all work is complete.
  }
}
```

Do not assume `120` is available on every device or appropriate for every screen. Set a valid range for the target display and workload, measure callback cost, and stop the listener when work is complete or the component is no longer visible.

## 5. Keep system callbacks lean and intentional

### 5.1 Avoid redundant or expensive work in high-frequency callbacks

Source: `IMG_4050.PNG`

The following callbacks can run at system or per-frame frequency and should remain extremely small:

- `onTouch`
- `onItemDragMove`
- `onDragMove`
- `onScroll`
- `onMouse`
- `onVisibleAreaChange`
- `onAreaChange`
- `onActionUpdate`
- `animator.onframe`
- `aboutToReuse` in component-reuse scenarios
- `aboutToAppear` and `aboutToDisappear` when components are frequently created and destroyed

Do not print routine logs, start/finish traces, allocate large objects, perform I/O, parse data, or execute unrelated business logic on every invocation.

Avoid:

```ts
Scroll() {
  ForEach(
    this.items,
    (item: number) => Text(`ListItem ${item}`),
    (item: number) => item.toString()
  )
}
.onScroll(() => {
  hiTraceMeter.startTrace('ScrollSlide', 1002);
  hilog.info(1002, 'Scroll', 'ListItem');
  this.doBusinessWork();
  hiTraceMeter.finishTrace('ScrollSlide', 1002);
})
```

Prefer:

```ts
.onScroll(() => {
  // Only the smallest operation needed for the current scroll event.
  this.updateVisibleScrollState();
})
```

For diagnostics, sample or throttle events, aggregate counters in memory, and emit outside the hot path. Remove verbose instrumentation from production paths after profiling.

### 5.2 Do not register callbacks that do no useful work

Source: `IMG_4051.PNG`

An empty callback is not free. For example, registering `onAreaChange` can cause the native side to compute size and position changes and bridge the result back to ArkTS even when the callback body is empty.

Avoid:

```ts
Button('Click', {
  type: ButtonType.Normal,
  stateEffect: true
})
  .onClick(() => {
    hiTraceMeter.startTrace('ButtonClick', 1004);
    hilog.info(1004, 'Click', 'ButtonType.Normal');
    hiTraceMeter.finishTrace('ButtonClick', 1004);
    this.runAction();
  })
  .onAreaChange((_oldValue: Area, _newValue: Area) => {
    // Empty, but the framework still pays to observe and deliver changes.
  })
```

Prefer registering only the listener required by the feature:

```ts
Button('Click', {
  type: ButtonType.Normal,
  stateEffect: true
})
  .onClick(() => {
    this.runAction();
  })
```

Audit placeholders, obsolete analytics hooks, and callbacks whose feature flag is permanently off. Remove the listener itself instead of leaving an empty body.

## 6. Defer uncommon modules with dynamic imports

Source: `IMG_4052.PNG`

A home page may navigate to several complex modules, only some of which are commonly used. Static imports load dependencies before they are needed and can increase startup work.

Eager form:

```ts
import { pageOne, pageOneData } from './pageOne';
import { pageTwo, pageTwoData } from './pageTwo';
import { pageThree, pageThreeData } from './pageThree';
import { pageFour, pageFourData } from './pageFour';
import router from '@ohos.router';
```

Lazy form:

```ts
private pageOneLoader: Object | undefined;
private pageOneLoadPromise?: Promise<void>;

async loadPageOne(key: string): Promise<void> {
  if (key !== 'pageOne' || this.pageOneLoader) {
    return;
  }

  // Deduplicate concurrent requests for the same module.
  if (!this.pageOneLoadPromise) {
    this.pageOneLoadPromise = import('../pages/PageLoader')
      .then(({ PageOneLoader }) => {
        this.pageOneLoader = PageOneLoader;
      })
      .finally(() => {
        this.pageOneLoadPromise = undefined;
      });
  }

  await this.pageOneLoadPromise;
}
```

Use `await import(...)` for modules that are not required for the first frame. Keep first-screen essentials static to avoid turning startup savings into a visible delay. Consider preloading a lazy module after the first frame or when user intent becomes likely, such as on tab focus or pointer-down. Handle import failure and loading UI explicitly.

## 7. Use component transitions for appearance and disappearance animations

Source: `IMG_4053.PNG`

For animations tied to a component entering or leaving the UI tree, prefer a component `transition` over manually combining a property animation with completion logic. The transition integrates with component lifecycle, is easier to interrupt correctly, and reduces redundant rendering-process work.

Avoid manually coordinating opacity, counters, and delayed removal:

```ts
Text('toggle state')
  .onClick(() => {
    this.count += 1;
    const requestCount: number = this.count;
    this.show = true;

    animateTo(
      {
        duration: 1000,
        onFinish: () => {
          if (requestCount === this.count && this.opacity === 0) {
            this.show = false;
          }
        }
      },
      () => {
        this.opacity = this.opacity === 1 ? 0 : 1;
      }
    );
  })
```

Prefer a transition attached to the conditional component:

```ts
@State private show: boolean = true;

build() {
  Column() {
    Row() {
      if (this.show) {
        Text('value')
          .id('myText')
          .transition(
            TransitionEffect.OPACITY.animation({ duration: 1000 })
          )
      }
    }
    .width('100%')
    .height(100)
    .justifyContent(FlexAlign.Center)

    Text('toggle state')
      .onClick(() => {
        this.show = !this.show;
      })
  }
}
```

Use a stable ID when the transition requires stable component identity. Test rapid repeated toggles, navigation during animation, reduced-motion/accessibility behavior, and component destruction.

## 8. Repository audit playbook

An engineer or agent can use the following searches as an initial map. The matches are review candidates, not automatic defects.

```sh
# Eager list construction and missing virtualization/reuse
rg -n "Scroll\(|ForEach\(|LazyForEach\(|cachedCount|@Reusable|aboutToReuse" .

# Main-thread or lifecycle startup work
rg -n "aboutToAppear|onPageShow|initializeWebEngine|JSON\.parse|decode|decompress" .

# High-frequency and potentially redundant callbacks
rg -n "onTouch|onItemDragMove|onDragMove|onScroll|onMouse|onVisibleAreaChange|onAreaChange|onActionUpdate|onframe" .

# Logging/tracing in hot paths
rg -n "hilog\.|logger\.|startTrace|finishTrace" .

# State-transfer and broad-refresh candidates
rg -n "@Prop|@Link|@ObjectLink|@Observed|@State|AttributeModifier" .

# Eager feature modules and manual enter/exit animation logic
rg -n "^import .*page|^import .*feature|animateTo|\.transition\(" .

# Web acceleration candidates
rg -n "Web\(|WebviewController|loadUrl|prefetchPage|prepareForPageLoad|NodeContainer" .
```

For each candidate, document:

- the user journey and device class affected;
- whether the code is in the first-frame or interaction-critical path;
- the current timing, frame-loss, CPU, and memory evidence;
- the chosen optimization and why its tradeoff is acceptable;
- lifecycle cleanup and stale-result protection; and
- before/after measurements using the same build and scenario.

### Suggested implementation order

1. Remove expensive work and verbose diagnostics from high-frequency callbacks.
2. Remove unused listeners.
3. Move genuinely expensive non-UI work to TaskPool or Worker.
4. Defer nonessential startup work and uncommon static imports.
5. Virtualize large lists with `LazyForEach`, stable keys, and measured `cachedCount`.
6. Add `@Reusable` and make `aboutToReuse` complete and cheap.
7. Reduce broad state refreshes with correct link semantics and targeted modifiers.
8. Add Web preconnect/prefetch/prerender only for likely destinations.
9. Split heavy per-frame updates with `DisplaySync` where profiling justifies it.
10. Replace manual appearance/disappearance animation bookkeeping with transitions.

## 9. Rules suitable for selective AGENTS.md integration

When an agent uses this guide inside a real application repository, it should inspect the target SDK, architecture, and profiling evidence, then add only applicable rules to the existing `AGENTS.md`. Preserve existing project instructions and avoid generic mandates that are not true for the repository.

Example repository-specific section:

```md
## ArkTS performance rules

- Keep first-frame lifecycle methods free of nonessential synchronous work.
- Run measured CPU-heavy, UI-independent tasks in TaskPool or the project's existing Worker abstraction; never mutate ArkUI state from a worker.
- Use LazyForEach with stable domain IDs for large scrolling collections. Tune cachedCount from device measurements.
- Reusable list items must reset all item-specific state and invalidate stale asynchronous results in aboutToReuse.
- Do not add logs, traces, allocations, I/O, or heavy calculations to per-frame callbacks.
- Do not register empty onAreaChange or similar system listeners.
- Keep first-screen modules static; load uncommon feature modules with the repository's dynamic-import helper.
- Use component transitions for conditional enter/exit animations.
- Include before/after startup, frame, CPU, and memory evidence in performance-related changes.
```

An agent should not rewrite `@Prop` to `@ObjectLink`, add background concurrency, increase `cachedCount`, or introduce preloading without confirming data ownership, thread/API compatibility, memory budget, and measured benefit.

## 10. Consolidated review checklist

### Startup and first frame

- [ ] No nonessential expensive work blocks the UI thread before the first frame.
- [ ] Independent expensive startup work is scheduled with an appropriate concurrency mechanism.
- [ ] Deferred work is prioritized and does not produce a second post-startup stall.
- [ ] Uncommon feature modules are dynamically loaded.
- [ ] Web engine preparation and likely-origin preconnection are used only where beneficial.

### Interaction and rendering

- [ ] Complex destinations show a lightweight skeleton or retained preview while loading.
- [ ] Large scrolling collections use `LazyForEach` with stable unique keys.
- [ ] `cachedCount` is tuned rather than maximized.
- [ ] Repeated complex items use `@Reusable` and fully reset in `aboutToReuse`.
- [ ] Expensive reusable inputs are precomputed or memoized.
- [ ] High-load updates are bounded per frame; `DisplaySync` listeners are stopped correctly.
- [ ] Conditional appearance/disappearance uses component transitions where appropriate.

### State and data transfer

- [ ] `@Prop`, `@Link`, and `@ObjectLink` match intended ownership and mutation semantics.
- [ ] Large cross-concurrency payloads use valid Sendable structures where reference transfer is safe.
- [ ] Attribute-only changes do not trigger unnecessarily broad component refreshes.
- [ ] Background and recycled-item results cannot update stale UI state.

### Callback hygiene

- [ ] Per-frame and gesture callbacks contain only bounded, necessary work.
- [ ] Routine logging and tracing are absent from hot paths.
- [ ] Empty or obsolete system listeners are removed, not left with empty bodies.
- [ ] Timers, listeners, DisplaySync callbacks, workers, and asynchronous requests are cleaned up or invalidated with component lifecycle.

## 11. Source coverage index

| Slide | Knowledge captured |
|---|---|
| `IMG_4034.PNG` | TaskPool parallelism for startup/tab network loading and parsing |
| `IMG_4035.PNG` | TaskPool/Worker use for heavy work, UI-thread load, and frame-loss comparison |
| `IMG_4036.PNG` | Asynchronous execution and delaying unavoidable main-thread initialization |
| `IMG_4037.PNG` | Sendable reference transfer between concurrent instances |
| `IMG_4038.PNG` | Web engine initialization, DNS/preconnect, prefetch, and prerendering |
| `IMG_4039.PNG` | Skeleton screens, conditional rendering, and visibility control |
| `IMG_4040.PNG` | `LazyForEach`, component reuse, item caching, and list performance |
| `IMG_4041.PNG` | `cachedCount` for `List`, `Swiper`, `Grid`, and `WaterFlow` |
| `IMG_4042.PNG` | Component reuse principles and behavior without reuse |
| `IMG_4043.PNG` | Reuse pool behavior with `@Reusable` |
| `IMG_4044.PNG` | Runtime reuse pool structure and recursive `aboutToReuse` callbacks |
| `IMG_4045.PNG` | Reusable component code and recommended list/layout/map scenarios |
| `IMG_4046.PNG` | `@Prop` vs `@Link` vs `@Observed`/`@ObjectLink` |
| `IMG_4047.PNG` | `AttributeModifier` for precise attribute refresh |
| `IMG_4048.PNG` | Avoiding expensive function/method results as reusable inputs |
| `IMG_4049.PNG` | `DisplaySync` and per-frame work distribution |
| `IMG_4050.PNG` | Avoiding logs, traces, and heavy work in high-frequency callbacks |
| `IMG_4051.PNG` | Removing redundant system callback listeners |
| `IMG_4052.PNG` | Dynamic imports for deferred feature-module loading |
| `IMG_4053.PNG` | Component `transition` instead of manual `animateTo` bookkeeping |

---

Performance work is complete only when behavior remains correct and measurements improve. Prefer evidence-backed, repository-specific rules over broad rewrites.
