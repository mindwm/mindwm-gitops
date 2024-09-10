import pytest
import subprocess
import allure


@pytest.mark.e2e
@allure.title("Test mindwm infra")
class TestInfra:
    def run_cmd(self, cmd):
        try:
            result = subprocess.run(["sh", "-c", cmd], check=True, text=True, capture_output=True, cwd="../../")
            print("Command Output:", result.stdout)
            assert result.returncode == 0, f"Expected return code 0 but got {result.returncode}"
        except subprocess.CalledProcessError as e:
            # If the command fails, capture the error and output
            print(f"Error executing '{cmd}': {e}")
            print(f"Error Output: {e.stderr}")
            pytest.fail(f"Make cluster command failed with return code {e.returncode}")

    @allure.story('Deploy k8s cluster')
    def test_cluster(self):
        self.run_cmd("make cluster")
       

    @allure.story('Create argocd mindwm application')
    @pytest.mark.depends(on=['test_cluster'])
    def test_argocd_app(self):
        self.run_cmd("make argocd_app")

    @allure.story('Argocd mindwm application sync')
    @pytest.mark.depends(on=['test_argocd_app'])
    def test_argocd_app_sync_async(self):
        self.run_cmd("make argocd_app_sync_async")


    @allure.story('Waiting for argocd mindwm application is ready')
    @pytest.mark.depends(on=['test_argocd_app_sync_async'])
    def test_argocd_app_async_wait(self):
        self.run_cmd("make argocd_app_async_wait")

    @allure.story('Crossplane rolebinding workaround')
    @pytest.mark.depends(on=['test_argocd_app_async_wait'])
    def test_crossplane_rolebinding_workaround(self):
        self.run_cmd("make crossplane_rolebinding_workaround")

    @allure.story('Verify that everthing is green in argocd')
    @pytest.mark.depends(on=['test_crossplane_rolebinding_workaround'])
    def test_argocd_apps_ensure(self):
        self.run_cmd("make argocd_apps_ensure")

    @allure.story('Create mindwm resources, context, user, host')
    @pytest.mark.depends(on=['test_argocd_apps_ensure'])
    def test_mindwm_resoures(self):
        self.run_cmd("make mindwm_resources")
