Mimic.copy(Ash)

{:ok, _} = Cinder.TestEndpoint.start_link()
Cinder.TestLive.Fixture.setup_registry!()

ExUnit.start()
