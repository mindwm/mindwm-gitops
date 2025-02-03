from git_utils import git_clone
from utils import run_cmd
from tmux import create_tmux_session
from tmux import send_command_to_pane
from tmux import vertically_split_window
from tmux import capture_pane
import time

work_dir="/tmp/mindwm-manager"
tmux_session_name = "integration-test1"
window_name = "integration-test"

mindwm_manager_env = {
        "HOST": "$(hostname -s)",
        "NATS_URL": "nats://root:r00tpass@nats.mindwm.local:4222",
        "MINDWM_EVENT_SUBJECT_PREFIX": "org.mindwm.${USER}.${HOST}",
        "MINDWM_FEEDBACK_SUBJECT": "user-${USER}.${HOST}-broker-kne-trigger._knative",
        "MINDWM_SURREALDB_URL": "ws://127.0.0.1:8000/mindwm/context_graph",
        "MINDWM_SURREALDB_ENABLED": "False"
} 
hostname = "$(hostname -s)"

#git_clone(work_dir, "https://github.com/mindwm/mindwm-manager", "master", "HEAD")
# #
run_cmd("python3.11 -m venv .venv", work_dir)
#run_cmd(f"{work_dir}/.venv/bin/pip install -r requirements.txt", work_dir)
# exit(0)
create_tmux_session(tmux_session_name, window_name, work_dir)
capture_pane("/tmp/xxx", tmux_session_name, window_name, 0)
send_command_to_pane(tmux_session_name, window_name, 0, ". .venv/bin/activate")
for env_var in mindwm_manager_env.keys():
    send_command_to_pane(tmux_session_name, window_name, 0, f"export {env_var}={mindwm_manager_env[env_var]}")

send_command_to_pane(tmux_session_name, window_name, 0, "python3.11 src/manager.py")

vertically_split_window(tmux_session_name, window_name)

send_command_to_pane(tmux_session_name, window_name, 1, f"sleep 5; cd {work_dir}; bash ./join.sh")
time.sleep(10)
send_command_to_pane(tmux_session_name, window_name, 1, f"id")
