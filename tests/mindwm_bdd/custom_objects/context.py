from kubetest.objects.custom_objects import CustomObject
from kubernetes import client, config
import pprint
from kubetest import utils, condition
import time


api_group = "mindwm.io"
api_version = "v1beta1"

class MindwmContext(CustomObject):
    namespace = "default"

    def status(self):
        r = self.api_client.get_namespaced_custom_object_status(group = api_group, version = api_version, namespace = self.namespace, plural = "contexts", name = self.name)
        return r.get('status')

    def _has_status(self):
        try:
            status = self.status()
            assert not status is None
            return True
        except:
            return False
            

    def wait_for_status(self):
        ready_condition = condition.Condition(
            "api object has status",
            self._has_status,
        )
        utils.wait_for_condition(
            condition=ready_condition,
            timeout=60,
            interval=1,
        )
