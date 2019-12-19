# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.

from jupyter_core.paths import jupyter_data_dir
import subprocess
import os
import shutil
import errno
import stat
import textwrap
import getpass
import tempfile

c = get_config()
c.NotebookApp.ip = "0.0.0.0"
c.NotebookApp.port = 8888
c.NotebookApp.open_browser = False
c.NotebookApp.allow_origin = "*"

# https://github.com/jupyter/notebook/issues/3130
c.FileContentsManager.delete_to_trash = False

def _codeserver_command(port):
    full_path = shutil.which("code-server")
    if not full_path:
        raise FileNotFoundError("Can not find code-server in $PATH")
    # lstrip is used as a hack to deal with using paths in environments
    # when using git-bash on windows
    working_dir = os.getenv("CODE_WORKINGDIR", None).lstrip()
    if working_dir is None:
        working_dir = os.getenv("JUPYTER_SERVER_ROOT", ".")
    elif os.path.isdir(working_dir) is False:
        os.mkdir(working_dir)
    data_dir = os.getenv("CODE_USER_DATA_DIR", "")
    if data_dir != "":
        data_dir = "--user-data-dir=" + str(data_dir)
    extensions_dir = os.getenv("CODE_EXTENSIONS_DIR", "")
    if extensions_dir != "":
        extensions_dir = "--extensions-dir=" + str(extensions_dir)
    builtin_extensions_dir = os.getenv("CODE_BUILTIN_EXTENSIONS_DIR", "")
    if builtin_extensions_dir != "":
        builtin_extensions_dir = "--builtin-extensions-dir=" + str(
            builtin_extensions_dir
        )

    return [
        full_path,
        "--port=" + str(port),
        "--allow-http",
        "--no-auth",
        "--vanilla",
        data_dir,
        extensions_dir,
        builtin_extensions_dir,
        working_dir,
    ]

c.ServerProxy.servers = {
    "vscode": {
        "command": _codeserver_command,
        "timeout": 20,
        "launcher_entry": {
            "title": "VS Code",
            "icon_path": "/opt/code-server/vscode.svg",
        },
    },
    "voila": {
        "command": ['voila', '--port', '{port}', '--server_url', '/', '--base_url', '{base_url}voila/'],
#        "command": ['voila', '--port', '{port}', '--server_url', '/', '--base_url', '{base_url}voila/', 
#                    '--template', 'gridstack', """--VoilaConfiguration.resources='{"gridstack": {"show_handles": True}}'"""],
        "launcher_entry": {
            "title": "Voilà",
#            "icon_path": "/path/to/voila_icon.svg",
        },
    },
}

# Generate a self-signed certificate
if "GEN_CERT" in os.environ:
    dir_name = jupyter_data_dir()
    pem_file = os.path.join(dir_name, "notebook.pem")
    try:
        os.makedirs(dir_name)
    except OSError as exc:  # Python >2.5
        if exc.errno == errno.EEXIST and os.path.isdir(dir_name):
            pass
        else:
            raise
    # Generate a certificate if one doesn't exist on disk
    subprocess.check_call(
        [
            "openssl",
            "req",
            "-new",
            "-newkey",
            "rsa:2048",
            "-days",
            "365",
            "-nodes",
            "-x509",
            "-subj",
            "/C=XX/ST=XX/L=XX/O=generated/CN=generated",
            "-keyout",
            pem_file,
            "-out",
            pem_file,
        ]
    )
    # Restrict access to the file
    os.chmod(pem_file, stat.S_IRUSR | stat.S_IWUSR)
    c.NotebookApp.certfile = pem_file
