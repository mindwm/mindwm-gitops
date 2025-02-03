import libtmux
import pprint

def create_tmux_session(session_name, window_name, dir=None):
    try:
        server = libtmux.Server()
        if dir is None:
            dir = os.getcwd()

        if server.has_session(session_name):
            print(f"Session '{session_name}' already exists.")
            return server.find_where({"session_name": session_name})

        print(f"Creating new tmux session: '{session_name}' in directory: '{dir}'")
        session = server.new_session(session_name=session_name, start_directory=dir, attach=False, kill_session=True, window_name=window_name)

        default_window = session.attached_window
        #default_window.set_option("automatic-rename", "off")


        print(f"Successfully created tmux session: '{session_name}' in directory: '{dir}'")
        return session
    except Exception as e:
        print(f"An error occurred: {e}")
        return None

def tmux_session_exists(session_name):
    try:
        server = libtmux.Server()
        return server.has_session(session_name)
    except Exception as e:
        print(f"An error occurred: {e}")
        return None

def capture_pane(capture_file : str, session_name : str, window_name : str, pane_index : int):
    print(f"capture {session_name}:{window_name}:{pane_index} to {capture_file}")
    assert capture_file is not None
    try:
        server = libtmux.Server()
        session = server.find_where({"session_name": session_name})
    except Exception as e:
        print(f"An error occurred: {e}")
        raise e

    if not session:
        print(f"Session '{session_name}' does not exist.")
        return False

    try:
        window = session.find_where({"window_name": window_name})
    except Exception as e:
        print(f"An error occurred: {e}")
        raise e

    if not window:
        print(f"Window '{window_name}' does not exist in session '{session_name}'.")
        return False

    try:
        panes = window.panes
        if pane_index >= len(panes):
            print(f"Pane index '{pane_index}' is out of range for window '{window_name}'.")
            return False

        pane = panes[pane_index]
        pane.cmd("pipe-pane", f"cat > {capture_file}")

    except Exception as e:
        print(f"An error occurred: {e}")
        raise e

    return True



def send_command_to_pane(session_name, window_name, pane_index, command):
    try:
        server = libtmux.Server()
        session = server.find_where({"session_name": session_name})

        if not session:
            print(f"Session '{session_name}' does not exist.")
            return False

        #windows = session._list_windows()
        #window = session.find_where({})
        #pprint.pprint(windows)
        window = session.find_where({"window_name": window_name})
        if not window:
            print(f"Window '{window_name}' does not exist in session '{session_name}'.")
            return False

        panes = window.panes
        if pane_index >= len(panes):
            print(f"Pane index '{pane_index}' is out of range for window '{window_name}'.")
            return False

        pane = panes[pane_index]
        pane.send_keys(command)
        print(f"Command '{command}' sent to pane {pane_index} in window '{window_name}' of session '{session_name}'.")
        return True
    except Exception as e:
        print(f"An error occurred: {e}")
        return False


def vertically_split_window(session_name, window_name):
    try:
        server = libtmux.Server()
        session = server.find_where({"session_name": session_name})

        if not session:
            print(f"Session '{session_name}' does not exist.")
            return False

        window = session.find_where({"window_name": window_name})
        if not window:
            print(f"Window '{window_name}' does not exist in session '{session_name}'.")
            return False

        # Vertically split the window
        window.split_window(attach=False, vertical=True)
        print(f"Successfully vertically split window '{window_name}' in session '{session_name}'.")
        return True
    except Exception as e:
        print(f"An error occurred: {e}")
        return False
