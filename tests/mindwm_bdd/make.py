import subprocess

def run_make_cmd(cmd, cwd):
    try:
        result = subprocess.run(["sh", "-c", cmd], check=True, text=True, capture_output=True, cwd=cwd)
        #print("Command Output:", result.stdout)
        assert result.returncode == 0, f"Expected return code 0 but got {result.returncode}"
    except subprocess.CalledProcessError as e:
        print(f"Error executing '{cmd}': {e}")
        print(f"Output: {e.stdout}")
        print(f"Error Output: {e.stderr}")
