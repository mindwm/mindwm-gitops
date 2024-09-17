from kubetest.objects.custom_objects import CustomObject
from kubernetes import client, config
import pprint
from kubetest import utils, condition
import time


from kubernetes.client.rest import ApiException
from kubernetes import client
from typing import Optional, Union

api_group = "mindwm.io"
api_version = "v1beta1"

class MindwmContext(CustomObject):
    namespace = "default"

    def delete(self, options: client.V1DeleteOptions) -> client.V1Status:
        return self.api_client.delete_namespaced_custom_object(api_group, api_version, self.namespace, "contexts", self.name)

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

    def wait_until_deleted(
            self, timeout: int = None, interval: Union[int, float] = 1
        ) -> None:
            def deleted_fn():
                try:
                    self.status()
                except ApiException as e:
                    if e.status == 404 and e.reason == "Not Found":
                        return True
                    else:
                        raise e
                else:
                    return False

            delete_condition = condition.Condition("api object deleted", deleted_fn)

            utils.wait_for_condition(
                condition=delete_condition,
                timeout=timeout,
                interval=interval,
            )
