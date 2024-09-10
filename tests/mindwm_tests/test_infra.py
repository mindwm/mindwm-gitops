import pytest
import subprocess


@pytest.mark.e2e
class TestClass:
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

    def test_cluster(self):
        self.run_cmd("make cluster")
       

    @pytest.mark.depends(on=['test_cluster'])
    def test_argocd_app(self):
        self.run_cmd("make argocd_app")

    @pytest.mark.depends(on=['test_argocd_app'])
    def test_argocd_app_sync_async(self):
        self.run_cmd("make argocd_app_sync_async")


    @pytest.mark.depends(on=['test_argocd_app_sync_async'])
    def test_argocd_app_async_wait(self):
        self.run_cmd("make argocd_app_async_wait")

    @pytest.mark.depends(on=['test_argocd_app_async_wait'])
    def test_crossplane_rolebinding_workaround(self):
        self.run_cmd("make crossplane_rolebinding_workaround")

    @pytest.mark.depends(on=['test_crossplane_rolebinding_workaround'])
    def test_argocd_apps_ensure(self):
        self.run_cmd("make argocd_apps_ensure")
