Mimic.copy(Ash)
Mimic.copy(Cinder.Filters.Text)

{:ok, _} = Cinder.TestEndpoint.start_link()
Cinder.TestLive.Fixture.setup_registry!()

ExUnit.start()
