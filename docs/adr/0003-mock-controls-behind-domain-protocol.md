# Mock backend is configured through a Domain protocol, opened by tapping the avatar three times

The dev panel (failure rate, latency, force-next-failure, reset seed data) talks to a `MockControlling` protocol declared in Domain and implemented only by the mock in Data, so Presentation never imports a mock type. With a real backend, no implementation is registered and the panel is hidden, which keeps the swap to a real backend a change in the composition root only.
