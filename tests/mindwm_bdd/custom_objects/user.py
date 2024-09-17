from kubetest.objects.custom_objects import CustomObject
from kubernetes import client, config
import pprint
from kubetest import utils, condition
import time


api_group = "mindwm.io"
api_version = "v1beta1"

class MindwmUser(CustomObject):
    namespace = "default"


    def is_ready(self): 
        for condition in self.status().get('conditions'):
            if condition.get('type') == 'Ready':
                ready_condition = condition
            if condition.get('type') == 'Synced':
                synced_condition = condition

        is_ready = ready_condition and ready_condition.get('status') == 'True'
        is_synced = synced_condition and synced_condition.get('status') == 'True'
        
        return not is_ready and not is_synced

    def status(self):
        r = self.api_client.get_namespaced_custom_object_status(group = api_group, version = api_version, namespace = self.namespace, plural = "users", name = self.name)
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

    def wait_for_ready(self):
        self.wait_for_status()

        ready_condition = condition.Condition(
            "api object is ready",
            self.is_ready,
        )
        utils.wait_for_condition(
            condition=ready_condition,
            timeout=10,
            interval=1,
        )
    def validate(self):
        try:
            self.wait_for_ready()
        except TimeoutError as e:
            pass

        status = self.status()
        for condition in status.get('conditions'):
            if condition.get('type') == 'Ready':
                ready_condition = condition
            if condition.get('type') == 'Synced':
                synced_condition = condition

        is_ready = ready_condition and ready_condition.get('status') == 'True'
        is_synced = synced_condition and synced_condition.get('status') == 'True'
        assert(is_synced), f"User {self.name} is not synced"
        assert(is_ready), f"User {self.name} is not ready"