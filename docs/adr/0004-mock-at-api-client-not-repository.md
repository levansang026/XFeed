# The mock backend implements `FeedAPIClient`, not `FeedRepository`

`FeedRepositoryImpl` is the only repository and talks to a `FeedAPIClient` protocol; `MockFeedAPIClient` is one implementation and a URLSession client will be another. We rejected a mock repository because DTO decoding, mapping and error translation would then run only against the real backend, untested until the switch.
