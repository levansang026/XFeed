# Created posts appear in the Feed immediately as Pending Posts

A new Post is inserted at the top of the Feed right away, blurred with a spinner while sending, and shows Retry/Discard if it fails. We rejected "insert only after server confirmation" because a failure would then leave the user with no trace of what they wrote outside the Composer. The cost is a second, local-only kind of Post (identified by a client id until the server id replaces it), and the Feed's order uses the server timestamp once confirmed, so a retried post lands at the top at the moment it succeeds.
