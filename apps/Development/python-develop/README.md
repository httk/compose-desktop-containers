This container is python-develop, based on generic-console.
This container sets up a fairly bare-bones console container,
but adds access to the host network, so that we are able to
access the containers localhost from outside the container.

You can launch software installed in the container by:
  ./exec.sh <program>
Or open an interactive console session by:
  ./interactive.sh

For example, to set up a Python development environment:
  ./interactive
  python3 -m venv venv
  source venv/bin/activate
  pip install <packages>
