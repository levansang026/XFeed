# XFeed design

iOS 17+, iPhone, portrait, light and dark. SwiftUI, Kingfisher (SPM), Swift Testing. Bundle id `com.billle.XFeed`. One app target; layers are folders and dependencies point inward: Presentation -> Domain <- Data.

## Domain
- Entities: `Post` (id, author, text, imageURL?, createdAt, likeCount, isLikedByMe), `Author`, `FeedPage` (posts, nextCursor?), `NetworkError`.
- `PostRepository` protocol: `feed(cursor:limit:)`, `createPost(text:imageURL:)`, `setLike(postID:liked:)`.
- `MockControlling` protocol: failure rate, latency range, force next failure, reset seed data.
- Use cases: `LoadFeed`, `CreatePost` (trims text, requires 1-280 characters, regex-validates the optional image URL), `SetLike`.

## Data
- `MockPostRepository` (actor): in-memory store loaded from bundled `seed_posts.json` (50 posts, ~12 authors, ~60% with picsum images, edge cases). Opaque cursor over a stable ordering key. Latency and failure injected via `MockConfig` and an injectable RNG. Resets on every launch. Also implements `MockControlling`.
- DTOs and mappers to the Domain entities. A future `RemotePostRepository` is a drop-in replacement chosen in the composition root.

## Presentation
- `FeedViewModel` (`@Observable @MainActor`): owns the list including Pending Posts, pagination (load more when any of the last 3 rows appears), refresh (cancels in-flight load-more, merges so in-flight likes keep local state), de-duplication by id, per-Post like debounce and rollback.
- `ComposerViewModel`, `DevPanelViewModel` separate. Dev panel opens with three taps on the top-left avatar, in all builds.
- Views take value-type row models and closures. Relative time is X style ("now", "5m", "3h", "2d", "Oct 4"), computed in Presentation. Images via Kingfisher `KFImage`.

## Tests (Swift Testing)
View models (fake repository with controllable continuations, no sleeps), use cases, and the mock repository with a seeded RNG (paging all 50 seeds, failure and latency behavior).
