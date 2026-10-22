# Cinder dev app

A Phoenix app for exercising Cinder by hand. It depends on the library in the parent directory, so edits to `../lib` recompile and live-reload the page with no restart.

```
cd dev
mix setup
iex -S mix phx.server
```

Then visit [localhost:4000](http://localhost:4000).

Data lives in ETS and is seeded at boot (`CinderDev.Seeds`), so it resets on every restart. The resources (`Music.Artist`, `Music.Album`) are shared with Cinder's own integration tests, in `../test/support/music/`.
