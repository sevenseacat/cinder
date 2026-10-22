Mimic.copy(Ash)
Mimic.copy(Cinder.Filters.Text)

{:ok, _} = Cinder.TestEndpoint.start_link()
Cinder.TestLive.Fixture.setup_registry!()
Cinder.TestLive.NextFixture.setup_registry!()

# `payload` measurements are slow and only printed: mix test --only payload
ExUnit.start(exclude: [:payload])
