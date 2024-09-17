import pytest
#import asyncio
#import pytest_asyncio
#import nats
from nats.errors import ConnectionClosedError, TimeoutError, NoServersError
from mindwm import test_namespace

nats_namespace = "nats"
nats_statefulset = "nats"
nats_deployment = "nats-box"

#@pytest.mark.asyncio(loop_scope="class")
@pytest.mark.dependency(name = "nats", scope = 'session')
class Test_Nats(test_namespace):
#    loop: asyncio.AbstractEventLoop
    namespace = "nats"
    deployment = [ "nats-box" ]
    statefulset = [ "nats" ]
    service = [
        "nats",
        "nats-headless",
    ]
#    @pytest.mark.depends(on=['Test_Nats::test_deployment'])
#    @pytest.mark.asyncio
#    async def test_nats_pub_sub(self, kube):
#        async def message_handler(msg):
#            print("XXX")
#        assert True
#        nc = await nats.connect("nats://demo.nats.io:4222")
#        #nc = await nats.connect("nats://176.124.198.10:4222")
#        sub = await nc.subscribe("foo", cb=message_handler) 
#        await sub.unsubscribe(limit=1)
#        await nc.publish("foo", b'Hello')
#        print("XXX")
#        #sub = await nc.subscribe("foo", cb=message_handler)
#        #await sub.unsubscribe(limit=1)
#        #await nc.publish("foo", b'Hello')
#        #await nc.publish("foo", b'Hello')
#        #await nc.publish("foo", b'Hello')

