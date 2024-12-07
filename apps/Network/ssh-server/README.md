This container runs an ssh server.
First install necessary files into home/ by running
```
  ./install.sh
```
Next add the generated client key to your ssh agent:
```
  ssh-add files/files/ssh_client_ed25519_key
```
Now you can ssh into the container on localhost:12121:
```
  ssh -p 12121 localhost
```
