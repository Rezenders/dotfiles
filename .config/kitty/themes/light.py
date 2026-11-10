# Run by kitty's `geninclude`: prints the include line for this machine's light theme.
# 'beast' is the personal machine; every other host gets the work theme.
import socket

machine = "beast" if socket.gethostname() == "beast" else "work"
print(f"include themes/{machine}-light.conf")
