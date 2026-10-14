# Like is an idempotent `setLike(postID, liked)`, rolled back to last confirmed state

The backend contract sets the desired liked state rather than toggling it, so retries and rapid taps cannot drift the count. The client applies the new state optimistically and, on failure, restores the last state the server confirmed, not "the opposite of what was just tapped". A toggle endpoint was rejected because a lost response or a double tap would leave client and server disagreeing.
