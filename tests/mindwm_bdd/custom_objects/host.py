from kubetest.objects.custom_objects import CustomObject
from kubernetes import client, config
from typing import Optional, Union
import pprint
from kubernetes.client.rest import ApiException
from kubernetes import client
from kubetest import utils, condition
import time
import logging

log = logging.getLogger("kubetest")


api_group = "mindwm.io"
api_version = "v1beta1"

class MindwmHost(CustomObject):
    namespace = "default"

    def delete(self, options: client.V1DeleteOptions) -> client.V1Status:
        return self.api_client.delete_namespaced_custom_object(api_group, api_version, self.namespace, "hosts", self.name)

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
        r = self.api_client.get_namespaced_custom_object_status(group = api_group, version = api_version, namespace = self.namespace, plural = "hosts", name = self.name)
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
        assert(is_synced), f"Host {self.name} is not synced"
        assert(is_ready), f"Host {self.name} is not ready"

    def wait_until_deleted(
            self, timeout: int = None, interval: Union[int, float] = 1
        ) -> None:
            def deleted_fn():
                try:
                    self.status()
                except ApiException as e:
                    # If we can no longer find the deployment, it is deleted.
                    # If we get any other exception, raise it.
                    if e.status == 404 and e.reason == "Not Found":
                        return True
                    else:
                        raise e
                else:
                    # The object was still found, so it has not been deleted
                    return False

            delete_condition = condition.Condition("api object deleted", deleted_fn)

            utils.wait_for_condition(
                condition=delete_condition,
                timeout=timeout,
                interval=interval,
            )
