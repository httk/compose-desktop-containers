This container sets up a fairly bare-bones console container.

You can launch software installed in the container by:
  ./exec.sh <program>
Or open an interactive console session by:
  ./interactive.sh

For example, to set up a Python commandline development environment:
  ./interactive
  python3 -m venv venv
  source venv/bin/activate
  pip install <packages>
