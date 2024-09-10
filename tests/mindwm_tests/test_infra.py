import pytest
import subprocess
import allure


@pytest.mark.gitops
@allure.title("Test mindwm infra")
class TestInfra(object):
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
    @pytest.mark.dependency(name = "cluster")
    def test_cluster(self):
        self.run_cmd("make cluster")
       

    @allure.story('Create argocd mindwm application')
    @pytest.mark.dependency(name = 'argocd_app', depends=['cluster'], scope = "session")
    def test_argocd_app(self):
        self.run_cmd("make argocd_app")

    @allure.story('Argocd mindwm application sync')
    @pytest.mark.dependency( name = 'argocd_app_sync_async', depends=['argocd_app'], scope = "session")
    def test_argocd_app_sync_async(self):
        self.run_cmd("make argocd_app_sync_async")


    @allure.story('Waiting for argocd mindwm application is ready')
    @pytest.mark.dependency( name = 'argocd_app_async_wait', depends=['argocd_app_sync_async'], scope = "session")
    def test_argocd_app_async_wait(self):
        self.run_cmd("make argocd_app_async_wait")

    @allure.story('Crossplane rolebinding workaround')
    @pytest.mark.dependency( name = 'crossplane_rolebinding_workaround', depends=['argocd_app_async_wait'], scope = "session")
    def test_crossplane_rolebinding_workaround(self):
        self.run_cmd("make crossplane_rolebinding_workaround")

    @allure.story('Verify that everthing is green in argocd')
    @pytest.mark.dependency( name = 'argocd_apps_ensure', depends=['crossplane_rolebinding_workaround'], scope = "session")
    def test_argocd_apps_ensure(self):
        self.run_cmd("make argocd_apps_ensure")

    @allure.story('Create mindwm resources, context, user, host')
    @pytest.mark.dependency( name = 'mindwm_resoures', depends=['argocd_apps_ensure'], scope = "session")
    def test_mindwm_resoures(self):
        self.run_cmd("make mindwm_resources")

