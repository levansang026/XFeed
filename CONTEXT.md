# XFeed

A clone of the X (Twitter) home feed: one global, infinitely scrolling list of posts that anyone can like and that the current user can add to.

## Language

**Post**:
A short piece of text, optionally with one image, written by an Author and shown in the Feed.
_Avoid_: Tweet, status, message

**Feed**:
The single, newest-first, paginated list of all Posts. There is no follow graph and no per-user timeline.
_Avoid_: Timeline, stream, home

**Author**:
The user who wrote a Post, shown with a name, handle and avatar.
_Avoid_: User, poster, creator

**Me**:
The one fixed Author who is the current user. Authentication is out of scope.
_Avoid_: Current user, logged-in user, account

**Like**:
Me's endorsement of a Post. A Post exposes how many Likes it has and whether Me has liked it.
_Avoid_: Favorite, heart, upvote
